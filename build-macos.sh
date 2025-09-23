#!/bin/bash

# Build PAX for macOS
# This script builds both Intel and Apple Silicon versions

set -e

echo "🍎 Building PAX for macOS..."

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install it from https://nodejs.org/"
    exit 1
fi

# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo "❌ Rust is not installed. Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
fi

# Install Rust targets for both architectures
echo "📦 Adding Rust targets..."
rustup target add aarch64-apple-darwin x86_64-apple-darwin

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build frontend
echo "🏗️  Building frontend..."
npm run build

# Build for Apple Silicon
echo "🏗️  Building for Apple Silicon (M1/M2/M3)..."
npm run tauri build -- --target aarch64-apple-darwin

# Build for Intel
echo "🏗️  Building for Intel Macs..."
npm run tauri build -- --target x86_64-apple-darwin

# Create distribution packages
echo "📦 Creating distribution packages..."

# Create dist directory
mkdir -p dist

# Package Apple Silicon version
if [ -d "src-tauri/target/aarch64-apple-darwin/release/bundle/macos" ]; then
    echo "📦 Packaging Apple Silicon version..."
    cd "src-tauri/target/aarch64-apple-darwin/release/bundle/macos"
    zip -r "../../../../../dist/PAX-macOS-AppleSilicon.zip" "Purview Audit eXporter (PAX).app"
    cd - > /dev/null
fi

# Package Intel version
if [ -d "src-tauri/target/x86_64-apple-darwin/release/bundle/macos" ]; then
    echo "📦 Packaging Intel version..."
    cd "src-tauri/target/x86_64-apple-darwin/release/bundle/macos"
    zip -r "../../../../../dist/PAX-macOS-Intel.zip" "Purview Audit eXporter (PAX).app"
    cd - > /dev/null
fi

echo "✅ Build complete!"
echo ""
echo "📁 Built applications:"
echo "   • Apple Silicon: dist/PAX-macOS-AppleSilicon.zip"
echo "   • Intel:         dist/PAX-macOS-Intel.zip"
echo ""
echo "📱 To test locally:"
echo "   Apple Silicon: src-tauri/target/aarch64-apple-darwin/release/bundle/macos/"
echo "   Intel:         src-tauri/target/x86_64-apple-darwin/release/bundle/macos/"
echo ""
echo "🚀 Ready for distribution!"