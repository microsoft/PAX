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
              <li><b>Parameters:</b> Choose date range and activities (curated or full). Toggle recommended filters as needed.</li>
              <li><b>Output:</b> Pick a CSV path. Decide whether to overwrite existing files. Adjust advanced options like result size and pacing if required.</li>
              <li><b>Review:</b> Confirm selection and settings. Make any final adjustments before running.</li>
              <li><b>Export:</b> Run the export and monitor progress and logs in real time. You can also export a PowerShell script (.ps1) to run later.</li>
            </ol>
          </section>
          <section>
            <h3 className="font-semibold mb-1">What it outputs</h3>
            <p>
              A CSV file with rows of audit events matching your selected activities and time window. A companion log file
              can be generated in your temp directory to assist with troubleshooting.
            </p>
          </section>
          <section>
            <h3 className="font-semibold mb-1">Step details</h3>
            <div className="space-y-2">
              <div>
                <h4 className="font-semibold">1) Parameters</h4>
                <ul className="list-disc ml-5">
                  <li><b>Start/End Date:</b> Define your time window. End must be after start.</li>
                  <li><b>Activities:</b> Select from curated recommendations or switch to full catalog. Search and multi-select supported.</li>
                  <li><b>Filters:</b> Show only selected or recommended items to focus your list.</li>
                </ul>
              </div>
              <div>
                <h4 className="font-semibold">2) Output</h4>
                <ul className="list-disc ml-5">
                  <li><b>Output file:</b> Choose CSV path. Use <i>Browse…</i> to select a location.</li>
                  <li><b>Overwrite:</b> Allow replacing an existing CSV. When off, a new unique file name will be used.</li>
                  <li><b>Result size:</b> Batch size per request. Default works for most cases.</li>
                  <li><b>Pacing ms:</b> Optional delay between requests to reduce throttling risk.</li>
                </ul>
              </div>
              <div>
                <h4 className="font-semibold">3) Review</h4>
                <ul className="list-disc ml-5">
                  <li><b>Summary:</b> Check your chosen dates, activities, and output path.</li>
                  <li><b>Adjustments:</b> If something looks off, go back and change it before exporting.</li>
                </ul>
              </div>
              <div>
                <h4 className="font-semibold">4) Export</h4>
                <ul className="list-disc ml-5">
                  <li><b>Run:</b> Starts the export process and shows progress.</li>
                  <li><b>Logs:</b> Real-time logs appear here; you can copy them to share for support.</li>
                  <li><b>Export as .ps1:</b> Generate a self-contained PowerShell script to run later on another machine.</li>
                  <li><b>Cancel/Close:</b> Stop an in-flight run or close when done.</li>
                </ul>
              </div>
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
