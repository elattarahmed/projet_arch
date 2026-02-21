#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")

source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/partitioning.sh"
source "$SCRIPT_DIR/users.sh"
source "$SCRIPT_DIR/packages.sh"

init() {
    log_info "Initialisation..."
    require_root
    log_success "Environment is setup. Ready to start"
}


finalize() {
    log_info "Ending configuration..."

    sync

    log_info "Unmounting partitions..."
    umount -R "$MOUNT_POINT"

    log_info "Closing LUKS Volume..."
    cryptsetup close "$CRYPT_NAME" 2>/dev/null || true

    log_success "Installation Ended :))) Restarting..."

    reboot
}

main() {
    init

    run_partitioning
    run_users
    run_packages

    finalize
}

main "$@"