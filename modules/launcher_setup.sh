#!/bin/bash
# =============================================================================
# LAUNCHER SETUP MODULE
# =============================================================================
# @file        launcher_setup.sh
# @version     3.0.1
# @date        2026-03-31
# @author      aradanmn
# @license     MIT
# @repository  https://github.com/aradanmn/MinecraftSplitscreenSteamdeck
#
# @description
#   Handles launcher detection, installation, and CLI verification.
#   Supports both PineconeMC and PrismLauncher.
#   The launcher is used for automated Minecraft instance creation via CLI,
#   providing reliable instance management and Fabric loader installation.
#
#   On immutable Linux systems (Bazzite, SteamOS, etc.), this module prefers
#   installing via Flatpak. On traditional systems, it downloads the AppImage
#   from GitHub releases.
#
# @dependencies
#   - curl (for GitHub API queries)
#   - jq (for JSON parsing)
#   - wget (for downloading AppImage)
#   - flatpak (optional, for Flatpak installation)
#   - utilities.sh (for print_* functions)
#   - path_configuration.sh (for path constants, setters, and PREFER_FLATPAK)
#   - vars.sh (for launcher configuration and URLs)
#
# @exports
#   Functions:
#     - download_launcher : Detect or install launcher
#     - verify_cli        : Verify CLI capabilities
#     - get_executable    : Get executable path/command
#
#   Variables:
#     - LAUNCHER_INSTALL_TYPE : Installation type (appimage/flatpak)
#     - LAUNCHER_EXECUTABLE   : Path or command to run launcher
#
# @changelog
#   3.0.1 (2026-03-31) - Added PineconeMC support via vars.sh configuration
#   2.2.3 (2026-01-31) - Fix: Add --system flag to avoid flatpak remote selection prompt
#   2.2.2 (2026-01-25) - Fix: Try system-level Flatpak install first, then user-level
#   2.2.1 (2026-01-25) - Fix: Only create directories after successful download
#   2.2.0 (2026-01-25) - Use PREFER_FLATPAK from path_configuration
#   2.1.0 (2026-01-24) - Added Flatpak preference for immutable OS, arch detection
#   2.0.0 (2026-01-23) - Refactored to use centralized path configuration
#   1.0.0 (2026-01-22) - Initial version
# =============================================================================

# =============================================================================
# LOAD LAUNCHER VARIABLES
# =============================================================================
# Source vars.sh for launcher configuration (if not already loaded)
if [[ -z "${LAUNCHER_NAME:-}" ]]; then
    if [[ -f "${SCRIPT_DIR:-}/vars.sh" ]]; then
        source "${SCRIPT_DIR}/vars.sh"
    elif [[ -f "${SCRIPT_DIR:-}/../vars.sh" ]]; then
        source "${SCRIPT_DIR}/../vars.sh"
    elif [[ -f "./vars.sh" ]]; then
        source "./vars.sh"
    fi
fi

# Module-level variables for tracking installation
LAUNCHER_INSTALL_TYPE=""
LAUNCHER_EXECUTABLE=""

