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
    log_info "Installation des paquets Desktop, Fonts et Drivers"

    # Ajout de ttf-font-awesome pour les icônes i3
    # Ajout de feh pour le fond d'écran et picom pour la transparence
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed --overwrite "*" \
        xorg-server xorg-xinit xterm mesa xf86-video-fbdev \
        i3-wm i3status dmenu libxft fontconfig ttf-dejavu ttf-font-awesome \
        lightdm lightdm-gtk-greeter feh picom \
        base-devel gcc vim git firefox tmux tree termdown \
        virtualbox virtualbox-guest-iso \
        || die "Echec installation packages"

    arch-chroot "$MOUNT_POINT" systemctl enable lightdm || die "Echec activation LightDM"
}

configure_keyboard_fr() {
    log_info "Fixing keyboard to FR (AZERTY)"
    mkdir -p "$MOUNT_POINT/etc/X11/xorg.conf.d/"
    cat << EOF > "$MOUNT_POINT/etc/X11/xorg.conf.d/00-keyboard.conf"
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
        Option "XkbVariant" "oss"
EndSection
EOF
    # Pour la console TTY
    echo "KEYMAP=fr-latin9" > "$MOUNT_POINT/etc/vconsole.conf"
}

configure_users_ui() {
    log_info "Configuration i3 (Community Edition)"

    local temp_config="/tmp/i3_community_config"
    # On télécharge une base de config i3 propre et moderne
    curl -sL "https://raw.githubusercontent.com/i3/i3/master/etc/config" > "$MOUNT_POINT$temp_config"

    for user_dir in "$MOUNT_POINT/home/"*; do
        [ -d "$user_dir" ] || continue
        local user=$(basename "$user_dir")
        [ "$user" == "shared" ] && continue
        arch-chroot "$MOUNT_POINT" id "$user" &>/dev/null || continue

        local i3_path="$user_dir/.config/i3"
        mkdir -p "$i3_path"

        # Copie et Personnalisation
        cp "$MOUNT_POINT$temp_config" "$i3_path/config"
        
        # Configuration AZERTY dans i3 (au cas où) et changement du MOD4 (Windows)
        sed -i 's/set \$mod Mod1/set \$mod Mod4/g' "$i3_path/config"
        sed -i 's/i3-sensible-terminal/st/g' "$i3_path/config"
        
        # Ajout d'une petite touche "communauté" : lanceur d menu plus joli
        sed -i 's/bindsym \$mod+d exec dmenu_run/bindsym \$mod+d exec dmenu_run -nb "#222222" -nf "#b8bb26" -sb "#b8bb26" -sf "#282828" -fn "monospace-10"/g' "$i3_path/config"

        echo "exec i3" > "$user_dir/.xinitrc"
        arch-chroot "$MOUNT_POINT" chown -R "$user:$user" "/home/$user"
    done
}

run_packages() {
    log_info "===== PHASE FINALE : LOGICIELS & UI ====="
    sed -i 's/#Color/Color\nILoveCandy/' "$MOUNT_POINT/etc/pacman.conf" 2>/dev/null

    optimize_mirrors
    sync_database
    install_packages
    install_st
    configure_keyboard_fr  # <--- On ajoute ça ici
    configure_users_ui

    log_success "Tout est prêt ! Clavier FR, i3 configuré et LightDM activé."
}