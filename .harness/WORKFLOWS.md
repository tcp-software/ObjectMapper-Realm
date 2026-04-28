# Workflows

## Prerequisites

- Xcode 15+ (Swift 5.9)
- `gh` CLI authenticated (`gh auth status`)
- CocoaPods (`gem install cocoapods`) — only for podspec validation / trunk push
- SwiftLint (`brew install swiftlint`) — optional, for lint

## Build

```bash
# SPM
swift build

# Xcode (scheme: ObjectMapper+Realm)
xcodebuild -project ObjectMapper+Realm.xcodeproj \
  -scheme "ObjectMapper+Realm" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  build
```

## Test

```bash
# SPM
swift test

# Xcode (with xcpretty)
xcodebuild -project ObjectMapper+Realm.xcodeproj \
  -scheme "ObjectMapper+Realm" \
  -destination "platform=iOS Simulator,name=iPhone 15" \
  test | xcpretty
```

## Lint / Format

```bash
# SwiftLint
swiftlint lint

# SwiftLint autocorrect
swiftlint --fix
```

## Run Locally

This is a library — there is no runnable app. Functionality is verified via the test target.

## Deploy

**CocoaPods release:**
1. Bump `s.version` in `ObjectMapper+Realm.podspec`
2. Create a git tag matching the version: `git tag <version> && git push origin <version>`
3. Validate: `pod lib lint ObjectMapper+Realm.podspec`
4. Push to trunk: `pod trunk push ObjectMapper+Realm.podspec`

**SPM release:**
1. Create and push a git tag — SPM consumers resolve by tag
2. `Package.resolved` is updated by consumers automatically

**CI/CD:** No automated pipeline configured. Releases are manual.

## Environment Configuration

This library requires no environment variables — it is a stateless open-source package.

| Variable | Description | Required |
|----------|-------------|----------|
| — | — | — |
