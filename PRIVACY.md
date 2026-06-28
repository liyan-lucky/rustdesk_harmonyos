# Privacy Notice

This document describes the privacy posture of this repository and the application code in this repository. It is a project notice, not a substitute for a jurisdiction-specific privacy policy required by an app store, enterprise deployment, or commercial service.

## Application behavior

This project is a remote desktop client. Depending on enabled features and user configuration, the application may process:

- Device identifiers used by remote desktop protocols.
- Connection server addresses and peer IDs entered by the user.
- Session state, connection quality, logs, and diagnostic information.
- Screen, audio, input, file-transfer, and clipboard data during remote-control sessions.
- Account or server configuration data when login or address-book features are used.

## Data handling principle

The repository should not include production user data. Runtime data should remain on the user's device or the configured RustDesk-compatible service unless a feature clearly requires network transmission.

## Logs and diagnostics

Debug logs may contain device IDs, server addresses, peer IDs, session state, file paths, or other operational data. Do not publish user logs without review and redaction.

## Third-party services

Remote desktop connectivity depends on the server, relay, rendezvous, account, and update services configured by the user or distributor. Those services may have their own privacy terms.

## App-store / release requirement

Before distributing signed builds to users, publish a user-facing privacy policy that matches the actual released behavior, region, server configuration, telemetry, crash reporting, account system, and data retention practice.

## No telemetry by policy unless documented

Do not add analytics, crash reporting, advertising SDKs, or background telemetry without updating this notice, documenting user controls, and completing a privacy review.