# -----------------------------------------------------------------------------
# @function    download_launcher
# @description Detects existing launcher installation or installs it.
#              Uses different strategies based on the operating system:
#
#              On immutable OS (Bazzite, SteamOS, etc.):
#              1) Use existing Flatpak if installed
#              2) Install Flatpak from Flathub
#              3) Use existing AppImage if present
#              4) Download AppImage from GitHub
#
#              On traditional OS:
#              1) Use existing Flatpak if installed
#              2) Use existing AppImage if present
#              3) Download AppImage from GitHub
#
# @param       None
# @global      PREFER_FLATPAK         - (input) Whether to prefer Flatpak (from path_configuration)
# @global      LAUNCHER_FLATPAK_ID    - (input) Flatpak application ID (from vars.sh)
# @global      LAUNCHER_FLATPAK_DATA_DIR - (input) Flatpak data directory (from vars.sh)
# @global      LAUNCHER_APPIMAGE_PATH - (input) Expected AppImage location (from vars.sh)
# @global      LAUNCHER_APPIMAGE_DATA_DIR - (input) AppImage data directory (from vars.sh)
# @global      LAUNCHER_APPIMAGE_URL  - (input) Direct download URL for AppImage (from vars.sh)
# @global      LAUNCHER_API_URL       - (input) GitHub API URL for version detection (from vars.sh)
# @global      LAUNCHER_NAME          - (input) Launcher name (from vars.sh)
# @return      0 on success, exits on critical failure
# @sideeffect  Calls set_creation_launcher() to update paths
# -----------------------------------------------------------------------------
download_launcher() {
    print_progress "Detecting ${LAUNCHER_NAME:-launcher} installation..."

    # Priority 1: Check for existing Flatpak installation
    if is_flatpak_installed "$LAUNCHER_FLATPAK_ID" 2>/dev/null; then
        print_success "Found existing ${LAUNCHER_NAME} Flatpak installation"

        mkdir -p "$LAUNCHER_FLATPAK_DATA_DIR/instances"
        set_creation_launcher "flatpak" "flatpak run $LAUNCHER_FLATPAK_ID"
        print_info "   → Using Flatpak data directory: $LAUNCHER_FLATPAK_DATA_DIR"
        return 0
    fi

    # Priority 2 (immutable OS only): Install Flatpak if preferred
    # PREFER_FLATPAK is set by configure_launcher_paths() in path_configuration.sh
    if [[ "$PREFER_FLATPAK" == true ]]; then
        print_info "Immutable OS detected - preferring Flatpak installation"

        if command -v flatpak &>/dev/null; then
            print_progress "Installing ${LAUNCHER_NAME} via Flatpak..."

            local flatpak_installed=false

            # Try system-level install first (works on Bazzite/SteamOS where Flathub is system-only)
            # Use --system explicitly to avoid flatpak's remote selection prompt when both system
            # and user flathub remotes exist. This may prompt for authentication on some systems.
            if flatpak install --system -y flathub "$LAUNCHER_FLATPAK_ID" 2>/dev/null; then
                flatpak_installed=true
                print_success "${LAUNCHER_NAME} Flatpak installed (system)"
            else
                # Fall back to user-level install
                # First ensure Flathub repo is available for user
                if ! flatpak remote-list --user 2>/dev/null | grep -q flathub; then
                    print_progress "Adding Flathub repository for user..."
                    flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
                fi

                if flatpak install --user -y flathub "$LAUNCHER_FLATPAK_ID" 2>/dev/null; then
                    flatpak_installed=true
                    print_success "${LAUNCHER_NAME} Flatpak installed (user)"
                fi
            fi

            if [[ "$flatpak_installed" == true ]]; then
                mkdir -p "$LAUNCHER_FLATPAK_DATA_DIR/instances"
                set_creation_launcher "flatpak" "flatpak run $LAUNCHER_FLATPAK_ID"
                print_info "   → Using Flatpak data directory: $LAUNCHER_FLATPAK_DATA_DIR"
                return 0
            else
                print_warning "Flatpak installation failed - falling back to AppImage"
            fi
        else
            print_warning "Flatpak not available - falling back to AppImage"
        fi
    fi

    # Priority 3: Check for existing AppImage
    if [[ -f "$LAUNCHER_APPIMAGE_PATH" ]]; then
        print_success "${LAUNCHER_NAME} AppImage already present"

        set_creation_launcher "appimage" "$LAUNCHER_APPIMAGE_PATH"
        return 0
    fi

    # Priority 4: Download AppImage
    print_progress "No existing ${LAUNCHER_NAME} found - downloading AppImage..."

    # Use direct URL from vars.sh if available (PineconeMC has fixed URL)
    local appimage_url="$LAUNCHER_APPIMAGE_URL"

    # If no direct URL (PrismLauncher), query GitHub API for latest release
    if [[ -z "$appimage_url" ]] && [[ -n "$LAUNCHER_API_URL" ]]; then
        print_info "Querying GitHub API for latest ${LAUNCHER_NAME} release..."
        local arch
        arch=$(uname -m)

        appimage_url=$(curl -s "${LAUNCHER_API_URL}/releases/latest" | \
            jq -r --arg arch "$arch" '.assets[] | select(.name | test("AppImage$")) | select(.name | contains($arch)) | .browser_download_url' | head -n1)

        if [[ -z "$appimage_url" || "$appimage_url" == "null" ]]; then
            print_error "Could not find latest ${LAUNCHER_NAME} AppImage URL."
            print_error "Please check the releases page manually."
            exit 1
        fi
    fi

    if [[ -z "$appimage_url" ]]; then
        print_error "No download URL available for ${LAUNCHER_NAME}."
        print_error "Please check vars.sh configuration."
        exit 1
    fi

    # Download to temp location first, only create directory on success
    local temp_appimage
    temp_appimage=$(mktemp)

    print_progress "Downloading from: $appimage_url"
    if ! wget -q -O "$temp_appimage" "$appimage_url"; then
        print_error "Failed to download ${LAUNCHER_NAME} AppImage."
        rm -f "$temp_appimage" 2>/dev/null
        exit 1
    fi

    # Download successful - now create directory and move file
    mkdir -p "$LAUNCHER_APPIMAGE_DATA_DIR"
    mv "$temp_appimage" "$LAUNCHER_APPIMAGE_PATH"
    chmod +x "$LAUNCHER_APPIMAGE_PATH"

    set_creation_launcher "appimage" "$LAUNCHER_APPIMAGE_PATH"
    print_success "${LAUNCHER_NAME} AppImage downloaded successfully"
    print_info "   → Installation type: appimage"
    print_info "   → Location: $LAUNCHER_APPIMAGE_PATH"
}

# -----------------------------------------------------------------------------
# @function    download_prism_launcher
# @description Legacy wrapper for download_launcher for backward compatibility
# @deprecated  Use download_launcher instead
# -----------------------------------------------------------------------------
download_prism_launcher() {
    download_launcher
}

