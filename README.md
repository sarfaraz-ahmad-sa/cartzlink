# CARTZ Link — exact Flutter runtime port

This package follows the behavior of the **compiled `dist` shipped inside the uploaded Ionic project**, not the stale TSX files that are also present in the archive.

## Exact login flow from the shipped app

1. Screen shows only **ERP Host**.
2. Previously used host is restored from `erp:lastUrl`.
3. Host is normalized to a hostname.
4. App stores:
   - `erp:lastUrl`
   - `erp:lastUser` (legacy hidden value)
   - `crm:baseUrl = https://<host>`
   - `crm:lastUrl = https://<host>/admin`
5. App creates `auth:user_session` with `username: guest` (unless an old legacy user exists), `loginURL`, `lastLoginAt`, and `raw: {}`.
6. App opens Home.
7. Home loads the ERP `/admin` page in the embedded WebView.

There is **no direct-login API**, **no FetchAPPUsers**, **no fetchUserHashPass**, **no username field**, **no password field**, and **no SQLite login database** in the compiled runtime.

## Home behavior

- Title: `CARTZ Link - ERP`
- Reload button
- Logout button
- Embedded WebView
- Keeps `crm:baseUrl` and `crm:lastUrl`
- Adds `_ts=<timestamp>` when loading/reloading
- Rejects a stored last URL when it belongs to another origin
- Shows `Loading…` and an `Open in Browser` fallback while loading
- Android/system back uses WebView history first, then exits

The current shipped Home does **not** render the old bottom tabs, online indicator, open button, or exit button in its header.

## Profile

Profile code is included because it exists in the shipped bundle. It preserves the hard-coded profile source `https://nb.newagedistributions.com`, its cache-clearing key list, and bottom-tab behavior. The shipped Home does not expose a visible Profile tab.

## Generate Android/iOS folders

Flutter SDK was not available in the conversion environment, so platform boilerplate is intentionally not fabricated. Run from this folder:

```bash
flutter create --platforms=android,ios --org com.cartzlink --project-name cartz_link .
flutter pub get
flutter run
```

Set the displayed app name to `CARTZ Link` and keep application id/bundle id `com.cartzlink.crm`.


## Host navigation correction

The Flutter port now opens the entered ERP host directly. Example: entering `anamta.primeerp.top` loads `https://anamta.primeerp.top/`. It does **not** append `/admin` and does **not** append a `_ts` cache-busting query parameter. The Reload action uses the WebView's normal reload operation.

## Android ERR_CACHE_MISS fix

`android/app/src/main/AndroidManifest.xml` is included with `INTERNET` and `ACCESS_NETWORK_STATE` permissions at manifest level. This is required for the WebView in release builds. After any `flutter create .`, verify these permissions remain present, then run `flutter clean` before rebuilding.
