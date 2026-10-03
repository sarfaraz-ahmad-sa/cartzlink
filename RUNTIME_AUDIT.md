# Runtime audit used for this migration

The uploaded Ionic archive contains two conflicting implementations:

## Stale TypeScript source

`src/LoginPage.tsx` contains an older username/password + SQLite + API-validation flow.

## Compiled application actually present in `dist`

`dist/assets/index-BPXUx8HJ.js` contains the newer runtime flow:

- Login UI: ERP Host only.
- No `FetchAPPUsers` string in the compiled bundle.
- No `fetchUserHashPass` string in the compiled bundle.
- Login writes `crm:baseUrl` and `crm:lastUrl`.
- Auth session is saved under `auth:user_session`.
- Home derives its base URL from `session.loginURL`, then stored base/last URL, then `https://crm.cartzlink.com` fallback.
- Default Home target is `<base>/admin`.
- Home header contains Reload + Logout.
- Home WebView has a loading/fallback state.
- Profile still references `https://nb.newagedistributions.com`.

This Flutter port intentionally follows the compiled runtime because it represents the application that was actually built/shipped.
