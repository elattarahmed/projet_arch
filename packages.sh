#!/bin/bash

optimize_mirrors() {
    log_info "Optimisation des miroirs (France)"

    curl -s "https://archlinux.org/mirrorlist/?country=FR&protocol=https&use_mirror_status=on" | \
    sed 's/^#Server/Server/' > "$MOUNT_POINT/etc/pacman.d/mirrorlist" \
    || die "Echec du téléchargement mirrorlist"

    log_success "Mirrorlist optimisée"
}

sync_database() {
    log_info "Synchronisation forcée des bases"

    arch-chroot "$MOUNT_POINT" rm -f /var/lib/pacman/db.lck

    arch-chroot "$MOUNT_POINT" pacman -Syy --noconfirm \
    || die "Echec de la synchronisation pacman"

    log_success "Bases synchronisées"
}

install_packages() {
    log_info "Installation des paquets desktop et Display Manager"

    # Ajout de lightdm, lightdm-gtk-greeter et xterm (secours)
    # Ajout de xf86-video-vmware et xf86-video-fbdev pour la compatibilité VM
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed --overwrite "*" \
        xorg-server xorg-xinit xterm mesa xf86-video-fbdev \
        i3-wm i3status dmenu libxft fontconfig ttf-dejavu \
        lightdm lightdm-gtk-greeter \
        base-devel gcc vim git firefox tmux tree termdown \
        virtualbox virtualbox-guest-iso \
        || die "Echec installation packages"

    # Activation de LightDM
    arch-chroot "$MOUNT_POINT" systemctl enable lightdm || die "Echec activation LightDM"

    log_success "Paquets desktop et LightDM installés"
}

install_st() {
    log_info "Compilation de st"

    arch-chroot "$MOUNT_POINT" bash -c '
        cd /tmp &&
        rm -rf st &&
        git clone https://git.suckless.org/st &&
        cd st &&
        make clean install
    ' || die "Echec compilation st"

    log_success "st installé"
}

configure_users_ui() {
    log_info "Configuration i3 et .xinitrc"

    rm -rf "$MOUNT_POINT/tmp/i3-repo"

    arch-chroot "$MOUNT_POINT" git clone https://github.com/i3/i3 /tmp/i3-repo \
        || log_warn "Clone i3 impossible, config minimale utilisée"

    for user_dir in "$MOUNT_POINT/home/"*; do
        [ -d "$user_dir" ] || continue

        local user
        user=$(basename "$user_dir")

        [ "$user" == "shared" ] && continue

        arch-chroot "$MOUNT_POINT" id "$user" &>/dev/null || continue

        log_info "Configuration de $user"

        local i3_path="$user_dir/.config/i3"
        # On crée le dossier dans l'environnement host via MOUNT_POINT
        mkdir -p "$i3_path"

        if [ -f "$MOUNT_POINT/tmp/i3-repo/etc/config" ]; then
            cp "$MOUNT_POINT/tmp/i3-repo/etc/config" "$i3_path/config"
        else
            echo "exec st" > "$i3_path/config"
        fi

        # Personnalisation de la config
        sed -i 's/i3-sensible-terminal/st/g' "$i3_path/config" 2>/dev/null

        # .xinitrc (toujours utile même avec LightDM)
        echo "exec i3" > "$user_dir/.xinitrc"

        # On s'assure que l'utilisateur est proprio de tout son home
        arch-chroot "$MOUNT_POINT" chown -R "$user:$user" "/home/$user"
    done

    log_success "Configuration UI terminée"
}

run_packages() {
    log_info "===== PACKAGES PHASE ====="

    # Effet visuel Pacman
    sed -i 's/#Color/Color\nILoveCandy/' "$MOUNT_POINT/etc/pacman.conf" 2>/dev/null

    optimize_mirrors
    sync_database
    install_packages
    install_st
    configure_users_ui

    log_success "Installation terminée ! Au prochain redémarrage, LightDM se lancera."
}