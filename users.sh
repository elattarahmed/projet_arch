#!/bin/bash

user_create(){
    log_info "Configuration des utilisateurs"

    arch-chroot "$MOUNT_POINT" groupadd famille 2>/dev/null || true

    USER_PERE="${USER_PERE:-pere}"
    PASS_PERE="${PASS_PERE:-azerty123}"
    USER_FILS="${USER_FILS:-fils}"
    PASS_FILS="${PASS_FILS:-azerty123}"

    local users=("${USER_PERE}:${PASS_PERE}" "${USER_FILS}:${PASS_FILS}")

    for user_info in "${users[@]}"; do
        local user=$(echo "$user_info" | cut -f1 -d:)
        local pass=$(echo "$user_info" | cut -f2 -d:)

        if ! arch-chroot "$MOUNT_POINT" id "$user" &>/dev/null; then
            arch-chroot "$MOUNT_POINT" useradd -m -s /bin/bash -G wheel "$user" \
                || die "Impossible de créer $user"

            echo "$user:$pass" | arch-chroot "$MOUNT_POINT" chpasswd \
                || die "Impossible de définir mot de passe"

            log_success "Utilisateur $user créé"
        else
            log_warn "Utilisateur $user existe déjà"
        fi
    done

    arch-chroot "$MOUNT_POINT" usermod -aG famille "$USER_PERE"
    arch-chroot "$MOUNT_POINT" usermod -aG famille "$USER_FILS"
}

shared_folder(){
    log_info "Configuration dossier partagé"

    if [ -d "$MOUNT_POINT/var/shared" ]; then
        TARGET_DIR="$MOUNT_POINT/var/shared"
    else
        TARGET_DIR="$MOUNT_POINT/home/shared"
        mkdir -p "$TARGET_DIR"
    fi

    chown :famille "$TARGET_DIR"
    chmod 770 "$TARGET_DIR"
    chmod +t "$TARGET_DIR"

    log_success "Permissions appliquées"
}

run_users(){
    log_info "===== USERS PHASE ====="
    user_create
    shared_folder
}
