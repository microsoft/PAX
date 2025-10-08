# Dual-Branch Workflow Setup Guide

## Overview

Your PAX repository now uses a **dual-branch strategy**:
- **`PAX` branch**: Full development environment (all code, UI, scripts, test data)
- **`release` branch**: Customer-facing only (script + documentation files)

## What Was Done

✅ **Updated `release.ps1`** with automatic branch syncing
✅ **Committed changes** to PAX branch
✅ **Pushed to private repo** (Rance9/PAX)

## What You Need to Do Manually

### Step 1: Set Default Branch to `release` on GitHub

You need to change the default branch on both repositories so customers see the `release` branch first.

#### For Microsoft Repo (microsoft/PAX):

1. Go to: **https://github.com/microsoft/PAX/settings/branches**
2. Under "Default branch", click the ⇄ switch icon
3. Select **`release`** from the dropdown
4. Click **"Update"**
5. Confirm the change

#### For Private Repo (Rance9/PAX):

1. Go to: **https://github.com/Rance9/PAX/settings/branches**
2. Under "Default branch", click the ⇄ switch icon
3. Select **`release`** from the dropdown
4. Click **"Update"**
5. Confirm the change

**Why:** This ensures when customers visit your repo, they see the clean `release` branch first, not the development `PAX` branch.

---

### Step 2: Initial Population of Release Branch

Since the `release` branch exists but may be empty, you have two options:

#### Option A: Let release.ps1 Handle It (Recommended)

Just run a release as normal, and the script will automatically populate the release branch:

```powershell
.\release.ps1 -Patch -Message "Initial release branch setup"
```

This will:
1. Bump the version
2. Update all version files on PAX branch
3. Commit and push to PAX branch
4. Automatically sync customer-facing files to release branch
5. Push release branch to both repos

#### Option B: Manually Populate Release Branch (If Needed Now)

If you want to populate the release branch immediately without doing a version bump:

```powershell
# 1. Switch to release branch
git checkout release

# 2. Copy files from PAX branch
git checkout PAX -- scripts/PAX_Purview_Audit_Log_Processor_v1.5.0.ps1
git checkout PAX -- README.md
git checkout PAX -- LICENSE
git checkout PAX -- CONTRIBUTORS.md
git checkout PAX -- SECURITY.md
git checkout PAX -- CODE_OF_CONDUCT.md

# 3. Commit
git add .
git commit -m "Initial population of release branch with v1.5.0"

# 4. Push to both repos
git push origin release
git push backup release

# 5. Switch back to PAX branch
git checkout PAX
```

---

### Step 3: Fix SSO Authentication (If Not Done Yet)

You still need to authorize Git Credential Manager for the Microsoft organization. Until this is fixed, pushes to the Microsoft repo will fail.

**To Fix:**
1. Visit: **https://github.com/settings/connections/applications**
2. Find **"Git Credential Manager"**
3. Look for a **"Configure SSO"** or **"Grant"** button next to Microsoft
4. Authorize it

**Verify it works:**
```powershell
git push origin PAX
```

If successful, you're good to go!

---

## How It Works Going Forward

### Normal Development Workflow

Work on the `PAX` branch as usual:

```powershell
# Make changes to UI, add features, modify scripts
git add .
git commit -m "Added new feature"
git push origin PAX  # Pushes to both Microsoft and private repos
```

The `release` branch is NOT updated - customers don't see work-in-progress.

### When Ready to Release

Run the release script:

```powershell
# Patch version (1.5.0 → 1.5.1)
.\release.ps1 -Patch -Message "Bug fixes and improvements"

# Minor version (1.5.0 → 1.6.0)
.\release.ps1 -Minor -Message "Added new features"

# Major version (1.5.0 → 2.0.0)
.\release.ps1 -Major -Message "Major release with breaking changes"
```

**What Happens Automatically:**

1. ✅ Versions bumped in `package.json`, `tauri.conf.json`, `Cargo.toml`
2. ✅ Script file renamed to new version (old version archived to `LegacyScripts/`)
3. ✅ Changes committed to PAX branch
4. ✅ Git tag created (e.g., `v1.5.1`)
5. ✅ PAX branch pushed to both repositories
6. ✅ **Script switches to `release` branch**
7. ✅ **Copies ONLY customer-facing files from PAX branch:**
   - Latest script: `scripts/PAX_Purview_Audit_Log_Processor_v1.5.1.ps1`
   - `README.md`
   - `LICENSE`
   - `CONTRIBUTORS.md`
   - `SECURITY.md`
   - `CODE_OF_CONDUCT.md`
