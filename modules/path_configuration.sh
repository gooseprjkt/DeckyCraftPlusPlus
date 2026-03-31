#!/bin/bash
# =============================================================================
# PATH CONFIGURATION MODULE - SINGLE SOURCE OF TRUTH
# =============================================================================
# @file        path_configuration.sh
# @version     3.0.2
# @date        2026-03-15
# @author      aradanmn
# @license     MIT
# @repository  https://github.com/aradanmn/MinecraftSplitscreenSteamdeck
#
# @description
#   Centralizes ALL path definitions and launcher detection for the Minecraft
#   Splitscreen installer. All other modules MUST use these variables and
#   functions - DO NOT hardcode paths anywhere else.
#
#   PineconeMC (or PrismLauncher) is used for both instance creation and gameplay.
#   The CREATION and ACTIVE launcher variables both point to the active launcher.
#
# @dependencies
#   - flatpak (optional, for Flatpak detection)
#   - utilities.sh (for print_* functions, should_prefer_flatpak)
#   - vars.sh (for launcher configuration and URLs)
#
# @exports
#   Constants:
#     - LAUNCHER_FLATPAK_ID         : Launcher Flatpak application ID (from vars.sh)
#     - LAUNCHER_APPIMAGE_DATA_DIR  : Launcher AppImage data directory (from vars.sh)
#     - LAUNCHER_FLATPAK_DATA_DIR   : Launcher Flatpak data directory (from vars.sh)
#     - LAUNCHER_APPIMAGE_PATH      : Path to Launcher AppImage (from vars.sh)
#
#   Variables (set by configure_launcher_paths):
#     - PREFER_FLATPAK            : Whether to prefer Flatpak over AppImage (true/false)
#     - IMMUTABLE_OS_DETECTED     : Whether running on immutable OS (true/false)
#     - ACTIVE_LAUNCHER           : Active launcher name ("pineconemc" or "prismlauncher")
#     - ACTIVE_LAUNCHER_TYPE      : Active launcher type ("appimage"/"flatpak")
#     - ACTIVE_DATA_DIR           : Active launcher data directory
#     - ACTIVE_INSTANCES_DIR      : Active launcher instances directory
#     - ACTIVE_EXECUTABLE         : Command to run active launcher
#     - ACTIVE_LAUNCHER_SCRIPT    : Path to minecraftSplitscreen.sh
#     - CREATION_LAUNCHER         : Creation launcher name
#     - CREATION_LAUNCHER_TYPE    : Creation launcher type
#     - CREATION_DATA_DIR         : Creation launcher data directory
#     - CREATION_INSTANCES_DIR    : Creation launcher instances directory
#     - CREATION_EXECUTABLE       : Command to run creation launcher
#
#   Functions:
#     - is_flatpak_installed            : Check if Flatpak app is installed
#     - is_appimage_available           : Check if AppImage exists
#     - detect_launcher                 : Detect launcher installation
#     - configure_launcher_paths        : Main configuration function
#     - set_creation_launcher           : Set launcher as creation launcher
#     - finalize_launcher_paths         : Finalize and verify configuration
#     - get_creation_instances_dir      : Get creation instances directory
#     - get_active_instances_dir        : Get active instances directory
#     - get_launcher_script_path        : Get launcher script path
#     - get_active_executable           : Get active launcher executable
#     - get_active_data_dir             : Get active data directory
#     - needs_instance_migration        : Check if migration needed
#     - get_migration_source_dir        : Get migration source directory
#     - get_migration_dest_dir          : Get migration destination directory
#     - validate_path_configuration     : Validate all paths are set
#     - print_path_configuration        : Debug print all paths
#
# @changelog
#   3.0.2 (2026-03-31) - Added support for PineconeMC via vars.sh configuration
#   3.0.1 (2026-03-07) - Removed PollyMC; PrismLauncher is now the sole launcher
#   2.1.0 (2026-01-31) - Added architecture detection for PollyMC AppImage (x86_64/arm64)
#   2.0.2 (2026-01-25) - Fix: Don't create directories in configure_launcher_paths() detection phase
#   2.0.1 (2026-01-25) - Centralized PREFER_FLATPAK decision; set once, used by all modules
#   2.0.0 (2026-01-25) - Rebased to 2.x for fork; added comprehensive JSDoc documentation
#   1.1.1 (2026-01-25) - Prefer Flatpak over AppImage on immutable OS (Bazzite, SteamOS, etc.)
#   1.1.0 (2026-01-24) - Added revert_to_prismlauncher function
#   1.0.0 (2026-01-23) - Initial version with centralized path management
# =============================================================================

