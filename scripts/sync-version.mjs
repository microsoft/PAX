#!/usr/bin/env node

/**
 * Syncs version numbers across package.json, tauri.conf.json, and updates
 * window titles and executable names to include the version number.
 * 
 * Usage:
 *   node scripts/sync-version.mjs [new-version]
 * 
 * If no version is provided, extracts from git tag or uses current package.json version.
 */

import { readFileSync, writeFileSync } from 'fs';
import { execSync } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');

function getVersion() {
  // Check if a version was passed as argument
  const argVersion = process.argv[2];
  if (argVersion) {
    console.log(`📌 Using provided version: ${argVersion}`);
    return argVersion;
  }

  // Try to get version from git tag
  try {
    const gitTag = execSync('git describe --tags --exact-match HEAD', { 
      encoding: 'utf8', 
      stdio: ['ignore', 'pipe', 'ignore'] 
    }).trim();
    
    if (gitTag.startsWith('v')) {
      const version = gitTag.substring(1);
      console.log(`🏷️  Using git tag version: ${version}`);
      return version;
    }
  } catch (e) {
    // No exact tag match, continue
  }

  // Fall back to package.json version
  const packageJson = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  console.log(`📦 Using package.json version: ${packageJson.version}`);
  return packageJson.version;
}

function updatePackageJson(version) {
  const path = join(projectRoot, 'package.json');
  const content = JSON.parse(readFileSync(path, 'utf8'));
  content.version = version;
  writeFileSync(path, JSON.stringify(content, null, 2) + '\n');
  console.log(`✅ Updated package.json to version ${version}`);
}

function updateTauriConfig(version) {
  const path = join(projectRoot, 'src-tauri', 'tauri.conf.json');
  const content = JSON.parse(readFileSync(path, 'utf8'));
  
  // Update package version
  content.package.version = version;
  
  // Update window title to include version
  if (content.tauri && content.tauri.windows && content.tauri.windows[0]) {
    content.tauri.windows[0].title = `Purview Audit eXporter (PAX) v${version}`;
  }
  
  writeFileSync(path, JSON.stringify(content, null, 2) + '\n');
  console.log(`✅ Updated tauri.conf.json to version ${version}`);
  console.log(`✅ Updated window title to: Purview Audit eXporter (PAX) v${version}`);
}

function updateWorkflowFileNames(version) {
  const workflowPath = join(projectRoot, '.github', 'workflows', 'build-release.yml');
  
  try {
    let content = readFileSync(workflowPath, 'utf8');
    
    // Update Windows portable executable name
    content = content.replace(
      /Rename-Item "windows-dist\/\$exePath" "PAX-v[\d\.]+-Windows-Portable\.exe"/g,
      `Rename-Item "windows-dist/\\$exePath" "PAX-v${version}-Windows-Portable.exe"`
    );
    
    // Update Windows MSI installer name
    content = content.replace(
      /Rename-Item "windows-dist\/\$msiPath" "PAX-v[\d\.]+-Windows-Installer\.msi"/g,
      `Rename-Item "windows-dist/\\$msiPath" "PAX-v${version}-Windows-Installer.msi"`
    );
    
    // Update artifact search patterns - Windows EXE
    content = content.replace(
      /find \. -name "PAX-v[\d\.]+-Windows-Portable\.exe"/g,
      `find . -name "PAX-v${version}-Windows-Portable.exe"`
    );
    
    // Update artifact search patterns - Windows MSI
    content = content.replace(
      /find \. -name "PAX-v[\d\.]+-Windows-Installer\.msi"/g,
      `find . -name "PAX-v${version}-Windows-Installer.msi"`
    );
    
    // Update macOS artifact name
    content = content.replace(
      /zip -r "PAX-v[\d\.]+-macOS-Universal\.zip"/g,
      `zip -r "PAX-v${version}-macOS-Universal.zip"`
    );
    
    content = content.replace(
      /find \. -name "PAX-v[\d\.]+-macOS-Universal\.zip"/g,
      `find . -name "PAX-v${version}-macOS-Universal.zip"`
    );
    
    // Update release description - Windows EXE
    content = content.replace(
      /- `PAX-v[\d\.]+-Windows-Portable\.exe`/g,
      `- \`PAX-v${version}-Windows-Portable.exe\``
    );
    
    // Update release description - Windows MSI
    content = content.replace(
      /- `PAX-v[\d\.]+-Windows-Installer\.msi`/g,
      `- \`PAX-v${version}-Windows-Installer.msi\``
    );
    
    // Update release description - macOS
    content = content.replace(
      /- `PAX-v[\d\.]+-macOS-Universal\.zip`/g,
      `- \`PAX-v${version}-macOS-Universal.zip\``
    );
    
    writeFileSync(workflowPath, content);
    console.log(`✅ Updated GitHub workflow to use versioned filenames`);
    console.log(`✅ Updated MSI installer to use versioned filename`);
  } catch (e) {
    console.warn(`⚠️  Could not update workflow file: ${e.message}`);
  }
}

function main() {
  console.log('🔄 Syncing version numbers...\n');
  
  const version = getVersion();
  
  // Validate version format
  if (!/^\d+\.\d+\.\d+(-.*)?$/.test(version)) {
    console.error(`❌ Invalid version format: ${version}`);
    console.error('   Expected format: X.Y.Z or X.Y.Z-suffix');
    process.exit(1);
  }
  
  updatePackageJson(version);
  updateTauriConfig(version);
  updateWorkflowFileNames(version);
  
  console.log(`\n🎉 Version sync complete! All files updated to v${version}`);
  console.log('\n📋 Next steps:');
  console.log('   1. Commit the changes: git add -A && git commit -m "Update version to v' + version + '"');
  console.log('   2. Create and push tag: git tag v' + version + ' && git push origin v' + version);
  console.log('   3. GitHub Actions will build with versioned filenames automatically');
}

main();