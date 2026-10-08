# TestFlight from GitHub Actions

`.github/workflows/testflight.yml` builds the app on a GitHub macOS runner and
uploads it to TestFlight with fastlane (`fastlane/Fastfile`, lane `beta`).

- Runs on every push to `production` and by hand (Actions → TestFlight → Run workflow).
- Pushes build the **Test Apex** app (`software.rdd.ApexPerformance.test`,
  red TEST icon), which installs next to the App Store app. Run the workflow
  by hand with `app: store` to build the App Store app for a release.
- The build number is the latest TestFlight build number + 1.
- The version is the higher of the project's `MARKETING_VERSION` and the
  latest TestFlight version. When that version is already live on the App
  Store, the last number is raised (1.5 -> 1.6). A version can also be given
  when running the workflow by hand.
- Signing is cloud managed by Xcode with an App Store Connect API key, so no
  certificate or provisioning profile is stored anywhere.

## Secrets

Add them in GitHub → repository → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | Key ID of the App Store Connect API key |
| `ASC_ISSUER_ID` | Issuer ID shown above the keys list |
| `ASC_KEY_CONTENT` | The `.p8` file encoded with base64: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

The API key needs the **Admin** role, which cloud managed signing requires.
Never commit the `.p8` file.

## Test app

The variant comes from `APP_VARIANT` in `ApexPerformance/Config/AppVariant.xcconfig`
(bundle id suffix, name and icon). Builds from Xcode are the App Store app.

One time setup for the test app:

1. Developer portal → Identifiers → add the App ID `software.rdd.ApexPerformance.test`
   with Push Notifications.
2. App Store Connect → Apps → New App with that bundle id (name e.g. "Apex Performance Test").
3. Firebase → add an iOS app with that bundle id, upload the APNs key for it and
   save its config as `ApexPerformance/Config/GoogleService-Info-Test.plist`.
   The lane uses it for the test app; without it push notifications don't reach the test app.

## Running locally

```bash
bundle install
ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_CONTENT=... bundle exec fastlane beta
```
