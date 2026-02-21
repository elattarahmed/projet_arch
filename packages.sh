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
        i3-wm i3status dmenu libxft fontconfig ttf-dejavu ttf-font-awesome \
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
    log_info "Configuration i3 (Community Edition) et .xinitrc"

    # 1. On prépare une config source élégante
    # On utilise ici un lien vers une config i3 standard optimisée
    local temp_config="/tmp/i3_community_config"
    rm -rf "$MOUNT_POINT$temp_config"
    
    # Option A: Cloner un repo de dotfiles connu (ex: une config i3 de base propre)
    # Pour l'exemple, on télécharge une config équilibrée
    curl -L -o "$MOUNT_POINT$temp_config" "https://raw.githubusercontent.com/i3/i3/master/etc/config" || \
        log_warn "Impossible de récupérer la config distante, utilisation du défaut"

    for user_dir in "$MOUNT_POINT/home/"*; do
        [ -d "$user_dir" ] || continue
        local user=$(basename "$user_dir")
        [ "$user" == "shared" ] && continue
        arch-chroot "$MOUNT_POINT" id "$user" &>/dev/null || continue

        log_info "Configuration personnalisée pour $user"

        local i3_path="$user_dir/.config/i3"
        mkdir -p "$i3_path"

        # Copie de la config
        if [ -f "$MOUNT_POINT$temp_config" ]; then
            cp "$MOUNT_POINT$temp_config" "$i3_path/config"
        else
            # Fallback minimaliste
            echo "exec i3" > "$i3_path/config"
        fi

        # --- PERSONNALISATION DE LA CONFIG ---
        # 1. Utiliser la touche Windows (Mod4) au lieu de Alt (Mod1)
        sed -i 's/set $mod Mod1/set $mod Mod4/g' "$i3_path/config"
        
        # 2. Forcer ton terminal 'st' fraîchement compilé
        sed -i 's/i3-sensible-terminal/st/g' "$i3_path/config"
        sed -i 's/bindsym $mod+Return exec terminal/bindsym $mod+Return exec st/g' "$i3_path/config"

        # 3. Ajouter un fond d'écran (si un outil comme 'feh' est installé)
        # echo "exec_always --no-startup-id feh --bg-fill /usr/share/backgrounds/arch-wallpaper.jpg" >> "$i3_path/config"

        # .xinitrc
        echo "exec i3" > "$user_dir/.xinitrc"

        # Permissions
        arch-chroot "$MOUNT_POINT" chown -R "$user:$user" "/home/$user"
    done
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