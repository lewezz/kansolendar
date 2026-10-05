# ADR-0004: Authenticated encryption

Calendar data must remain confidential and authenticated at rest. The current implementation encrypts the entire document, including internal metadata, using AES-256-GCM with native CryptoKit. Random data keys are password-wrapped using platform PBKDF2 and AES-GCM. The exact file prefix is authenticated.

External file properties remain public. There is no plaintext database, older row-envelope persistence or external calendar interchange. See [ADR-0014](0014-whole-document-vaults.md), [ADR-0015](0015-current-format-only.md) and [security](../security.md).