# =============================================================================
# LOAD LAUNCHER VARIABLES
# =============================================================================
# Source vars.sh for launcher configuration (if not already loaded)
# Always source vars.sh to ensure LAUNCHER_* variables are set
if [[ -f "${SCRIPT_DIR:-}/vars.sh" ]]; then
    source "${SCRIPT_DIR}/vars.sh"
elif [[ -f "${SCRIPT_DIR:-}/../vars.sh" ]]; then
    source "${SCRIPT_DIR}/../vars.sh"
elif [[ -f "./vars.sh" ]]; then
    source "./vars.sh"
fi

# =============================================================================
# LAUNCHER IDENTIFIERS (Constants - from vars.sh)
# =============================================================================
# Use LAUNCHER_FLATPAK_ID from vars.sh (defaults to ElyPrismLauncher)
# Fallback if vars.sh wasn't loaded
readonly PRISM_FLATPAK_ID="${LAUNCHER_FLATPAK_ID:-io.github.elyprismlauncher.ElyPrismLauncher}"

# =============================================================================
# BASE PATH DEFINITIONS (Constants - from vars.sh)
# =============================================================================
# AppImage data directories (where AppImage launchers store their data)
# Note: ElyPrismLauncher uses ~/.local/share/ElyPrismLauncher/ as data directory
readonly PRISM_APPIMAGE_DATA_DIR="${LAUNCHER_APPIMAGE_DATA_DIR:-$HOME/.local/share/ElyPrismLauncher}"

# Flatpak data directories (where Flatpak launchers store their data)
readonly PRISM_FLATPAK_DATA_DIR="${LAUNCHER_FLATPAK_DATA_DIR:-$HOME/.var/app/${PRISM_FLATPAK_ID}/data/ElyPrismLauncher}"

# AppImage executable location
readonly PRISM_APPIMAGE_PATH="${LAUNCHER_APPIMAGE_PATH:-$PRISM_APPIMAGE_DATA_DIR/ElyPrismLauncher.AppImage}"

# =============================================================================
# SYSTEM DETECTION VARIABLES
# =============================================================================
# These are set once by configure_launcher_paths() and used by all modules

# Whether to prefer Flatpak installations over AppImage
# Set based on OS type detection (immutable OS = prefer Flatpak)
PREFER_FLATPAK=false

# Whether an immutable OS was detected
IMMUTABLE_OS_DETECTED=false

# =============================================================================
# ACTIVE CONFIGURATION VARIABLES
# =============================================================================
# These are set by configure_launcher_paths() based on what's detected

# Primary launcher (the one used for gameplay)
ACTIVE_LAUNCHER=""           # "prismlauncher"
ACTIVE_LAUNCHER_TYPE=""      # "appimage" or "flatpak"
ACTIVE_DATA_DIR=""           # Where launcher stores its data
ACTIVE_INSTANCES_DIR=""      # Where instances are stored
ACTIVE_EXECUTABLE=""         # Command to run the launcher
ACTIVE_LAUNCHER_SCRIPT=""    # Path to minecraftSplitscreen.sh

# Creation launcher (used for initial instance creation)
CREATION_LAUNCHER=""         # "prismlauncher"
CREATION_LAUNCHER_TYPE=""    # "appimage" or "flatpak"
CREATION_DATA_DIR=""         # Where to create instances
CREATION_INSTANCES_DIR=""    # Instance creation directory
CREATION_EXECUTABLE=""       # Command to run creation launcher

# =============================================================================
# DETECTION FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# @function    is_flatpak_installed
# @description Checks if a Flatpak application is installed on the system.
# @param       $1 - Flatpak application ID (e.g., "org.prismlauncher.PrismLauncher")
# @return      0 if installed, 1 if not installed or flatpak unavailable
# @example
#   if is_flatpak_installed "org.prismlauncher.PrismLauncher"; then
#       echo "PrismLauncher Flatpak is installed"
#   fi
# -----------------------------------------------------------------------------
is_flatpak_installed() {
    local flatpak_id="$1"
    command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q "$flatpak_id"
}

# -----------------------------------------------------------------------------
# @function    is_appimage_available
# @description Checks if an AppImage file exists and is executable.
# @param       $1 - Full path to the AppImage file
# @return      0 if exists and executable, 1 otherwise
# @example
#   if is_appimage_available "$HOME/.local/share/PrismLauncher/PrismLauncher.AppImage"; then
#       echo "AppImage is ready to use"
#   fi
# -----------------------------------------------------------------------------
is_appimage_available() {
    local appimage_path="$1"
    [[ -f "$appimage_path" ]] && [[ -x "$appimage_path" ]]
}

