# heart•beat — Privacy Policy

**Effective date:** 2026-05-22

heart•beat is built by a single developer (Sahit Koganti) for private peer-to-peer messaging. We collect as little data as we can while still delivering messages.

## What we collect on our server

When you install heart•beat and create an identity, the relay server stores:

- **Your Ed25519 public key** — used to route messages addressed to you and to verify message signatures.
- **Your Firebase Cloud Messaging (FCM) push token** — used to wake your device when a message arrives for you. The token is provided by Google's Firebase service.
- **The display name you set** — so other people you chat with see the name you chose. This is set by you in the app and can be changed or left blank at any time.

That is the complete list of data the heart•beat server stores about you.

## What we DO NOT collect

heart•beat does not collect, transmit, or store:

- The content of your messages (every message is end-to-end encrypted with the Signal protocol — the relay server only sees ciphertext)
- Your phone number, email address, real name, or any government identifier
- Your phone's contact list (the in-app Contacts list lives only on your device)
- Analytics, telemetry, crash reports, or usage statistics
- Any advertising identifiers or marketing tracking signals
- Third-party SDKs other than Google Firebase Cloud Messaging (push wake-up only)

## Third parties involved

- **Google Firebase Cloud Messaging** — delivers a wake-up signal to your device when a message arrives. The wake-up signal itself contains the end-to-end-encrypted message envelope; Google does not see the plaintext. Firebase's privacy policy applies to the FCM token it issues for your device: https://firebase.google.com/support/privacy

## Your rights and choices

- **Delete your account at any time.** Uninstall the app to remove all local data (messages, contacts, identity). To also remove your public key, FCM token, and display name from the relay server, email `sahit.koganti@gmail.com` with the subject "Delete my heart•beat identity" and include your public key (visible in the My Profile screen).
- **Change your display name** at any time in the app via the My Profile screen.

## Contact

Questions, concerns, or deletion requests: `sahit.koganti@gmail.com`

## Changes to this policy

If this policy ever changes, the new version will be published at this URL with a new effective date.
