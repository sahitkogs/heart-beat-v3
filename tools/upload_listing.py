"""Uploads the en-US Main Store Listing to Play Console via the Publisher API.

Fills in: title, short description, full description, icon (512x512),
feature graphic, phone screenshots, 7-inch tablet screenshots.

Source content:
    marketing/listing.md           — title, descriptions
    marketing/feature-graphic.png  — 1024x500
    marketing/screenshots/pixel8/  — phone shots (1080x2400)
    marketing/screenshots/tablet/  — 7-inch tablet shots (1200x1920)
    assets/icon/heartbeat-icon.png — resized inline to 512x512

Usage:
    python tools/upload_listing.py
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload, MediaFileUpload
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
KEY = ROOT / "android" / "play-publisher-key.json"
PACKAGE = "com.sahitkogs.heartbeat"
LANGUAGE = "en-US"

ICON_SRC = ROOT / "assets" / "icon" / "heartbeat-icon.png"
FEATURE = ROOT / "marketing" / "feature-graphic.png"
PHONE_DIR = ROOT / "marketing" / "screenshots" / "pixel8"
TABLET_DIR = ROOT / "marketing" / "screenshots" / "tablet"

TITLE = "heart•beat"
SHORT = "End-to-end encrypted messages for two."
FULL = (
    "heart•beat is a private messaging app for the people who matter most. "
    "Every message is end-to-end encrypted with the Signal protocol — only you "
    "and the people you message can read what you send. We don't run ads, we don't "
    "track you, and we don't store your messages on any server. Your conversations "
    "stay on your phone.\n\n"
    "Add a contact by scanning their QR code or pasting their public key. Send text "
    "messages one-on-one or in small groups (up to 8 people). When a message arrives "
    "for you, a push notification wakes your phone — but the message content "
    "itself is encrypted, so the server delivering the notification never sees what "
    "you wrote.\n\n"
    "heart•beat is built for two people who want to talk privately. No accounts. "
    "No phone numbers. No ads."
)

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def resize_icon_to_bytes(src: Path) -> bytes:
    img = Image.open(src).convert("RGB")
    img = img.resize((512, 512), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def delete_all_images(edits, edit_id: str, image_type: str) -> None:
    edits.images().deleteall(
        packageName=PACKAGE,
        editId=edit_id,
        language=LANGUAGE,
        imageType=image_type,
    ).execute()


def upload_image_file(edits, edit_id: str, image_type: str, path: Path) -> None:
    media = MediaFileUpload(str(path), mimetype="image/png", resumable=False)
    edits.images().upload(
        packageName=PACKAGE,
        editId=edit_id,
        language=LANGUAGE,
        imageType=image_type,
        media_body=media,
    ).execute()


def upload_image_bytes(edits, edit_id: str, image_type: str, data: bytes) -> None:
    media = MediaIoBaseUpload(io.BytesIO(data), mimetype="image/png", resumable=False)
    edits.images().upload(
        packageName=PACKAGE,
        editId=edit_id,
        language=LANGUAGE,
        imageType=image_type,
        media_body=media,
    ).execute()


def main() -> int:
    if not KEY.exists():
        print(f"ERROR: service account key not found at {KEY}", file=sys.stderr)
        return 1

    for required in [ICON_SRC, FEATURE]:
        if not required.exists():
            print(f"ERROR: missing {required}", file=sys.stderr)
            return 1

    phone_shots = sorted(PHONE_DIR.glob("*.png"))
    tablet_shots = sorted(TABLET_DIR.glob("*.png"))
    if not phone_shots:
        print(f"ERROR: no phone screenshots in {PHONE_DIR}", file=sys.stderr)
        return 1

    creds = service_account.Credentials.from_service_account_file(str(KEY), scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()

    print(f"Opening edit for {PACKAGE} ...")
    edit = edits.insert(packageName=PACKAGE, body={}).execute()
    edit_id = edit["id"]

    try:
        print(f"Setting {LANGUAGE} listing text ...")
        edits.listings().update(
            packageName=PACKAGE,
            editId=edit_id,
            language=LANGUAGE,
            body={
                "language": LANGUAGE,
                "title": TITLE,
                "shortDescription": SHORT,
                "fullDescription": FULL,
            },
        ).execute()

        print("Uploading icon (512x512, resized in memory) ...")
        delete_all_images(edits, edit_id, "icon")
        upload_image_bytes(edits, edit_id, "icon", resize_icon_to_bytes(ICON_SRC))

        print(f"Uploading feature graphic {FEATURE.name} ...")
        delete_all_images(edits, edit_id, "featureGraphic")
        upload_image_file(edits, edit_id, "featureGraphic", FEATURE)

        print(f"Uploading {len(phone_shots)} phone screenshot(s) ...")
        delete_all_images(edits, edit_id, "phoneScreenshots")
        for p in phone_shots:
            print(f"  + {p.name}")
            upload_image_file(edits, edit_id, "phoneScreenshots", p)

        if tablet_shots:
            print(f"Uploading {len(tablet_shots)} 7-inch tablet screenshot(s) ...")
            delete_all_images(edits, edit_id, "sevenInchScreenshots")
            for p in tablet_shots:
                print(f"  + {p.name}")
                upload_image_file(edits, edit_id, "sevenInchScreenshots", p)

        print("Committing edit ...")
        edits.commit(packageName=PACKAGE, editId=edit_id).execute()
        print(f"OK — listing saved for {LANGUAGE}")
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
