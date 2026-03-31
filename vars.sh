#!/bin/bash
# =============================================================================
# LAUNCHER VARIABLES AND URLS CONFIGURATION
# =============================================================================
# @file        vars.sh
# @version     1.0.0
# @date        2026-03-31
# @author      aradanmn (modified for PineconeMC by goosedev72)
# @license     MIT
# @repository  https://github.com/aradanmn/MinecraftSplitscreenSteamdeck
#
# @description
#   Centralized configuration file for all launcher-specific variables,
#   download URLs, Flatpak IDs, and platform-specific settings.
#
#   This file contains all the magic numbers and URLs that were previously
#   hardcoded throughout the installer scripts. Edit this file to change
#   launchers or update download sources.
#
# @usage
#   Source this file early in your script:
#     source "vars.sh"
#
#   Then use the exported variables:
#     echo "$LAUNCHER_NAME"
#     echo "$LAUNCHER_APPIMAGE_URL"
#
# =============================================================================

# =============================================================================
# ACTIVE LAUNCHER SELECTION
# =============================================================================
# Change this to switch between different launchers
# Available options: "pineconemc", "prismlauncher"
readonly ACTIVE_LAUNCHER_NAME="pineconemc"

# =============================================================================
# PINECONEMC CONFIGURATION
# =============================================================================
# PineconeMC is a fork of PrismLauncher with additional features
# GitHub: https://github.com/ElyPrismLauncher/Launcher
# Flatpak: https://elyprismlauncher.github.io/elyprismlauncher.flatpakref

readonly PINECONEMC_NAME="PineconeMC"
readonly PINECONEMC_FLATPAK_ID="org.elyprismlauncher.ElyPrismLauncher"
readonly PINECONEMC_FLATPAK_REF="https://elyprismlauncher.github.io/elyprismlauncher.flatpakref"
readonly PINECONEMC_APPIMAGE_DATA_DIR="$HOME/.local/share/PineconeMC"
readonly PINECONEMC_FLATPAK_DATA_DIR="$HOME/.var/app/${PINECONEMC_FLATPAK_ID}/data/PineconeMC"
readonly PINECONEMC_APPIMAGE_PATH="$PINECONEMC_APPIMAGE_DATA_DIR/PineconeMC.AppImage"

# PineconeMC release URL (specific version)
# Format: https://github.com/ElyPrismLauncher/Launcher/releases/download/{VERSION}/{FILENAME}
readonly PINECONEMC_VERSION="11.0.0-pre1"
readonly PINECONEMC_APPIMAGE_URL="https://github.com/ElyPrismLauncher/Launcher/releases/download/${PINECONEMC_VERSION}/PineconeMC-Linux-x86_64.AppImage"

# PineconeMC GitHub API URL for version detection
readonly PINECONEMC_API_URL="https://api.github.com/repos/ElyPrismLauncher/Launcher"

# PineconeMC Flatpak repository
readonly PINECONEMC_FLATPAK_REPO_URL="https://elyprismlauncher.github.io/elyprismlauncher.flatpakref"

# =============================================================================
# PRISMLAUNCHER CONFIGURATION (Fallback/Alternative)
# =============================================================================
# Original PrismLauncher configuration
# GitHub: https://github.com/PrismLauncher/PrismLauncher

readonly PRISMLAUNCHER_NAME="PrismLauncher"
readonly PRISMLAUNCHER_FLATPAK_ID="org.prismlauncher.PrismLauncher"
readonly PRISMLAUNCHER_APPIMAGE_DATA_DIR="$HOME/.local/share/PrismLauncher"
readonly PRISMLAUNCHER_FLATPAK_DATA_DIR="$HOME/.var/app/${PRISMLAUNCHER_FLATPAK_ID}/data/PrismLauncher"
readonly PRISMLAUNCHER_APPIMAGE_PATH="$PRISMLAUNCHER_APPIMAGE_DATA_DIR/PrismLauncher.AppImage"

# PrismLauncher GitHub API URL for latest release detection
readonly PRISMLAUNCHER_API_URL="https://api.github.com/repos/PrismLauncher/PrismLauncher"

# =============================================================================
# LAUNCHER TYPE DETECTION
# =============================================================================
# Helper function to get current launcher configuration
# @return Sets LAUNCHER_* variables based on ACTIVE_LAUNCHER_NAME

get_launcher_config() {
    case "$ACTIVE_LAUNCHER_NAME" in
        "pineconemc")
            LAUNCHER_NAME="$PINECONEMC_NAME"
            LAUNCHER_FLATPAK_ID="$PINECONEMC_FLATPAK_ID"
            LAUNCHER_APPIMAGE_DATA_DIR="$PINECONEMC_APPIMAGE_DATA_DIR"
            LAUNCHER_FLATPAK_DATA_DIR="$PINECONEMC_FLATPAK_DATA_DIR"
            LAUNCHER_APPIMAGE_PATH="$PINECONEMC_APPIMAGE_PATH"
            LAUNCHER_APPIMAGE_URL="$PINECONEMC_APPIMAGE_URL"
            LAUNCHER_API_URL="$PINECONEMC_API_URL"
            LAUNCHER_VERSION="$PINECONEMC_VERSION"
            ;;
        "prismlauncher")
            LAUNCHER_NAME="$PRISMLAUNCHER_NAME"
            LAUNCHER_FLATPAK_ID="$PRISMLAUNCHER_FLATPAK_ID"
            LAUNCHER_APPIMAGE_DATA_DIR="$PRISMLAUNCHER_APPIMAGE_DATA_DIR"
            LAUNCHER_FLATPAK_DATA_DIR="$PRISMLAUNCHER_FLATPAK_DATA_DIR"
            LAUNCHER_APPIMAGE_PATH="$PRISMLAUNCHER_APPIMAGE_PATH"
            # For PrismLauncher, we fetch latest from API
            LAUNCHER_APPIMAGE_URL=""  # Will be set by API call
            LAUNCHER_API_URL="$PRISMLAUNCHER_API_URL"
            LAUNCHER_VERSION=""  # Will be set by API call
            ;;
        *)
            echo "Error: Unknown launcher '$ACTIVE_LAUNCHER_NAME'" >&2
            return 1
            ;;
    esac
}

