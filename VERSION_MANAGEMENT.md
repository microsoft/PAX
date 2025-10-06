# PAX Version Management System

## Overview

PAX uses a comprehensive automated version management system that ensures version consistency across all components. The version number is the **single source of truth** that propagates through:

- `package.json` (npm package version)
- `src-tauri/tauri.conf.json` (Tauri app version)
- `src-tauri/Cargo.toml` (Rust package version)
- **PowerShell script filename**: `PAX_Purview_Audit_Log_Processor_vX.X.X.ps1`
- PowerShell script header comment (line 1)
- PowerShell script `$ScriptVersion` variable (if exists)
- All example commands in script help section
- `README.md` script reference and all command examples

## Version Format

PAX follows **Semantic Versioning** (SemVer): `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes, incompatible API changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, performance improvements, backward-compatible

Current version: **1.4.2**

## Automated Release Process

### Using release.ps1

The `release.ps1` script is the **100% authoritative release manager** for PAX. It handles:

1. Version number calculation and validation
2. File updates (package.json, tauri.conf.json, Cargo.toml, script file)
3. Script archiving to `scripts/LegacyScripts/`
4. Git commit creation with standardized message
5. Git tag creation (triggers GitHub Actions release workflow)
6. README.md synchronization

### Release Commands

```powershell
# Patch release (1.4.2 -> 1.4.3) - Bug fixes
.\release.ps1 -Patch

# Minor release (1.4.2 -> 1.5.0) - New features
.\release.ps1 -Minor

# Major release (1.4.2 -> 2.0.0) - Breaking changes
.\release.ps1 -Major

# Custom commit message
.\release.ps1 -Patch -Message "Fix critical parsing bug"
```

### What Happens During a Release

When you run `.\release.ps1 -Patch`:

#### Step 1: Version Calculation
- Reads current version from `package.json`: **1.4.2**
- Calculates new version: **1.4.3**
- Prompts for confirmation

#### Step 2: Script Archiving (NEW!)
- **Archives** old script to `scripts/LegacyScripts/PAX_Purview_Audit_Log_Processor_v1.4.2.ps1`
- This preserves the **exact filename** with the old version number
- Creates `LegacyScripts/` folder if it doesn't exist

#### Step 3: Script Versioning
- **Reads** `scripts/PAX_Purview_Audit_Log_Processor_v1.4.2.ps1`
- **Updates** header: `# Portable Audit eXporter (PAX) - Purview Audit Log Processor - v1.4.3`
- **Updates** `$ScriptVersion = '1.4.3'` (if variable exists)
- **Updates** all script filename references in `.EXAMPLE` sections
- **Renames** file to: `PAX_Purview_Audit_Log_Processor_v1.4.3.ps1`
- **Deletes** old file from `scripts/` root (already archived)

#### Step 4: Other File Updates
- `package.json`: `"version": "1.4.3"`
- `src-tauri/tauri.conf.json`: `"version": "1.4.3"`
- `src-tauri/Cargo.toml`: `version = "1.4.3"` (package only, not dependencies)

#### Step 5: README Synchronization
- **Updates** script reference: `` Script: `PAX_Purview_Audit_Log_Processor_v1.4.3.ps1` ``
- **Updates** all command examples (20+ occurrences) to reference `v1.4.3.ps1`

#### Step 6: Git Commit & Tag
- Stages all modified files
- Creates commit: `"chore(release): bump version to 1.4.3"`
- Creates tag: `v1.4.3`
- **Triggers GitHub Actions workflow** to build installers/executables

#### Step 7: Summary
- Displays version change summary
- Shows commit hash and tag
- Reminds to push: `git push origin main --tags`

## Script Versioning Architecture

### Filename = Version (Single Source of Truth)

The script filename **always matches** the internal version:

```
scripts/PAX_Purview_Audit_Log_Processor_v1.4.2.ps1
    ↓
# Portable Audit eXporter (PAX) - Purview Audit Log Processor - v1.4.2
```

### Legacy Script Preservation

Old versions are **archived** in `scripts/LegacyScripts/`:

