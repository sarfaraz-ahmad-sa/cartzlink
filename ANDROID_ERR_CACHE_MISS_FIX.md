# Android `net::ERR_CACHE_MISS` fix

The Flutter WebView needs Android network permission in the **main** manifest, not only the debug manifest.

The project now includes:

`android/app/src/main/AndroidManifest.xml`

with:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Both permissions are top-level children of `<manifest>` and are outside `<application>`.

## If you run `flutter create .`

Run it first, then make sure the above permission is still present in:

`android/app/src/main/AndroidManifest.xml`

Then rebuild from scratch:

```bash
flutter clean
flutter pub get
flutter run
```

For an APK:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Uninstall the previous app from the device before installing the rebuilt APK if Android still launches an older installed build.

## URL behavior

Entering:

`crm.cartzlink.com`

loads exactly:

`crm.cartzlink.com`

No `/admin` and no `_ts` query string are added by Flutter.