# -----------------------------------------------------------------------------
# @function    verify_cli
# @description Verifies that the launcher supports CLI operations needed for
#              automated instance creation. Tests the --help output for CLI
#              keywords. If AppImage fails due to FUSE issues, attempts to
#              extract and run directly.
#
# @param       None
# @global      CREATION_LAUNCHER_TYPE - (input) "appimage" or "flatpak"
# @global      CREATION_EXECUTABLE    - (input/output) May be updated if extracted
# @global      CREATION_DATA_DIR      - (input) Data directory for extraction
# @global      LAUNCHER_FLATPAK_ID    - (input) Flatpak application ID (from vars.sh)
# @return      0 if CLI verified, 1 if CLI not available
# @note        Returns 1 (not exit) to allow fallback to manual creation
# -----------------------------------------------------------------------------
verify_cli() {
    print_progress "Verifying ${LAUNCHER_NAME:-launcher} CLI capabilities..."

    local launcher_exec=""
    local help_output=""
    local exit_code=0

    # Determine the executable based on installation type
    if [[ "$CREATION_LAUNCHER_TYPE" == "flatpak" ]]; then
        launcher_exec="flatpak run $LAUNCHER_FLATPAK_ID"
        print_info "   → Testing Flatpak CLI..."

        help_output=$($launcher_exec --help 2>&1)
        exit_code=$?

        if [[ $exit_code -ne 0 ]]; then
            print_warning "${LAUNCHER_NAME} Flatpak CLI test failed"
            print_info "Error output: $(echo "$help_output" | head -3)"
            return 1
        fi
    else
        # AppImage path
        local appimage="$CREATION_EXECUTABLE"

        chmod +x "$appimage" 2>/dev/null || true
        help_output=$("$appimage" --help 2>&1)
        exit_code=$?

        # Check if AppImage failed due to FUSE issues
        if [[ $exit_code -ne 0 ]] && echo "$help_output" | grep -q "FUSE\|Cannot mount\|squashfs\|Failed to open"; then
            print_warning "AppImage execution failed due to FUSE/squashfs issues"

            # Try extracting AppImage to avoid FUSE dependency
            print_progress "Attempting to extract AppImage contents..."
            cd "$CREATION_DATA_DIR"
            local extracted_path="$CREATION_DATA_DIR/squashfs-root/AppRun"
            if "$appimage" --appimage-extract >/dev/null 2>&1; then
                if [[ -d "$CREATION_DATA_DIR/squashfs-root" ]] && [[ -x "$extracted_path" ]]; then
                    print_success "AppImage extracted successfully"
                    CREATION_EXECUTABLE="$extracted_path"
                    launcher_exec="$CREATION_EXECUTABLE"
                    help_output=$("$launcher_exec" --help 2>&1)
                    exit_code=$?
                else
                    print_warning "AppImage extraction failed or incomplete"
                    print_info "Will skip CLI creation and use manual instance creation method"
                    return 1
                fi
            else
                print_warning "AppImage extraction failed"
                print_info "Will skip CLI creation and use manual instance creation method"
                return 1
            fi
        fi

        launcher_exec="${LAUNCHER_EXECUTABLE:-$appimage}"
    fi

    # Check if help command worked
    if [[ $exit_code -ne 0 ]]; then
        print_warning "${LAUNCHER_NAME} execution failed, using manual instance creation"
        print_info "Error output: $(echo "$help_output" | head -3)"
        return 1
    fi

    # Test for CLI support by checking help output
    if ! echo "$help_output" | grep -q -E "(cli|create|instance)"; then
        print_warning "${LAUNCHER_NAME} CLI may not support instance creation. Checking with --help-all..."

        local extended_help
        extended_help=$($launcher_exec --help-all 2>&1)
        if ! echo "$extended_help" | grep -q -E "(cli|create-instance)"; then
            print_warning "This version of ${LAUNCHER_NAME} does not support CLI instance creation"
            print_info "Will use manual instance creation method instead"
            return 1
        fi
    fi

    print_info "Available ${LAUNCHER_NAME} CLI commands:"
    echo "$help_output" | grep -E "(create|instance|cli)" || echo "  (Basic CLI commands found)"
    print_success "${LAUNCHER_NAME} CLI instance creation verified ($CREATION_LAUNCHER_TYPE)"
    return 0
}

# -----------------------------------------------------------------------------
# @function    verify_prism_cli
# @description Legacy wrapper for verify_cli for backward compatibility
# @deprecated  Use verify_cli instead
# -----------------------------------------------------------------------------
verify_prism_cli() {
    verify_cli
}

# -----------------------------------------------------------------------------
# @function    get_executable
# @description Returns the launcher executable command or path from the
#              centralized path configuration.
#
# @param       None
# @global      CREATION_EXECUTABLE - (input) Executable path/command
# @stdout      Executable path or command
# @return      0 if executable set, 1 if not configured
# -----------------------------------------------------------------------------
get_executable() {
    if [[ -n "$CREATION_EXECUTABLE" ]]; then
        echo "$CREATION_EXECUTABLE"
    else
        echo ""
        return 1
    fi
}

# -----------------------------------------------------------------------------
# @function    get_prism_executable
# @description Legacy wrapper for get_executable for backward compatibility
# @deprecated  Use get_executable instead
# -----------------------------------------------------------------------------
get_prism_executable() {
    get_executable
}
