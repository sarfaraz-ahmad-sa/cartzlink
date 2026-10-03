# Android Passkey setup for ERP domains

CARTZ Link now uses `WebAuthenticationSupport.forApp` so a passkey request cannot use privileged-browser mode.

For passkeys to work for an ERP website inside the app, associate that ERP domain with the Android app using Digital Asset Links.

For every ERP host that should support passkeys, publish:

`https://YOUR-DOMAIN/.well-known/assetlinks.json`

Example structure:

```json
[
  {
    "relation": ["delegate_permission/common.get_login_creds"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.cartzlink.crm",
      "sha256_cert_fingerprints": [
        "YOUR_RELEASE_CERT_SHA256"
      ]
    }
  }
]
```

Important:
- Use the SHA-256 fingerprint of the certificate that signs the installed APK/AAB.
- The current sample Gradle file still signs `release` with the debug key. Before production passkey rollout, configure a permanent release signing key and publish its SHA-256 fingerprint.
- The same app association JSON can be deployed to all ERP domains controlled by you, using the same package name and production signing fingerprint.
- `forBrowser` is intentionally not used. Arbitrary-domain browser WebAuthn requires privileged-browser trust/allowlisting by the credential provider.
