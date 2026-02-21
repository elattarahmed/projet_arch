#!/bin/bash

# COLORS

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"




# LOGGING FUNCTIONS

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}



# ERROR HANDLING

die() {
    log_error "$1"
    exit 1
}



# SYSTEM CHECKS

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        die "Ce script doit être exécuté en root."
    fi
}

require_command() {
    if ! command -v "$1" &> /dev/null; then
        die "La commande '$1' est requise mais non installée."
    fi
}
