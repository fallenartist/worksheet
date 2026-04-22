# Daily Worksheet

Personal macOS worksheet app for Daily Time Tracking reports.

The app syncs Daily timesheet data, adds local manual admin time, calculates creative/admin ratios, and exports a printable monthly PDF.

## Current MVP

- SwiftUI macOS app
- Status bar menu for opening and syncing
- Daily API key stored in Keychain
- Monthly sync from `GET /timesheet`
- Daily project rows are read-only and marked as synced
- Manual admin entries are editable and stored locally
- Creative/admin totals and percentages
- Basic PDF export

## Development

This starter is a Swift Package so it can live cleanly in GitHub and later be opened from Xcode.

For normal SwiftUI app development, install full Xcode. Apple's Command Line Tools alone are not enough on this machine because SwiftPM needs Xcode's developer tools.

Build from the command line:

```bash
swift build
```

Run from the command line:

```bash
swift run DailyWorksheet
```

For a proper universal `.app` bundle, create/open a macOS app target in Xcode that uses these sources, then build with the standard `Any Mac` destination.

## Daily Setup

In Daily:

1. Open Preferences.
2. Enable Web API.
3. Copy the API key from the Integrations tab.
4. Paste it into this app's Settings tab.

Daily's API syncs periodically, so the current day may lag slightly behind the Daily app while tracking is active.
