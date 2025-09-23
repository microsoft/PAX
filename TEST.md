# Manual Acceptance Tests

## Step 1 Validation
- Missing start date shows error
- Missing end date shows error
- End date before start date shows error
- No activities selected shows error

## Multi-select
- Relevant group appears first
- Categories appear after
- Search filters by name & description
- Selected items display as chips

## Step 2 Output
- Browse dialog selects a CSV path
- Overwrite toggle present

## Step 3 Review & Run
- Summary matches inputs
- Run transitions to Progress step

## Step 4 Progress & Results
- Status badge updates Running → Success/Error
- Logs stream live (stdout white, stderr red)
- CSV file exists at chosen path
- Open CSV launches file
- Open Folder opens containing directory
- Run Again resets wizard

## Error Handling
- If `pwsh` missing, friendly install hint in stderr

## Activities Catalog
- `npm run sync:activities` regenerates `src/lib/activities.ts`
- File contains categorized, alphabetized entries

## Script Path Behavior
- Dev: uses `./scripts/CopilotAuditExport.ps1`
- Prod: packaged resource `resources/scripts/CopilotAuditExport.ps1`
