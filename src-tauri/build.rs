fn main() {
  // Rebuild when the embedded script or datasets change
  println!("cargo:rerun-if-changed=../scripts/CopilotAuditExport.ps1");
  println!("cargo:rerun-if-changed=../scripts/audit-activities.json");
  println!("cargo:rerun-if-changed=../scripts/audit-activities.generated.json");
  println!("cargo:rerun-if-changed=../scripts/audit-activities.merged.json");
  // Embed a build timestamp to ensure the binary updates and to aid diagnostics
  let ts = std::time::SystemTime::now()
    .duration_since(std::time::UNIX_EPOCH)
    .map(|d| d.as_secs())
    .unwrap_or(0);
  println!("cargo:rustc-env=PAX_BUILD_TS={}", ts);
  tauri_build::build()
}
