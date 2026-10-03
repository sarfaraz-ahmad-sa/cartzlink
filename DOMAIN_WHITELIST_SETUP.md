# CARTZ Link domain whitelist

This build is based on the latest uploaded `cartzlink(1).rar` source.

## Expected CRM endpoint

Default URL:

`https://crm.cartzlink.com/admin/?r=api/fetchMobileDomainList`

Expected response:

```json
{
  "ok": 1,
  "data": [
    {"domain": "client1.example.com"},
    {"domain": "client2.example.com"}
  ]
}
```

The app sends a POST request.

If `validateMobileAppRequest()` expects a token, the client sends it in:

`X-App-Token: <token>`

A runtime token saved in SharedPreferences under `mobile:apiToken` takes priority. For testing only, a token can also be supplied at build time:

```powershell
flutter build appbundle --release --dart-define=CARTZ_MOBILE_API_TOKEN=YOUR_TOKEN
```

For production, prefer a short-lived token issued by your authentication endpoint instead of a permanent token compiled into the app.

## Domain flow

1. App loads cached approved domains for fast UI only.
2. App POSTs to the CRM domain API on each app process/session.
3. Fresh server response replaces the cache.
4. Login/connect is disabled until the fresh refresh succeeds.
5. Typed hosts are normalized and must exactly match an approved domain.
6. Recent-domain dropdown is filtered against the latest approved list.
7. Navbar domain switching is also checked against the latest approved list.
8. If a domain is removed on the server, it stops working on the next app launch/refresh even if it existed in old local storage.

## Override endpoint if needed

```powershell
flutter run --dart-define=CARTZ_DOMAIN_API_URL=https://your-api.example.com/path
```

## Signing

The uploaded private keystore and `android/key.properties` were intentionally NOT copied into this ZIP. Keep using your existing local signing files. `android/app/build.gradle.kts` still reads `android/key.properties` for the release signing config.
