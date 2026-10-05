# Key management

Each current `.kanso` file carries a random 256-bit data key wrapped with its own password. CommonCrypto PBKDF2-HMAC-SHA256 uses a random 16-byte salt and 600,000 iterations; AES-GCM authenticates the wrapping context and whole-document framing. No device credential item or key sidecar is required.

Passwords require at least 15 Unicode scalars, no control characters and at most 1,024 UTF-8 bytes. PBKDF2 is not memory-hard: choose a long unique phrase. Forgetting it means losing access. No Touch ID, passkey or password reset exists.

After creation, the password sheet starts concealed. Reveal/Hide is explicit; Copy Password does not require revealing it. Open Passwords is optional and saving there is manual. Continue, lock and close clear the secret presentation. Clipboard copies are current-host-only and expire after 30 seconds if unchanged while the process remains running; other local processes may still read them.

Unlocked sessions hold keys and decrypted values in memory. Clearing Swift references does not guarantee physical zeroization. See [security](security.md) and [vaults](kanso-vault-files.md).