# =============================================================================
# FLATPAK CONFIGURATION
# =============================================================================
readonly FLATHUB_REPO="https://dl.flathub.org/repo/flathub.flatpakrepo"
readonly FLATHUB_NAME="flathub"

# =============================================================================
# SYSTEM PATHS
# =============================================================================
readonly JAVA_INSTALL_DIR="$HOME/.local/jdk"
readonly LOGS_DIR="$HOME/.local/share/MinecraftSplitscreen/logs"
readonly DESKTOP_DIR="$HOME/Desktop"
readonly APPLICATIONS_DIR="$HOME/.local/share/applications"

# =============================================================================
# MINECRAFT SPLITSREEN SCRIPT PATHS
# =============================================================================
# These paths are relative to the launcher data directory
readonly SPLITSREEN_SCRIPT_NAME="minecraftSplitscreen.sh"
readonly INSTANCES_SUBDIR="instances"
readonly LWJGL_SUBDIR="lwjgl"
readonly MODS_SUBDIR="mods"

# =============================================================================
# API ENDPOINTS
# =============================================================================
# Modrinth API
readonly MODRINTH_API_BASE="https://api.modrinth.com/v2"
readonly MODRINTH_SEARCH_URL="${MODRINTH_API_BASE}/search"
readonly MODRINTH_VERSION_URL="${MODRINTH_API_BASE}/version"

# CurseForge API (via Modrinth proxy or direct)
readonly CURSEFORGE_API_BASE="https://api.curseforge.com/v1"
readonly CURSEFORGE_SEARCH_URL="${CURSEFORGE_API_BASE}/search"

# =============================================================================
# REQUIRED MODS CONFIGURATION
# =============================================================================
# Format: "Mod Name|platform|mod_id"
# These mods are always installed for splitscreen functionality
declare -a REQUIRED_SPLITSCREEN_MODS=(
    "Controllable (Fabric)"
    "Splitscreen Support"
)

declare -a REQUIRED_SPLITSCREEN_IDS=(
    "317269"
    "yJgqfSDR"
)

# =============================================================================
# OPTIONAL MODS CONFIGURATION
# =============================================================================
# Full list of available optional mods with their metadata
declare -a OPTIONAL_MODS=(
    "Better Name Visibility|modrinth|pSfNeCCY"
    "Full Brightness Toggle|modrinth|aEK1KhsC"
    "In-Game Account Switcher|modrinth|cudtvDnd"
    "Just Zoom|modrinth|iAiqcykM"
    "Legacy4J|modrinth|gHvKJofA"
    "Mod Menu|modrinth|mOgUt4GM"
    "Old Combat Mod|modrinth|dZ1APLkO"
    "Reese's Sodium Options|modrinth|Bh37bMuy"
    "Sodium|modrinth|AANobbMI"
    "Sodium Dynamic Lights|modrinth|PxQSWIcD"
    "Sodium Extra|modrinth|PtjYWJkn"
    "Sodium Extras|modrinth|vqqx0QiE"
    "Sodium Options API|modrinth|Es5v4eyq"
)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# @function    is_launcher_flatpak
# @description Checks if the active launcher should use Flatpak
# @param       $1 - launcher type: "appimage" or "flatpak"
# @return      0 if flatpak, 1 otherwise
# -----------------------------------------------------------------------------
is_launcher_flatpak() {
    [[ "$1" == "flatpak" ]]
}

# -----------------------------------------------------------------------------
# @function    get_launcher_data_dir
# @description Returns the data directory for the active launcher
# @param       $1 - launcher type: "appimage" or "flatpak"
# @stdout      Data directory path
# @return      0 always
# -----------------------------------------------------------------------------
get_launcher_data_dir() {
    local type="$1"
    if is_launcher_flatpak "$type"; then
        echo "$LAUNCHER_FLATPAK_DATA_DIR"
    else
        echo "$LAUNCHER_APPIMAGE_DATA_DIR"
    fi
}

# -----------------------------------------------------------------------------
# @function    get_launcher_instances_dir
# @description Returns the instances directory for the active launcher
# @param       $1 - launcher type: "appimage" or "flatpak"
# @stdout      Instances directory path
# @return      0 always
# -----------------------------------------------------------------------------
get_launcher_instances_dir() {
    local data_dir
    data_dir=$(get_launcher_data_dir "$1")
    echo "${data_dir}/${INSTANCES_SUBDIR}"
}

# -----------------------------------------------------------------------------
# @function    print_launcher_info
# @description Prints information about the active launcher
# @return      0 always
# -----------------------------------------------------------------------------
print_launcher_info() {
    echo "Active Launcher: $LAUNCHER_NAME"
    echo "AppImage Path: $LAUNCHER_APPIMAGE_PATH"
    echo "Flatpak ID: $LAUNCHER_FLATPAK_ID"
    if [[ -n "$LAUNCHER_VERSION" ]]; then
        echo "Version: $LAUNCHER_VERSION"
    fi
}

# Auto-execute launcher config on source
get_launcher_config
