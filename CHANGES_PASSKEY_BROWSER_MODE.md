# Passkey browser-mode change

- Android WebView WebAuthn changed from `WebAuthenticationSupport.forApp` to `WebAuthenticationSupport.forBrowser`.
- Existing WebView feature check remains in place.
- Existing try/catch remains in place so initialization failure does not close the app.
- Recent-domain dropdown, progress bar, URL flow, and login flow are unchanged.
