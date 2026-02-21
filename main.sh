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

main() {
    init

    run_partitioning
    run_users
    run_packages

    log_success "INSTALLATION COMPLETE"
}

main "$@"