# GitHub Setup Guide for PAX

This guide walks you through getting PAX on GitHub with automated multi-platform builds.

## Step 1: Publish to GitHub (Using VS Code)

### 1.1 Initialize and Commit
1. Open VS Code with your PAX project
2. Open Source Control panel (Ctrl+Shift+G)
3. Click "Initialize Repository" if needed
4. Stage all files by clicking "+" next to "Changes"
5. Write commit message: "Initial PAX project with multi-platform support"
6. Click checkmark to commit

### 1.2 Publish to GitHub
1. Click "Publish to GitHub" in Source Control panel
2. Choose "Public" or "Private" repository
3. Name it: `purview-audit-exporter` or `PAX`
4. Click "Publish to GitHub"

VS Code will create the repository and upload your code automatically.

### 1.3 Verify Upload
1. Go to [github.com](https://github.com) in your browser
2. Navigate to your repositories
3. Open your new PAX repository
4. Confirm all files are present, including `.github/workflows/build-release.yml`

## Step 2: Test Automated Builds

### Option A: Manual Test Build
1. Go to your GitHub repository
2. Click "Actions" tab
3. Click "Build Multi-Platform Release" workflow
4. Click "Run workflow" → enter "v1.0.0-test" → "Run workflow"
5. Wait 15-20 minutes for build to complete
6. Download artifacts to test (Windows .exe, Mac .zip files)

### Option B: Create Official Release
1. In VS Code terminal, run:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. This triggers build AND creates a GitHub release
3. Go to your repo → "Releases" to see the published downloads

## Step 3: Distribute to Users

### For Windows Users:
- Direct them to your GitHub releases page
- They download `PAX-Windows-Portable.exe`
- No installation required - just run the .exe

### For Mac Users:
- Direct them to your GitHub releases page  
- They download appropriate .zip file:
  - `PAX-macOS-AppleSilicon.zip` for M1/M2/M3 Macs
  - `PAX-macOS-Intel.zip` for Intel Macs
- Extract and right-click app → "Open"

## Troubleshooting

### Build Fails:
- Check "Actions" tab for error details
- Common issues: syntax errors in workflow file, missing dependencies
- Re-run failed jobs after fixes

### Can't Push to GitHub:
- Ensure VS Code is signed into the correct GitHub account
- Check repository permissions
- Try cloning and re-uploading if needed

### Downloads Don't Work:
- Verify builds completed successfully in Actions tab
- Check that release was created in "Releases" section
- Ensure artifacts were uploaded (visible in completed workflow)

## Updating Releases

To create new versions:

1. Make your code changes
2. Commit and push to main branch
3. Create new tag: `git tag v1.0.1 && git push origin v1.0.1`
4. GitHub automatically builds and publishes new release

## Support

- **Build Issues**: Check GitHub Actions logs
- **Distribution Issues**: Verify files in Releases section
- **User Issues**: Direct them to the README or user guides

---

**Ready?** Start with Step 1 to get your PAX project on GitHub!