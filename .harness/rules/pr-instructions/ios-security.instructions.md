---
applyTo: "**/*.swift"
---

# Security Review Rules

## SEC-01 Never log tokens, credentials, or PII
Sensitive data must never be written to logs.

## SEC-02 Avoid unsafe optional handling that can crash
Crash risk is a security and stability concern when external or untrusted input is involved.

## SEC-03 Validate external input
Flag unsafe parsing, unchecked URL input, and unsafe handling of external data.

## SEC-04 Handle web and URL navigation safely
Flag unsafe web content handling, overly permissive URL opening, or missing validation of navigated destinations.

## SEC-05 Do not store sensitive information insecurely
Flag insecure persistence or exposure of tokens, credentials, or personal data.
