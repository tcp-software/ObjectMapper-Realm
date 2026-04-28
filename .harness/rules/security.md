# Security Rules

<!-- LOAD: always | BUDGET: keep under 500 words -->

## Authentication & Authorization

- Use `ASWebAuthenticationSession` for OAuth/OIDC flows; never build custom browser-based auth with `WKWebView`.
- For biometric auth, use `LAContext` with `LAPolicy.deviceOwnerAuthenticationWithBiometrics`. Always provide passcode fallback via `.deviceOwnerAuthentication` for accessibility.
- Validate biometric availability before presenting the prompt; handle `.biometryLockout` and `.biometryNotEnrolled` gracefully.
- Use App Attest (`DCAppAttestService`) to verify app integrity on supported devices. Gate server-side trust decisions on attestation tokens.

## Input Validation

- Validate all deep link and universal link parameters before routing. Reject malformed or unexpected schemes.
- Sanitize `WKWebView` content: disable `javaScriptEnabled` unless required; set `allowsInlineMediaPlayback`, `mediaTypesRequiringUserActionForPlayback` restrictively.
- When handling `UIPasteboard` content, validate and sanitize before use — treat clipboard as untrusted input.
- Validate all JSON decoded from external sources using `Decodable` with explicit `CodingKeys`; never use `JSONSerialization` with unchecked casts.

## Secrets Management

- Store tokens, keys, and credentials exclusively in Keychain using `kSecAttrAccessible` set to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (or stricter).
- Never store secrets in `UserDefaults`, `plist` files, `Info.plist`, or hardcoded constants.
- For Keychain access, use a shared wrapper that enforces access group scoping and error handling. Never call `SecItem*` APIs directly from scene code.
- Access control: apply `SecAccessControlCreateWithFlags` with `.biometryCurrentSet` for high-value credentials.

## Data Protection

- Set file protection to `.completeUntilFirstUserAuthentication` minimum for persistent data. Use `.complete` for sensitive files.
- Enable data protection entitlement in the app target.
- Mark Core Data stores with `NSPersistentStoreFileProtectionKey` at the appropriate level.
- Exclude sensitive files from iCloud and iTunes backup using `URLResourceValues.isExcludedFromBackup`.
- Clear sensitive in-memory data (tokens, keys) on `UIApplication.didEnterBackgroundNotification`.
- Provide a `PrivacyInfo.xcprivacy` manifest declaring all accessed API categories (required since Spring 2024). Update it whenever new privacy-relevant APIs are adopted.

## Dependency Security

- Only add dependencies via Swift Package Manager. Lock to exact versions or closed ranges in `Package.resolved`.
- Audit new dependencies for: active maintenance, license compatibility, no excessive entitlement requirements.
- All third-party SDKs must include their own privacy manifest and signature; reject unsigned or manifest-missing packages for App Store builds.
- Review transitive dependencies before adoption — a direct dependency's subdependencies inherit your trust.

## Security Anti-Patterns

- Never disable App Transport Security globally; add per-domain exceptions only with documented justification.
- Never use `MD5` or `SHA1` for security purposes; use `SHA256`+ via `CryptoKit`.
- Never store tokens in `@AppStorage` or `SceneStorage` (backed by `UserDefaults`).
- Never embed API keys in client bundles without server-side validation layer.
- Never trust `canOpenURL` alone for scheme validation — verify the full URL structure.
