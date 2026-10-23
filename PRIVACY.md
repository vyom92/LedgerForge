# LedgerForge privacy policy

Last updated: 23 October 2026

LedgerForge is a personal, single-user macOS application maintained by the [repository owner](https://github.com/vyom92) to organize financial statements, maintain a local ledger and plan a monthly budget.

## Google account access

The optional Gmail connection requests only `https://www.googleapis.com/auth/gmail.readonly`. This is a mailbox-wide read permission. Within LedgerForge, collection searches the sender and date ranges selected by the owner, including matching messages in Spam and Trash, reads matching messages, and saves eligible original attachments locally for import. Message identifiers and related metadata support source tracing and duplicate detection.

LedgerForge does not request permission to send email, delete messages, change labels or mark messages as read. Google's sign-in and consent flow handles account authentication; LedgerForge does not collect the Google account password.

## Use, storage and sharing

Gmail data is used to provide the owner's statement collection, import, financial reporting and planning features. Original attachments, import metadata and accepted ledger records are retained in the local LedgerForge data store. OAuth credentials are stored in macOS Keychain. Local backups may include retained financial data; the owner chooses where backups are saved.

LedgerForge has no separate hosted ledger or mail server. If the owner enables Financial MCP or pairs the iPhone companion, selected financial views and planning data can be shared through OpenAI or an owner-selected iCloud Drive folder. These optional connections are controlled separately from Gmail authorization. Google, Apple, GitHub and OpenAI operate under their own applicable terms and privacy policies.

LedgerForge does not sell Gmail data, use it for advertising or use it to train general-purpose artificial intelligence or machine-learning models. LedgerForge's use and transfer of information received from Google APIs will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including its Limited Use requirements.

## Retention and control

The owner can stop collection in LedgerForge and revoke the connection in [Google Account connections](https://myaccount.google.com/connections). Revocation stops future authorized Gmail access; it does not delete originals or ledger records already imported, or copies in owner-controlled backups. Those remain until the owner removes them from local storage and any retained backups. LedgerForge does not offer a hosted account-deletion service.

## Ownership and contact

This policy grants no licence to access, reuse, redistribute or exploit the owner's emails, statements, financial records, credentials or other private data. Repository visibility and OAuth publishing status do not make the owner's Gmail account or local ledger publicly accessible. Original LedgerForge material is subject to the [rights notice](LICENSE.md).

For privacy questions, contact the [repository owner](https://github.com/vyom92). Do not include private financial information or credentials in a public issue.
