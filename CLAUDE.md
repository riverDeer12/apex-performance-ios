# Apex Performance iOS

## App Store releases

A release is the TestFlight workflow run on `production` with `app: store`.
New App Store screenshots are taken only when the owner asks for them
(input `screenshots: true`): then it also runs the "App Store screenshots"
workflow, which uploads the `AppStore-screenshots` artifact (iPhone 6.9" and
iPad 13", ten each, in the order they go to App Store Connect) and pushes
all PNGs to the `store-screenshots` branch. Without it the new App Store
version keeps the previous version's screenshots. Then the "App Store
listing" workflow puts What's New (`fastlane/whats_new/<language>.txt`),
the screenshots (if taken) and the build (once Apple has processed it) on
the App Store version being prepared. Submitting for review stays manual.

For every new App Store version:

- When the owner asks for new screenshots: before the store build, add the version's new screens to
  `ApexPerformanceUITests/AppStoreScreenshotTests.swift` and their data to
  `ApexPerformance/Core/Networking/DemoAPI.swift` (Debug only, `-demoData`).
  `DemoAPITests` must keep passing: every demo response decodes into the
  app's models. Update the order in the "Make the App Store set" step of
  `.github/workflows/screenshots.yml` so new features come first.
- Before the store build, update the What's New texts in
  `fastlane/whats_new/` (hr, en, it, de): everything since the last
  version that is live on the App Store.
- After the store build, send the owner the "What's New" text; when new
  screenshots were taken, look at them and send the ZIP of the App Store
  set too.
- Screenshots never show real people: only the invented demo data.
