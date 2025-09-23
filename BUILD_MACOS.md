# Building PAX for macOS

This guide provides multiple ways to get the Purview Audit eXporter (PAX) running on macOS.

## Option 1: Download Pre-built Release (Easiest)

1. Go to the [Releases page](../../releases) on GitHub
2. Download the appropriate ZIP file for your Mac:
   - **Apple Silicon Macs** (M1/M2/M3): `PAX-macOS-AppleSilicon.zip`
   - **Intel Macs**: `PAX-macOS-Intel.zip`
3. Extract the ZIP file
4. **Right-click** on `Purview Audit eXporter (PAX).app` and select **"Open"**
   - You may see a security warning about an unidentified developer
   - Click **"Open"** to confirm you want to run the app
5. The app will launch without requiring installation or admin privileges

## Option 2: Build Locally on Your Mac

If pre-built releases aren't available or you want to build from source:

### Prerequisites

1. **Install Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```

2. **Install Rust**:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

3. **Install Node.js** (if not already installed):
   - Download from [nodejs.org](https://nodejs.org/) or use Homebrew:
   ```bash
   brew install node
   ```

### Build Steps

1. **Clone or download this repository**
2. **Open Terminal** and navigate to the project folder
3. **Install dependencies**:
   ```bash
   npm install
   ```
4. **Build the application**:
   ```bash
   npm run tauri build
   ```
5. **Find your built app**:
   - The `.app` bundle will be in: `src-tauri/target/release/bundle/macos/`
   - You can move `Purview Audit eXporter (PAX).app` to your Applications folder

## Option 3: Build Specific Architecture

If you want to build for a specific Mac architecture:

```bash
# For Apple Silicon (M1/M2/M3)
npm run tauri build -- --target aarch64-apple-darwin

# For Intel Macs
npm run tauri build -- --target x86_64-apple-darwin
```

## Troubleshooting

### "App is damaged and can't be opened"

This happens because the app isn't code-signed. To fix this:

1. **Remove the quarantine attribute**:
   ```bash
   xattr -d com.apple.quarantine "/path/to/Purview Audit eXporter (PAX).app"
   ```

2. **Or allow unsigned apps** in System Preferences:
   - Go to **System Preferences** → **Security & Privacy** → **General**
   - Click **"Open Anyway"** next to the blocked app message

### PowerShell Module Requirements

The app uses PowerShell for Microsoft Graph authentication. On macOS, you'll need:

1. **PowerShell Core** (automatically detected by the app)
2. **Microsoft Graph PowerShell modules** (installed automatically by the script)

The app will guide you through any missing requirements when you first run it.

## Distribution

### For End Users (Simple Instructions)

1. Download the ZIP file appropriate for your Mac
2. Extract it by double-clicking the ZIP file
3. **Right-click** the app and choose **"Open"**
4. Click **"Open"** if you see a security warning
5. Use the app normally - no installation required!

### Creating a Simple Distribution Package

To create a user-friendly package:

1. Create a folder called `PAX for Mac`
2. Put the `.app` file inside
3. Add a `README.txt` with these instructions:
   ```
   Double-click "Purview Audit eXporter (PAX).app" to run.
   
   If you see a security warning:
   1. Right-click the app
   2. Choose "Open"
   3. Click "Open" in the dialog
   
   No installation required!
   ```
4. ZIP the entire folder: `PAX for Mac.zip`

This creates a single file that any Mac user can download, extract, and run without technical knowledge or admin privileges.