```
scripts/
├── PAX_Purview_Audit_Log_Processor_v1.4.3.ps1   ← Current version
└── LegacyScripts/
    ├── PAX_Purview_Audit_Log_Processor_v1.4.2.ps1
    ├── PAX_Purview_Audit_Log_Processor_v1.4.1.ps1
    ├── PAX_Purview_Audit_Log_Processor_v1.4.0.ps1
    └── PAX_Purview_Audit_Log_Processor_v1.3.11.ps1
```

**Why preserve old versions?**
- Customer support (users may reference older version)
- Rollback capability
- Historical comparison
- Documentation accuracy (release notes reference specific versions)

### Version Consistency Rules

**CRITICAL**: The version number in the filename MUST match:
1. ✅ The header comment (line 1)
2. ✅ The `$ScriptVersion` variable (if present)
3. ✅ All example commands in help section
4. ✅ The `package.json` version
5. ✅ The `README.md` script reference
6. ✅ All `README.md` command examples

**The `release.ps1` script enforces this consistency automatically.**

## Manual Version Changes (NOT RECOMMENDED)

If you need to manually update versions (e.g., testing, emergency fix):

### DO NOT:
- ❌ Manually rename the script file
- ❌ Edit version numbers in multiple places
- ❌ Create git tags manually
- ❌ Skip the archive step

### DO:
- ✅ Use `.\release.ps1` with appropriate flag
- ✅ Let automation handle all file updates
- ✅ Verify version consistency after changes

## Version History

All releases are tracked via git tags and GitHub Releases:

```bash
# List all version tags
git tag -l "v*"

# View specific release
git show v1.4.2

# Compare versions
git diff v1.4.1..v1.4.2
```

## GitHub Actions Integration

When `release.ps1` creates a tag (e.g., `v1.4.3`), GitHub Actions automatically:

1. Builds Windows installers (.msi)
2. Builds Windows portable (.exe)
3. Builds macOS universal binaries
4. Creates GitHub Release with artifacts
5. Publishes release notes

**Workflow file**: `.github/workflows/release.yml`

## Troubleshooting

### Version Mismatch Detected

If versions are out of sync:

```powershell
# Check current versions
Select-String -Pattern "version" package.json
Select-String -Pattern "# Portable Audit" scripts/PAX_Purview_Audit_Log_Processor_*.ps1
```

**Fix**: Run `.\release.ps1 -Patch` to resync (will bump to next patch version)

### Script Not Found During Release

Error: `Export script not found matching pattern`

**Cause**: Script filename doesn't match `PAX_Purview_Audit_Log_Processor_v*.ps1`

**Fix**: 
1. Manually rename script to match pattern: `PAX_Purview_Audit_Log_Processor_v1.4.2.ps1`
2. Update header comment to match: `# ... - v1.4.2`
3. Run `.\release.ps1 -Patch`

### LegacyScripts Folder Not Created

**Cause**: First release after archive feature added

**Fix**: Folder will be created automatically on next release. Or manually:
```powershell
New-Item -Path "scripts/LegacyScripts" -ItemType Directory
```

## Best Practices

1. **Always use release.ps1** for version changes
2. **Test in development branch first** before releasing to main
3. **Write meaningful commit messages** using `-Message` parameter
4. **Verify script functionality** after version bump (run test suite)
5. **Push tags immediately** after release: `git push origin main --tags`
6. **Monitor GitHub Actions** to ensure build succeeds
7. **Archive release notes** after each release

## Security Considerations

- Script versions are **digitally signed** via git commit signatures
- GitHub Release artifacts include **checksums** for verification
- Old versions in `LegacyScripts/` are **read-only** (archived)
- Version tags are **immutable** once pushed to GitHub

## Support

For version management issues:
1. Check this document first
2. Review `release.ps1` script comments
3. Examine git history: `git log --oneline --grep="release"`
4. Test in isolated environment before production changes

---

**Last Updated**: October 6, 2025  
**Current Version**: 1.4.2  
**Release Manager**: release.ps1
