# Activities dataset notes

This synthetic dataset aligns operation names and app identities to official Microsoft Unified Audit Log (UAL) conventions to maximize realism.

## Official operation names used

- Teams:
  - `MessageSent` (messages, Copilot Chat in Teams)
  - `MeetingDetail` (meeting join/detail)
- SharePoint/OneDrive:
  - `FileAccessed`, `FileUploaded`, `FileModified`
- Exchange:
  - `MailItemsAccessed`, `Create`

These names replace prior placeholders like `ChatMessage`/`Meeting` and ensure downstream tools (and your intuition) match what the real UAL produces.

## AppIdentity mapping (resource app IDs)

- Microsoft Teams: `1fec8e78-bce4-4aaf-ab1b-5451cc387264`
- Microsoft SharePoint Online (also backs OneDrive for Business): `00000003-0000-0ff1-ce00-000000000000`
- Microsoft Exchange Online: `00000002-0000-0ff1-ce00-000000000000`

Display names follow the canonical service names (e.g., `Microsoft Teams`, `Microsoft SharePoint Online`, `Microsoft Exchange Online`).

## Copilot context mapping

- Copilot events are emitted with `Context_Type` reflecting the host surface (e.g., `Copilot Chat`, `Teams`, `Outlook`, `Word`, `Excel`, `PowerPoint`, `OneNote`, `Loop`).
- RecordType is mapped to the host workload based on this context:
  - Teams/Copilot Chat → Teams (64)
  - Outlook → ExchangeItem (2)
  - Word/Excel/PowerPoint/OneNote/Loop → SharePointFileOperation (6)
- Operations are chosen to match realistic host actions for that context (e.g., `MessageSent` for Teams/Copilot Chat, `MailItemsAccessed` for Outlook, `FileAccessed` for file-based apps).

## Licensing anchor realism

Previously, a synthetic `Licensed` operation was emitted. Now, the earliest licensing/adoption anchor is represented as a real host event in context (preferring Teams `MessageSent`, then Outlook `MailItemsAccessed`, then SharePoint `FileAccessed`). The validator recognizes these as valid Copilot-context anchors.

## Validation

Run:

- `npm run synth:csv` to generate
- `npm run validate:synthetic` to verify anchors and app last-activity coverage
- `npm run analyze:purview` to check column fill rates

All checks should show 0 misses and no empty columns.
