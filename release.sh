#!/bin/bash

# PAX Version Bump and Release Script
# Automatically updates version numbers, commits changes, and triggers GitHub release workflow

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_NAME="PAX Release Script"
PACKAGE_JSON="package.json"
TAURI_CONF="src-tauri/tauri.conf.json"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${CYAN}================================${NC}"
    echo -e "${CYAN}  $SCRIPT_NAME${NC}"
    echo -e "${CYAN}================================${NC}\n"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --patch             Increment patch version (1.0.21 → 1.0.22) [DEFAULT]"
    echo "  --minor             Increment minor version (1.0.21 → 1.1.0)"
    echo "  --major             Increment major version (1.0.21 → 2.0.0)"
    echo "  --message <text>    Custom commit message (optional)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Increment patch version"
    echo "  $0 --patch                                   # Increment patch version"
    echo "  $0 --minor                                   # Increment minor version"  
    echo "  $0 --major                                   # Increment major version"
    echo "  $0 --minor --message 'Added new features'   # Custom commit message"
    echo ""
}

# Function to get current version from package.json
get_current_version() {
    if [[ ! -f "$PACKAGE_JSON" ]]; then
        print_error "package.json not found!"
        exit 1
    fi
    
    # Extract version using node -p to handle JSON properly
    node -p "require('./$PACKAGE_JSON').version" 2>/dev/null || {
        print_error "Failed to read version from $PACKAGE_JSON"
        exit 1
    }
}

# Function to increment version based on type
increment_version() {
    local current_version="$1"
    local bump_type="$2"
    
    # Parse version components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case "$bump_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch"|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Function to update version in package.json
update_package_json() {
    local new_version="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$PACKAGE_JSON"
    else
        # Linux/Windows (Git Bash)
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$PACKAGE_JSON"
    fi
    
    print_success "Updated $PACKAGE_JSON to version $new_version"
}

# Function to update version in tauri.conf.json
update_tauri_conf() {
    local new_version="$1"
    
    # Update package version
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$TAURI_CONF"
        # Update window title
        sed -i '' "s/\"title\": \"Purview Audit eXporter (PAX) v[^\"]*\"/\"title\": \"Purview Audit eXporter (PAX) v$new_version\"/" "$TAURI_CONF"
    else
        # Linux/Windows (Git Bash)  
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$TAURI_CONF"
        # Update window title
        sed -i "s/\"title\": \"Purview Audit eXporter (PAX) v[^\"]*\"/\"title\": \"Purview Audit eXporter (PAX) v$new_version\"/" "$TAURI_CONF"
    fi
    
    print_success "Updated $TAURI_CONF to version $new_version (including window title)"
}

# Function to validate git status
check_git_status() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository!"
        exit 1
    fi
    
    # Check if we have uncommitted changes (excluding the files we're about to change)
    if git diff --quiet HEAD -- . ':!package.json' ':!src-tauri/tauri.conf.json' && 
       git diff --cached --quiet HEAD -- . ':!package.json' ':!src-tauri/tauri.conf.json'; then
        print_status "Git working directory is clean (except version files)"
    else
        print_warning "You have uncommitted changes other than version files."
        echo -n "Do you want to continue? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_error "Aborting due to uncommitted changes"
            exit 1
        fi
    fi
}

# Function to create commit and tag
commit_and_tag() {
    local new_version="$1"
    local bump_type="$2"
    local custom_message="$3"
    
    # Add the version files
    git add "$PACKAGE_JSON" "$TAURI_CONF"
    
    # Create commit message - use custom message if provided, otherwise auto-generate
    local commit_msg
    if [[ -n "$custom_message" ]]; then
        commit_msg="v${new_version}: $custom_message"
    else
        case "$bump_type" in
            "major")
                commit_msg="v${new_version}: Major version release"
                ;;
            "minor")
                commit_msg="v${new_version}: Minor version release"
                ;;
            "patch"|*)
                commit_msg="v${new_version}: Patch version release"
                ;;
        esac
    fi
    
    # Commit the changes
    git commit -m "$commit_msg"
    print_success "Created commit: $commit_msg"
    
    # Create and push tag
    git tag "v${new_version}"
    print_success "Created tag: v${new_version}"
    
    # Push changes and tag
    git push origin main
    git push origin "v${new_version}"
    print_success "Pushed changes and tag to GitHub"
}

# Function to show summary
show_summary() {
    local old_version="$1"
    local new_version="$2"
    local bump_type="$3"
    local commit_message="$4"
    
    echo -e "\n${GREEN}🎉 Release Summary${NC}"
    echo -e "${GREEN}==================${NC}"
    echo -e "• Old version: ${YELLOW}v${old_version}${NC}"
    echo -e "• New version: ${YELLOW}v${new_version}${NC}"
    echo -e "• Bump type:   ${YELLOW}${bump_type}${NC}"
    echo -e "• Git tag:     ${YELLOW}v${new_version}${NC}"
    echo -e "• Commit msg:  ${YELLOW}${commit_message}${NC}"
    echo ""
    echo -e "${CYAN}🚀 GitHub Actions workflow will now:${NC}"
    echo -e "   ✅ Build Windows executable"
    echo -e "   ✅ Build macOS executable"
    echo -e "   ✅ Create GitHub release page"
    echo -e "   ✅ Upload distribution files"
    echo ""
    echo -e "${BLUE}View progress at: https://github.com/Rance9/PAX/actions${NC}"
}

# Main function
main() {
    print_header
    
    # Parse command line arguments
    bump_type="patch"  # Default to patch
    custom_message=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --patch)
                bump_type="patch"
                shift
                ;;
            --minor)
                bump_type="minor"
                shift
                ;;
            --major)
                bump_type="major"
                shift
                ;;
            --message)
                custom_message="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Starting $bump_type version bump..."
    
    # Validate environment
    check_git_status
    
    # Get current version
    current_version=$(get_current_version)
    print_status "Current version: v${current_version}"
    
    # Calculate new version
    new_version=$(increment_version "$current_version" "$bump_type")
    print_status "New version: v${new_version}"
    
    # Prepare commit message
    local final_commit_msg
    if [[ -n "$custom_message" ]]; then
        final_commit_msg="v${new_version}: $custom_message"
    else
        case "$bump_type" in
            "major")
                final_commit_msg="v${new_version}: Major version release"
                ;;
            "minor")
                final_commit_msg="v${new_version}: Minor version release"
                ;;
            "patch"|*)
                final_commit_msg="v${new_version}: Patch version release"
                ;;
        esac
    fi
    
    # Confirm with user
    echo ""
    echo -e "${YELLOW}About to bump version:${NC}"
    echo -e "  From: ${CYAN}v${current_version}${NC}"
    echo -e "  To:   ${CYAN}v${new_version}${NC}"
    echo -e "  Type: ${CYAN}${bump_type}${NC}"
    echo -e "  Msg:  ${CYAN}${final_commit_msg}${NC}"
    echo ""
    echo -n "Continue? [Y/n]: "
    read -r response
    if [[ "$response" =~ ^[Nn]$ ]]; then
        print_warning "Version bump cancelled by user"
        exit 0
    fi
    
    # Update version files
    print_status "Updating version files..."
    update_package_json "$new_version"
    update_tauri_conf "$new_version"
    
    # Commit and tag
    print_status "Creating git commit and tag..."
    commit_and_tag "$new_version" "$bump_type" "$custom_message"
    
    # Show summary
    show_summary "$current_version" "$new_version" "$bump_type" "$final_commit_msg"
    
    print_success "Release process completed successfully! 🎉"
}

# Run main function with all arguments
main "$@"