# TestFlight from GitHub Actions

`.github/workflows/testflight.yml` builds the app on a GitHub macOS runner and
uploads it to TestFlight with fastlane (`fastlane/Fastfile`, lane `beta`).

- Runs on every push to `production` and by hand (Actions → TestFlight → Run workflow).
- The build number is the latest TestFlight build number + 1. The version
  (`MARKETING_VERSION`) comes from the project.
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

## Running locally

```bash
bundle install
ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_CONTENT=... bundle exec fastlane beta
```
