#!/bin/bash
# =============================================================================
# BUILD VARIABLES - REPOSITORY CONFIGURATION
# =============================================================================
# @file        buildvars.sh
# @version     1.0.0
# @date        2026-03-31
# @author      goosedev72
# @license     MIT
# @repository  https://github.com/gooseprjkt/DeckyCraftPlusPlus
#
# @description
#   Contains the repository URL for downloading installer modules.
#   This ensures the installer downloads modules from the correct repository,
#   not from the original upstream repository.
#
# @usage
#   Source this file early in your script:
#     source "buildvars.sh"
#
#   Then use the exported variables:
#     echo "$REPO_RAW_URL"
#     echo "$REPO_MODULES_URL"
#
# =============================================================================

# =============================================================================
# REPOSITORY CONFIGURATION
# =============================================================================
# Change these values to point to your fork/repository

readonly BUILD_REPO_OWNER="gooseprjkt"
readonly BUILD_REPO_NAME="DeckyCraftPlusPlus"
readonly BUILD_REPO_BRANCH="main"

# =============================================================================
# DERIVED URLS (DO NOT EDIT BELOW)
# =============================================================================

# Base URL for raw content (used for downloading modules)
readonly BUILD_REPO_RAW_URL="https://raw.githubusercontent.com/${BUILD_REPO_OWNER}/${BUILD_REPO_NAME}/${BUILD_REPO_BRANCH}"

# URL for modules directory
readonly BUILD_REPO_MODULES_URL="${BUILD_REPO_RAW_URL}/modules"

# =============================================================================
# EXPORT FOR INSTALLER
# =============================================================================
# These variables are used by install-minecraft-splitscreen.sh

# Override the default repository URLs if they're set to upstream
export REPO_RAW_URL="$BUILD_REPO_RAW_URL"
export REPO_MODULES_URL="$BUILD_REPO_MODULES_URL"