8. ✅ **Commits and pushes `release` branch to both repos**
9. ✅ **Switches back to PAX branch**

### Customer Experience

When customers visit **https://github.com/microsoft/PAX**:

1. They see the **`release` branch** by default (clean, focused view)
2. File listing shows ONLY:
   - Latest script in `scripts/` folder
   - Documentation files
3. No UI source code, no test data, no development files visible
4. README guides them to download the script

Advanced users can still:
- Switch to `PAX` branch to see full source (for contributions)
- View commit history
- Submit pull requests

---

## Files in Each Branch

### PAX Branch (Development - Private View)
```
├── scripts/
│   ├── PAX_Purview_Audit_Log_Processor_v1.5.0.ps1
│   ├── LegacyScripts/
│   ├── generate-synthetic.mjs
│   ├── build-merged-dataset.mjs
│   └── [all other dev scripts]
├── src/                  ← React app
├── src-tauri/            ← Desktop app
├── output/               ← Test data
├── Releases/             ← Build artifacts
├── node_modules/
├── package.json
├── vite.config.ts
├── README.md
├── LICENSE
├── CONTRIBUTORS.md
└── [everything else]
```

### release Branch (Customer-Facing - Public View)
```
├── scripts/
│   └── PAX_Purview_Audit_Log_Processor_v1.5.0.ps1  ← ONLY latest script
├── README.md
├── LICENSE
├── CONTRIBUTORS.md
├── SECURITY.md
└── CODE_OF_CONDUCT.md
```

---

## Troubleshooting

### "Release branch not found" error

If the script can't find the release branch:

```powershell
# Fetch it from remote
git fetch origin release:release
git checkout release
git push origin release
git checkout PAX
```

### Accidentally committed to wrong branch

If you committed to `release` branch by mistake:

```powershell
# Switch back to PAX
git checkout PAX

# Reset release branch to last known good state
git checkout release
git reset --hard origin/release
git checkout PAX
```

### Want to update release branch manually

If you need to update release branch without running full release:

```powershell
git checkout release
git checkout PAX -- README.md  # Copy specific files
git add .
git commit -m "Update documentation"
git push origin release
git push backup release
git checkout PAX
```

---

## Branch Protection Recommendations

### For `release` Branch (Recommended):

Set these on GitHub (Settings → Branches → Add rule for `release`):

- ✅ **Require pull request reviews before merging**
- ✅ **Require status checks to pass**
- ✅ **Do not allow force pushes**
- ✅ **Do not allow deletions**

This ensures `release` branch only gets updates through the automated script or approved PRs.

### For `PAX` Branch:

Less restrictive - this is your development playground.

---

## Future Considerations

### When You Have Multiple Scripts Ready:

The `release.ps1` script currently copies only the latest script. If you want to release multiple scripts:

**Option 1: Modify the script** to copy all `scripts/PAX_*.ps1` files
**Option 2: Manually add** additional scripts before release:

```powershell
git checkout release
git checkout PAX -- scripts/AnotherScript_v1.0.0.ps1
git add .
git commit -m "Add AnotherScript to release branch"
git push origin release
git push backup release
git checkout PAX
```

### When README Should Differ:

Currently, `release.ps1` copies the same README to both branches. If you want different READMEs:

1. Create `README-RELEASE.md` in PAX branch (customer-focused version)
2. Modify `release.ps1` to copy `README-RELEASE.md` to `README.md` on release branch

---

## Summary Checklist

- [ ] Set default branch to `release` on Microsoft repo
- [ ] Set default branch to `release` on Rance9 repo
- [ ] Populate release branch (via release.ps1 or manually)
- [ ] Fix SSO authentication for Microsoft repo
- [ ] Test a release: `.\release.ps1 -Patch -Message "Test release"`
- [ ] Verify release branch updated on both repos
- [ ] Verify customer view shows only release branch files

---

## Support

If you encounter issues with the dual-branch workflow, check:
1. Current branch: `git branch` (should be on `PAX` for development)
2. Remote status: `git remote -v` (should show origin with 2 push URLs)
3. Branch list: `git branch -a` (should show both PAX and release)
4. Recent commits: `git log --oneline --all --graph`

The `release.ps1` script will handle most scenarios automatically!
