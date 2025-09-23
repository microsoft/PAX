const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// Only copy the runtime PowerShell export script and activity datasets; never copy synthetic generation/validation files.
const pairs = [
	['CopilotAuditExport.ps1', 'CopilotAuditExport.ps1'],
	// Removed refresh/discovery scripts to reduce surface area
	['audit-activities.json', 'audit-activities.json'],
    ['audit-activities.merged.json', 'audit-activities.merged.json'],
	['audit-activities.generated.json', 'audit-activities.generated.json'],
    
];

// Clean destination folder to avoid shipping stale scripts
const destDir = path.resolve(__dirname, '../src-tauri/resources/scripts/');
try {
  fs.rmSync(destDir, { recursive: true, force: true });
} catch {}
fs.mkdirSync(destDir, { recursive: true });

for (const [srcName, destName] of pairs) {
	const src = path.resolve(__dirname, srcName);
	const dest = path.join(destDir, destName);
	if (fs.existsSync(src)) {
		fs.copyFileSync(src, dest);
		console.log(`Copied ${src} -> ${dest}`);
	} else {
		console.warn(`WARN: Source not found: ${src}`);
	}
}

// Optional build-time signing of CopilotAuditExport.ps1
// Configure via environment variables:
//  - SIGN_THUMBPRINT: code signing cert thumbprint (uses CurrentUser/LocalMachine stores)
//  - SIGN_PFX_PATH: path to PFX file (alternatively)
//  - SIGN_PFX_PASSWORD: PFX password (plain; prefer ephemeral CI secrets)
//  - SIGN_STRICT=true: fail build if signing fails or no cert is provided
try {
	const scriptPath = path.resolve(__dirname, 'CopilotAuditExport.ps1');
	const resourceScriptPath = path.resolve(__dirname, '../src-tauri/resources/scripts/CopilotAuditExport.ps1');
	if (fs.existsSync(scriptPath)) {
		const tp = process.env.SIGN_THUMBPRINT;
		const pfx = process.env.SIGN_PFX_PATH;
		const pfxPwd = process.env.SIGN_PFX_PASSWORD;
		const strict = String(process.env.SIGN_STRICT || '').toLowerCase() === 'true';
		if (tp || pfx) {
			const signer = path.resolve(__dirname, 'Sign-CopilotAuditExport.ps1');
			const args = [ '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', signer ];
			if (tp) { args.push('-CertificateThumbprint', tp); }
			if (pfx) { args.push('-PfxPath', pfx); }
			if (pfxPwd) { args.push('-PfxPassword', pfxPwd); }
			console.log('Signing CopilotAuditExport.ps1 at build time...');
			const res = spawnSync('pwsh', args, { stdio: 'inherit' });
			if (res.status !== 0) {
				const msg = `Signing failed with exit code ${res.status}`;
				if (strict) { throw new Error(msg); }
				else { console.warn('WARN:', msg); }
			} else {
				console.log('Signing succeeded.');
			}
		} else if (process.env.SIGN_STRICT) {
			// SIGN_STRICT provided but no signing material
			throw new Error('SIGN_STRICT is set but no SIGN_THUMBPRINT or SIGN_PFX_PATH provided.');
		}
		// Re-copy the script after signing to ensure the signed file is embedded
		if (fs.existsSync(scriptPath)) {
			fs.copyFileSync(scriptPath, resourceScriptPath);
			console.log(`Embedded (post-sign): ${scriptPath} -> ${resourceScriptPath}`);
		}
	}
} catch (err) {
	console.error('ERROR during signing step:', err.message || err);
	if (String(process.env.SIGN_STRICT || '').toLowerCase() === 'true') {
		process.exit(1);
	}
}
