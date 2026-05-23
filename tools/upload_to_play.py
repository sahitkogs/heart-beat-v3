"""Uploads the latest release AAB to a Play Console testing track.

Usage:
    python tools/upload_to_play.py [--track internal] [--notes "what's new"]

Defaults to the internal testing track. Requires the play-publisher service
account JSON key at android/play-publisher-key.json (gitignored) and the SA
to have been invited to the Play Console with at least "Release manager"
permissions on this app.

Pre-requirements (one-time):
    pip install google-api-python-client google-auth
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

ROOT = Path(__file__).resolve().parent.parent
KEY = ROOT / "android" / "play-publisher-key.json"
AAB = ROOT / "build" / "app" / "outputs" / "bundle" / "release" / "app-release.aab"
PACKAGE = "com.sahitkogs.heartbeat"

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--track",
        default="internal",
        choices=["internal", "alpha", "beta", "production"],
        help="Release track (default: internal)",
    )
    parser.add_argument(
        "--notes",
        default="New build.",
        help="Release notes for en-US (default: 'New build.')",
    )
    parser.add_argument(
        "--rollout",
        type=float,
        default=1.0,
        help="User fraction 0.0-1.0 (default: 1.0 = 100%%; only meaningful for staged rollouts)",
    )
    args = parser.parse_args()

    if not KEY.exists():
        print(f"ERROR: service account key not found at {KEY}", file=sys.stderr)
        return 1
    if not AAB.exists():
        print(f"ERROR: AAB not found at {AAB}. Run 'flutter build appbundle --release' first.", file=sys.stderr)
        return 1

    creds = service_account.Credentials.from_service_account_file(str(KEY), scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()

    print(f"Opening edit for {PACKAGE} ...")
    edit = edits.insert(packageName=PACKAGE, body={}).execute()
    edit_id = edit["id"]

    try:
        print(f"Uploading {AAB.name} ({AAB.stat().st_size // 1024 // 1024} MB) ...")
        media = MediaFileUpload(str(AAB), mimetype="application/octet-stream", resumable=True)
        bundle = edits.bundles().upload(
            packageName=PACKAGE,
            editId=edit_id,
            media_body=media,
        ).execute()
        version_code = bundle["versionCode"]
        print(f"Uploaded versionCode={version_code} sha1={bundle['sha1']}")

        release = {
            "name": f"v{version_code}",
            "versionCodes": [str(version_code)],
            "status": "completed" if args.rollout >= 1.0 else "inProgress",
            "releaseNotes": [{"language": "en-US", "text": args.notes}],
        }
        if args.rollout < 1.0:
            release["userFraction"] = args.rollout

        print(f"Assigning to '{args.track}' track ...")
        edits.tracks().update(
            packageName=PACKAGE,
            editId=edit_id,
            track=args.track,
            body={"releases": [release]},
        ).execute()

        print("Committing edit ...")
        edits.commit(packageName=PACKAGE, editId=edit_id).execute()
        print(f"OK — versionCode {version_code} published to {args.track}")
        return 0
    except Exception:
        try:
            edits.delete(packageName=PACKAGE, editId=edit_id).execute()
            print(f"Rolled back edit {edit_id}", file=sys.stderr)
        except Exception:
            pass
        raise


if __name__ == "__main__":
    sys.exit(main())
