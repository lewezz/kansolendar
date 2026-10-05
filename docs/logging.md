# Errors and logging

The app reports safe error categories and does not log passwords, keys, event content or file payloads. Storage errors are independent of UI text in VaultError+Presentation.

| Condition | User-facing behavior |
| --- | --- |
| Wrong password | Remain locked and allow retry |
| Unsupported/corrupt file | Refuse opening and preserve the selected file |
| Existing creation destination | Request another name without overwriting |
| Second local writer | Report that the file is in use |
| External change or save failure | Clear decrypted presentation and require reopening |
| Invalid domain input | Reject changes |
| Broad recurrence/search query | Require a narrower range |

There is no remote diagnostic service. See [privacy](privacy.md) and [testing](testing.md).
