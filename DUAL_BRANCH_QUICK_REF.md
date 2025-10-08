# Dual-Branch Quick Reference

## Branch Overview

| Branch | Purpose | Who Sees It | Content |
|--------|---------|-------------|---------|
| **PAX** | Development | Developers only | Everything (UI, scripts, tests, docs) |
| **release** | Customer-facing | Public/Customers (default) | Script + docs only |

---

## Daily Workflow

### Normal Development (PAX branch)
```powershell
# Make changes, commit, push
git add .
git commit -m "Your changes"
git push origin PAX  # Auto-pushes to both Microsoft & Rance9 repos
```

### Release New Version
```powershell
# Patch (1.5.0 → 1.5.1)
.\release.ps1 -Patch -Message "Bug fixes"

# Minor (1.5.0 → 1.6.0)  
.\release.ps1 -Minor -Message "New features"

# Major (1.5.0 → 2.0.0)
.\release.ps1 -Major -Message "Breaking changes"
```

**Script automatically:**
- ✅ Bumps versions
- ✅ Updates PAX branch
- ✅ Syncs release branch with customer files
- ✅ Pushes both branches to both repos

---

## What's in Each Branch?

### PAX (Development)
- ✅ All source code (UI/UX)
- ✅ All scripts (current + development)
- ✅ Test data
- ✅ Build artifacts
- ✅ Everything

### release (Customer-Facing)
- ✅ Latest script only: `scripts/PAX_Purview_Audit_Log_Processor_v1.x.x.ps1`
- ✅ README.md
- ✅ LICENSE
- ✅ CONTRIBUTORS.md
- ✅ SECURITY.md
- ✅ CODE_OF_CONDUCT.md
- ❌ No UI code
- ❌ No test data
- ❌ No development files

---

## Manual Tasks Required (One-Time Setup)

### 1. Set Default Branch on GitHub

**Microsoft Repo:**
https://github.com/microsoft/PAX/settings/branches
→ Change default from `PAX` to `release`

**Private Repo:**
https://github.com/Rance9/PAX/settings/branches
→ Change default from `PAX` to `release`

### 2. Fix SSO Authentication
https://github.com/settings/connections/applications
→ Authorize "Git Credential Manager" for Microsoft org

### 3. Initial Release Branch Population

Run your first release:
```powershell
.\release.ps1 -Patch -Message "Initial release branch setup"
```

---

## Troubleshooting

### Switch between branches manually
```powershell
git checkout PAX      # Development
git checkout release  # Customer view
```

### View all branches
```powershell
git branch -a
```

### Check which branch you're on
```powershell
git branch  # Current branch has * 
```

### Reset if something goes wrong
```powershell
git checkout PAX  # Always go back to development branch
```

---

## Quick Checks

✅ **Current branch:** Should be `PAX` for dev work
```powershell
git rev-parse --abbrev-ref HEAD
```

✅ **Remote configuration:**
```powershell
git remote -v
# Should show origin with 2 push URLs (Microsoft + Rance9)
```

✅ **Branch sync status:**
```powershell
git fetch --all
git branch -vv
```

---

## Customer Experience

When visiting **github.com/microsoft/PAX**:

1. **Default view:** `release` branch (clean, script + docs only)
2. **Can switch to:** `PAX` branch (full source for contributors)
3. **Downloads:** Latest script from `scripts/` folder
4. **No clutter:** No dev files, no UI code, no test data

---

## Key Benefits

✅ **Separation:** Customers don't see work-in-progress
✅ **Automation:** release.ps1 handles everything
✅ **Flexibility:** Develop freely on PAX branch
✅ **Professional:** Clean customer-facing release branch
✅ **One Repo:** Don't need multiple repos
✅ **Dual Backup:** Both Microsoft + private repos synced

---

## Remember

- 🔧 **Develop on:** `PAX` branch
- 🚀 **Release via:** `.\release.ps1` script
- 👥 **Customers see:** `release` branch (auto-synced)
- 📦 **Both repos:** Microsoft + Rance9 stay in sync