# -----------------------------------------------------------------------------
# @function    detect_prismlauncher
# @description Detects if PrismLauncher is installed (AppImage or Flatpak).
#              Sets PRISM_TYPE, PRISM_DATA_DIR, and PRISM_EXECUTABLE variables.
#              Uses PREFER_FLATPAK (set by configure_launcher_paths) to determine
#              check order: Flatpak first on immutable OS, AppImage first otherwise.
# @param       None
# @global      PREFER_FLATPAK   - (input) Whether to prefer Flatpak
# @global      PRISM_DETECTED   - (output) Set to true/false
# @global      PRISM_TYPE       - (output) "appimage" or "flatpak"
# @global      PRISM_DATA_DIR   - (output) Path to data directory
# @global      PRISM_EXECUTABLE - (output) Command to run PrismLauncher
# @return      0 if detected, 1 if not found
# -----------------------------------------------------------------------------
detect_prismlauncher() {
    PRISM_DETECTED=false
    PRISM_TYPE=""
    PRISM_DATA_DIR=""
    PRISM_EXECUTABLE=""

    # Check order depends on PREFER_FLATPAK (set during system detection)
    if [[ "$PREFER_FLATPAK" == true ]]; then
        # Immutable OS: Check Flatpak first, then AppImage
        if is_flatpak_installed "$PRISM_FLATPAK_ID"; then
            PRISM_TYPE="flatpak"
            PRISM_DATA_DIR="$PRISM_FLATPAK_DATA_DIR"
            PRISM_EXECUTABLE="flatpak run $PRISM_FLATPAK_ID"
            print_info "Detected Flatpak PrismLauncher (preferred)"
            return 0
        fi

        if is_appimage_available "$PRISM_APPIMAGE_PATH"; then
            PRISM_TYPE="appimage"
            PRISM_DATA_DIR="$PRISM_APPIMAGE_DATA_DIR"
            PRISM_EXECUTABLE="$PRISM_APPIMAGE_PATH"
            print_info "Detected AppImage PrismLauncher (fallback)"
            return 0
        fi
    else
        # Traditional OS: Check AppImage first, then Flatpak
        if is_appimage_available "$PRISM_APPIMAGE_PATH"; then
            PRISM_TYPE="appimage"
            PRISM_DATA_DIR="$PRISM_APPIMAGE_DATA_DIR"
            PRISM_EXECUTABLE="$PRISM_APPIMAGE_PATH"
            print_info "Detected AppImage PrismLauncher (preferred)"
            return 0
        fi

        if is_flatpak_installed "$PRISM_FLATPAK_ID"; then
            PRISM_TYPE="flatpak"
            PRISM_DATA_DIR="$PRISM_FLATPAK_DATA_DIR"
            PRISM_EXECUTABLE="flatpak run $PRISM_FLATPAK_ID"
            print_info "Detected Flatpak PrismLauncher (fallback)"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# MAIN CONFIGURATION FUNCTION
# =============================================================================

# -----------------------------------------------------------------------------
# @function    configure_launcher_paths
# @description Main configuration function that detects PrismLauncher and sets
#              up CREATION_* and ACTIVE_* variables. This MUST be called early
#              in the installation process before any other module tries to
#              access launcher paths.
#
#              PrismLauncher is used for both instance creation (CLI) and
#              gameplay. Both CREATION_* and ACTIVE_* point to PrismLauncher.
#
# @param       None
# @global      All CREATION_* and ACTIVE_* variables are set
# @return      0 always
# -----------------------------------------------------------------------------
configure_launcher_paths() {
    print_header "DETECTING LAUNCHER CONFIGURATION"

    # =========================================================================
    # SYSTEM TYPE DETECTION (MUST BE FIRST)
    # =========================================================================
    # Detect if we're on an immutable OS and set PREFER_FLATPAK accordingly.
    # This decision is made ONCE here and used by all subsequent modules.

    if is_immutable_os; then
        IMMUTABLE_OS_DETECTED=true
        PREFER_FLATPAK=true
        print_info "Detected immutable OS: ${IMMUTABLE_OS_NAME:-unknown}"
        print_info "Flatpak installations will be preferred over AppImage"
    else
        IMMUTABLE_OS_DETECTED=false
        PREFER_FLATPAK=false
        print_info "Traditional Linux system detected"
        print_info "AppImage installations will be preferred"
    fi

    # =========================================================================
    # LAUNCHER DETECTION
    # =========================================================================

    # Use the launcher from vars.sh (PineconeMC or PrismLauncher)
    local launcher_name="${LAUNCHER_NAME:-PineconeMC}"
    
    if detect_prismlauncher; then
        CREATION_LAUNCHER="$launcher_name"
        CREATION_LAUNCHER_TYPE="$PRISM_TYPE"
        CREATION_DATA_DIR="$PRISM_DATA_DIR"
        CREATION_INSTANCES_DIR="$PRISM_DATA_DIR/instances"
        CREATION_EXECUTABLE="$PRISM_EXECUTABLE"
        print_success "Creation launcher: $launcher_name ($PRISM_TYPE)"
        print_info "  Data directory: $CREATION_DATA_DIR"
        print_info "  Instances: $CREATION_INSTANCES_DIR"

        ACTIVE_LAUNCHER="$launcher_name"
        ACTIVE_LAUNCHER_TYPE="$PRISM_TYPE"
        ACTIVE_DATA_DIR="$PRISM_DATA_DIR"
        ACTIVE_INSTANCES_DIR="$PRISM_DATA_DIR/instances"
        ACTIVE_EXECUTABLE="$PRISM_EXECUTABLE"
        ACTIVE_LAUNCHER_SCRIPT="$PRISM_DATA_DIR/minecraftSplitscreen.sh"
        print_success "Active launcher: $launcher_name ($PRISM_TYPE)"
        print_info "  Data directory: $ACTIVE_DATA_DIR"
        print_info "  Launcher script: $ACTIVE_LAUNCHER_SCRIPT"
    else
        CREATION_LAUNCHER=""
        print_warning "No $launcher_name detected - will attempt download"
    fi

    # NOTE: Directories are NOT created here during detection phase.
    # They are created later by launcher_setup.sh
    # only after successful installation/download to avoid empty directories.
}

# =============================================================================
# POST-DOWNLOAD CONFIGURATION FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# @function    set_creation_launcher
# @description Updates the creation launcher configuration after launcher
#              is downloaded or installed. Also sets ACTIVE_* variables if no
#              active launcher is configured yet.
# @param       $1 - type: "appimage" or "flatpak"
# @param       $2 - executable: Path or command to run launcher
# @global      CREATION_* variables are updated
# @global      ACTIVE_* variables may be updated if not set
# @return      0 always
# -----------------------------------------------------------------------------
set_creation_launcher() {
    local type="$1"
    local executable="$2"

    # Use LAUNCHER_NAME from vars.sh (ElyPrismLauncher or prismlauncher)
    local launcher_name="${LAUNCHER_NAME:-ElyPrismLauncher}"
    CREATION_LAUNCHER="$launcher_name"
    CREATION_LAUNCHER_TYPE="$type"

    if [[ "$type" == "appimage" ]]; then
        CREATION_DATA_DIR="${LAUNCHER_APPIMAGE_DATA_DIR:-$HOME/.local/share/ElyPrismLauncher}"
    else
        CREATION_DATA_DIR="${LAUNCHER_FLATPAK_DATA_DIR:-$HOME/.var/app/io.github.elyprismlauncher.ElyPrismLauncher/data/ElyPrismLauncher}"
    fi

    CREATION_INSTANCES_DIR="$CREATION_DATA_DIR/instances"
    CREATION_EXECUTABLE="$executable"

    mkdir -p "$CREATION_INSTANCES_DIR"

    # If no active launcher set yet, use current launcher
    if [[ -z "$ACTIVE_LAUNCHER" ]]; then
        ACTIVE_LAUNCHER="$launcher_name"
        ACTIVE_LAUNCHER_TYPE="$type"
        ACTIVE_DATA_DIR="$CREATION_DATA_DIR"
        ACTIVE_INSTANCES_DIR="$CREATION_INSTANCES_DIR"
        ACTIVE_EXECUTABLE="$executable"
        ACTIVE_LAUNCHER_SCRIPT="$ACTIVE_DATA_DIR/minecraftSplitscreen.sh"
    fi
}

# -----------------------------------------------------------------------------
# @function    set_creation_launcher_prismlauncher
# @description Legacy wrapper for set_creation_launcher for compatibility
# @deprecated  Use set_creation_launcher instead
# @param       $1 - type: "appimage" or "flatpak"
# @param       $2 - executable: Path or command to run PrismLauncher
# @global      CREATION_* variables are updated
# @global      ACTIVE_* variables may be updated if not set
# @return      0 always
# -----------------------------------------------------------------------------
set_creation_launcher_prismlauncher() {
    set_creation_launcher "$@"
}


# -----------------------------------------------------------------------------
# @function    finalize_launcher_paths
# @description Finalizes path configuration after all downloads and setup
#              are complete. Verifies that the active launcher and instance
#              directory are properly configured.
# @param       None
# @global      ACTIVE_* variables may be updated if verification fails
# @return      0 always
# -----------------------------------------------------------------------------
finalize_launcher_paths() {
    print_info "Finalizing launcher configuration..."

    print_success "Final configuration:"
    print_info "  Launcher: $ACTIVE_LAUNCHER ($ACTIVE_LAUNCHER_TYPE)"
    print_info "  Data: $ACTIVE_DATA_DIR"
    print_info "  Instances: $ACTIVE_INSTANCES_DIR"
    print_info "  Script: $ACTIVE_LAUNCHER_SCRIPT"
}
