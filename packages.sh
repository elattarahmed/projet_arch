#!/bin/bash

optimize_mirrors() {
    log_info "Optimisation des miroirs (France)"
    curl -s "https://archlinux.org/mirrorlist/?country=FR&protocol=https&use_mirror_status=on" | \
    sed 's/^#Server/Server/' > "$MOUNT_POINT/etc/pacman.d/mirrorlist" || die "Echec mirrorlist"
}

sync_database() {
    log_info "Synchronisation des bases"
    arch-chroot "$MOUNT_POINT" pacman -Syy --noconfirm || die "Echec pacman"
}

install_packages() {
    log_info "Installation des outils de base et Dev"
    
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed --overwrite "*" \
        base-devel gcc vim git firefox tmux tree termdown \
        virtualbox virtualbox-guest-iso \
        || die "Echec installation packages"

    log_success "Paquets installés (Système de base + Dev)"
}

run_packages() {
    log_info "===== PHASE LOGICIELS (MODE PURISTE) ====="
    
    sed -i 's/#Color/Color\nILoveCandy/' "$MOUNT_POINT/etc/pacman.conf" 2>/dev/null

    optimize_mirrors
    sync_database
    install_packages

    log_success "Installation terminée ! Système prêt en mode console (TTY)."
}