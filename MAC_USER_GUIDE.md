# PAX for Mac - Quick Start Guide

## What is PAX?

PAX (Purview Audit eXporter) is a simple app that helps you export Microsoft Purview audit data for analysis. It works with Microsoft 365 and requires no installation.

## How to Get PAX for Your Mac

### Method 1: Download Ready-to-Use App (Recommended)

1. Go to the PAX releases page: https://github.com/Rance9/PAX/releases
2. Download the latest **"PAX-vX.X.X-macOS-Universal.zip"** file
   - This single file works on ALL Mac computers (Intel & Apple Silicon)
3. **Double-click the ZIP file** to extract it
4. You should see a **"PAX.app"** or **"Portable Audit eXporter.app"** file
5. **Right-click** on the .app file and select **"Open"**
6. If you see a security warning, click **"Open"** to confirm
7. The app will start - no installation needed!

## Important: If You See Source Code Files

If your download shows folders like "scripts", "src", etc. instead of just an app:

- Look for a file ending in **.app**
- That's the actual application to run
- The other folders are not needed and can be ignored

### Method 2: Build It Yourself (Advanced Users)

If you're comfortable with Terminal and want to build from source, see `BUILD_MACOS.md` for detailed instructions.

## First Time Setup

When you first run PAX:

1. **PowerShell**: The app will check if PowerShell is installed and guide you if needed
2. **Microsoft Graph**: You'll be prompted to install required Microsoft modules
3. **Authentication**: You'll sign in with your Microsoft 365 account
4. **Permissions**: The app only needs read access to audit logs

## Using PAX

1. **Choose Activities**: Select which Microsoft 365 activities to export
2. **Set Date Range**: Pick the time period for your export
3. **Export**: Click "Export Script to File" to save the PowerShell script
4. **Run Script**: Open Terminal and run the saved script
5. **Get Results**: Your audit data will be saved as CSV files

## Troubleshooting

## Troubleshooting

### "App is damaged and can't be opened" or Security Warning

This is a common macOS security feature for unsigned apps. Try these solutions:

**Method 1 - Remove Quarantine (Recommended):**

1. Open Terminal (Applications → Utilities → Terminal)
2. Run this command (replace path with your app location):

```bash
xattr -d com.apple.quarantine "/path/to/Portable Audit eXporter (PAX).app"
```

3. Example if in Downloads folder:

```bash
xattr -d com.apple.quarantine "~/Downloads/Portable Audit eXporter (PAX).app"
```

4. Press Enter, then try opening the app normally

**Method 2 - Control+Click:**

1. Hold Control and click the app (don't right-click)
2. Choose "Open" from the menu
3. Click "Open" in the security dialog

**Method 3 - System Preferences:**

1. Try to open the app (it will fail)
2. Go to System Preferences → Security & Privacy → General
3. Look for a message about PAX being blocked
4. Click "Open Anyway"

### App won't start

- Right-click the app and choose "Open" (don't just double-click)
- Check System Preferences → Security & Privacy for blocked app notifications

### PowerShell issues

- The app will guide you through installing PowerShell if needed
- All required Microsoft modules are installed automatically

## Privacy & Security

- PAX runs locally on your Mac - no data is sent to third parties
- You authenticate directly with Microsoft using your own credentials
- The app only reads audit data you already have permission to access
- No admin privileges required - runs in your user account

## Getting Help

- Check the built-in help (? button in the app)
- Review the README.md file in the app folder
- Contact your IT administrator for Microsoft 365 account issues

---

**Ready to start?** Just right-click the app and choose "Open"!


