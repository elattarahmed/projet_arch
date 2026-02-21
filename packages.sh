#!/bin/bash

# --- Configuration Clavier & Miroirs ---

optimize_mirrors() {
    log_info "Optimisation des miroirs (France)"
    curl -s "https://archlinux.org/mirrorlist/?country=FR&protocol=https&use_mirror_status=on" | \
    sed 's/^#Server/Server/' > "$MOUNT_POINT/etc/pacman.d/mirrorlist" || die "Echec mirrorlist"
}

configure_keyboard_fr() {
    log_info "Configuration Clavier AZERTY (Console + X11)"
    # Console
    echo "KEYMAP=fr-latin9" > "$MOUNT_POINT/etc/vconsole.conf"
    # X11 (Interface graphique)
    mkdir -p "$MOUNT_POINT/etc/X11/xorg.conf.d/"
    cat << EOF > "$MOUNT_POINT/etc/X11/xorg.conf.d/00-keyboard.conf"
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
        Option "XkbVariant" "oss"
EndSection
EOF
}

# --- Installation & Compilation ---

install_packages() {
    log_info "Installation des paquets Desktop et Polices"
    
    # Correction : On retire xf86-video-vmware (souvent inutile/absent) 
    # On ajoute mesa (pilote universel) et ttf-font-awesome (icônes i3)
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed --overwrite "*" \
        xorg-server xorg-xinit xterm mesa xf86-video-fbdev \
        i3-wm i3status dmenu libxft fontconfig ttf-dejavu ttf-font-awesome \
        lightdm lightdm-gtk-greeter feh picom \
        base-devel gcc vim git firefox tmux tree termdown \
        virtualbox virtualbox-guest-iso || die "Echec installation packages"

    arch-chroot "$MOUNT_POINT" systemctl enable lightdm || die "Echec activation LightDM"
}

install_st() {
    log_info "Compilation de st (Suckless Terminal)"
    arch-chroot "$MOUNT_POINT" bash -c '
        cd /tmp && rm -rf st
        git clone https://git.suckless.org/st && cd st
        make clean install
    ' || log_warn "Echec compilation st, xterm sera utilisé par défaut"
}

# --- Interface Utilisateur ---

configure_users_ui() {
    log_info "Installation du 'Rice' i3 communautaire"

    # Récupération d'une config i3 propre et moderne
    local temp_config="/tmp/i3_community_config"
    curl -sL "https://raw.githubusercontent.com/i3/i3/master/etc/config" > "$MOUNT_POINT$temp_config"

    for user_dir in "$MOUNT_POINT/home/"*; do
        [ -d "$user_dir" ] || continue
        local user=$(basename "$user_dir")
        [ "$user" == "shared" ] && continue
        arch-chroot "$MOUNT_POINT" id "$user" &>/dev/null || continue

        log_info "Configuring UI for $user"
        local i3_path="$user_dir/.config/i3"
        mkdir -p "$i3_path"
        
        cp "$MOUNT_POINT$temp_config" "$i3_path/config"

        # Personnalisation : Touche Windows (Mod4) + Terminal st
        sed -i "s/set \$mod Mod1/set \$mod Mod4/g" "$i3_path/config"
        sed -i "s/i3-sensible-terminal/st/g" "$i3_path/config"
        
        # Ajout du clavier FR directement dans la config i3 (sécurité)
        echo "exec --no-startup-id setxkbmap fr" >> "$i3_path/config"

        echo "exec i3" > "$user_dir/.xinitrc"
        arch-chroot "$MOUNT_POINT" chown -R "$user:$user" "/home/$user"
    done
}

run_packages() {
    log_info "===== PHASE LOGICIELS & INTERFACE ====="
    sed -i 's/#Color/Color\nILoveCandy/' "$MOUNT_POINT/etc/pacman.conf" 2>/dev/null

    optimize_mirrors
    configure_keyboard_fr
    
    # On synchronise les bases avant d'installer
    arch-chroot "$MOUNT_POINT" pacman -Syy --noconfirm

    install_packages
    install_st
    configure_users_ui

    log_success "Installation UI terminée ! Redémarrez et profitez."
}