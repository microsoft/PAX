import React from 'react';

export function HelpModal({ open, onClose }: { open:boolean; onClose: ()=>void }){
  if (!open) return null;
  return (
    <div role="dialog" aria-modal="true" className="fixed inset-0 z-50 flex items-start justify-center">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative mt-10 max-w-2xl w-[90%] bg-white rounded shadow-lg ring-1 ring-black/10">
        <div className="px-4 py-3 border-b flex items-center justify-between">
          <h2 className="text-lg font-semibold">Purview Audit Exporter — Help</h2>
          <button className="text-gray-500 hover:text-gray-700" aria-label="Close" onClick={onClose}>✕</button>
        </div>
        <div className="p-4 space-y-4 max-h-[70vh] overflow-auto text-sm text-gray-800">
          <section>
            <h3 className="font-semibold mb-1">What this app is</h3>
            <p>
              A simple desktop wizard to export Microsoft Purview audit events into a CSV file. It guides you
              through selecting activities, date range, output path, and export execution.
            </p>
          </section>
          <section>
            <h3 className="font-semibold mb-1">How to use</h3>
            <ol className="list-decimal ml-5 space-y-1">
              <li><b>Parameters:</b> Set date range, authentication mode, and select activities from curated tiers. Configure advanced settings, remember preferences, and use activity filters to focus your selection.</li>
              <li><b>Output:</b> Choose CSV output path and configure export behavior. Set search intervals and advanced performance options for large datasets or busy tenants.</li>
              <li><b>Review:</b> Confirm all settings and use the Export buttons. Generate standalone PowerShell scripts with identical functionality for future use or sharing.</li>
              <li><b>Export:</b> Monitor real-time progress with structured logging. Access results, generate scripts, and manage export cancellation. All runs create detailed audit logs.</li>
            </ol>
          </section>
          <section>
            <h3 className="font-semibold mb-1">What it outputs</h3>
            <p>
              A CSV file with rows of audit events matching your selected activities and time window. Each row represents a Copilot, AI, Teams, Exchange, or SharePoint activity with columns for timestamp, user, action type, and technical details. Both in-app runs and exported scripts automatically create detailed log files (.log) in the same directory as the CSV output for troubleshooting and audit trails.
            </p>
          </section>
          <section>
            <h3 className="font-semibold mb-1">Authentication &amp; Security</h3>
            <div className="space-y-2 text-sm">
              <p><b>Authentication &amp; Validation:</b> The script connects to Microsoft 365 services and validates your account permissions by testing audit log access before beginning the full export. If authentication fails, you can retry with different credentials or authentication method.</p>
              <p><b>Required Permissions:</b> Your account needs Exchange Online management permissions and Purview audit log access. The script tests these permissions by attempting a sample audit query before beginning the full export.</p>
              <p><b>Authentication Modes:</b> Web Login (best for MFA/CA policies), Device Code (for restricted environments), Credential prompts (may fail with modern security), or Silent (reuses cached sessions).</p>
              <p><b>Session Management:</b> Authentication sessions are properly cleaned up when the application closes, and background processes are automatically terminated.</p>
            </div>
          </section>
          <section>
            <h3 className="font-semibold mb-1">Step details</h3>
            <div className="space-y-2">
              <div>
                <h4 className="font-semibold">1) Parameters</h4>
                <ul className="list-disc ml-5">
                  <li><b>Start/End Date:</b> Define your time window using date pickers. End date is exclusive (data up to but not including end date).</li>
                  <li><b>Auth Mode:</b> Choose authentication method with info popup (ⓘ). Options: Web Login (recommended for MFA), Device Code (for restricted environments), Credential (username/password), or Silent (reuse existing session). Script validates account permissions before starting the full export.</li>
                  <li><b>Activities Selection:</b> Choose from dynamically loaded activity catalog. Use <i>List view</i> toggle (Curated/Full) to control catalog scope. Filter with <i>Show only selected</i> or <i>Show only recommended</i> checkboxes.</li>
                  <li><b>Activity Tiers:</b> Curated list includes Tier 1 (Copilot core), Tier 2 (Teams context), Tier 3 (Files context). Full catalog includes all available activities plus optional tiers (Exchange, Governance).</li>
                  <li><b>Selection Tools:</b> Use <i>Select Recommended</i> (tiers 1-3), <i>Select Everything</i>, or <i>Reset to Recommended</i> buttons. Load custom activity lists with <i>Load from file…</i> button.</li>
                  <li><b>Remember Settings:</b> Check to save selections and output path locally for future sessions.</li>
                </ul>
              </div>
              <div>
                <h4 className="font-semibold">2) Output</h4>
                <ul className="list-disc ml-5">
                  <li><b>Output File:</b> Select CSV file path using text field or <i>Browse…</i> button. Log file (.log) is automatically created in same directory with timestamp naming.</li>
                  <li><b>Search Interval:</b> Choose query window size (2,4,6,8,12,24 hours) from dropdown. Smaller intervals create more frequent queries - longer overall process but better for large datasets or busy tenants.</li>
                  <li><b>Overwrite Toggle:</b> Switch to control file replacement behavior. When off, timestamp suffixes create unique file names.</li>
                  <li><b>Advanced Settings:</b> Expandable section with <i>Result size per call</i> (1-5000, default 5000) and <i>Pacing between calls</i> (0-10000ms, default 0). Use pacing (150-300ms) to reduce throttling in busy tenants. <i>Reset to defaults</i> button available.</li>
                </ul>
              </div>
              <div>
                <h4 className="font-semibold">3) Review</h4>
                <ul className="list-disc ml-5">
                  <li><b>Authentication Summary:</b> Shows selected auth mode with info popup (ⓘ) explaining all authentication options and permission validation behavior.</li>
                  <li><b>Settings Review:</b> Complete summary of dates, search interval, result size, pacing, selected activities count with individual activity badges, output path, and remember preference.</li>
                  <li><b>Detailed Post Logs:</b> Toggle to control verbosity of post-processing output (applies to next run, not current settings).</li>
                  <li><b>Export Actions:</b> <i>Run Export</i> button starts immediate execution. <i>Export to .ps1</i> button (📄) generates standalone PowerShell script with identical settings and functionality.</li>
                </ul>
              </div>
              <div>
                <h4 className="font-semibold">4) Export</h4>
                <ul className="list-disc ml-5">
                  <li><b>Status &amp; Progress:</b> Color-coded status badge (Running/Success/Error/No Results) with dual progress bars - overall export progress and current task progress with phase indicators (queries/keywords/post).</li>
                  <li><b>Real-time Controls:</b> Toggle <i>Show detailed post logs</i> (applies to next run) and <i>Auto scroll log</i> checkbox for log viewing preferences.</li>
                  <li><b>Authentication Alerts:</b> Prominent notification when Microsoft sign-in window opens during Web Login authentication, requiring user interaction in browser.</li>
                  <li><b>Results Access:</b> <i>Open CSV</i> opens data file, <i>Open Folder</i> opens containing directory, <i>Open Log</i> opens transcript file for troubleshooting.</li>
                  <li><b>Script Generation:</b> <i>Export as .ps1</i> button creates standalone PowerShell script with current settings for future execution or sharing with other administrators.</li>
                  <li><b>Process Management:</b> Cancel running exports or close application. Start Over button resets wizard to beginning. All files are preserved even if export is cancelled.</li>
                </ul>
              </div>
            </div>
          </section>
          <section>
            <h3 className="font-semibold mb-1">Performance &amp; Timing</h3>
            <div className="space-y-1 text-sm">
              <p><b>Expected Behavior:</b> Individual queries may appear to "hang" for 30-120 seconds. This is normal Microsoft 365 behavior - Purview processes complex audit queries server-side which takes time for large datasets.</p>
              <p><b>Progress Indicators:</b> Watch for "[25%] Query 5/20" progress markers followed by waiting periods. Be patient during apparent hangs - the service is working. True timeouts are rare (10+ minutes).</p>
              <p><b>Throttling Management:</b> Use smaller Block Hours (2-4) and Pacing (150-300ms) in busy tenants to reduce throttling risk. Higher Result Size (5000) reduces total API calls needed.</p>
              <p><b>Structured Logging:</b> Progress includes human-readable markers plus structured tags (PA:PHASE, PA:TOTALS, PA:POST) for automation tools while remaining console-friendly.</p>
            </div>
          </section>
        </div>
        <div className="px-4 py-3 border-t flex justify-end">
          <button className="px-3 py-1.5 rounded bg-blue-600 text-white hover:bg-blue-700" onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
}
