#!/bin/bash

user_create(){
    log_info "Configuration des utilisateurs"

    # Création du groupe famille à l'intérieur du chroot
    arch-chroot "$MOUNT_POINT" groupadd famille 2>/dev/null || true

    # Définition des utilisateurs (Père et Fils uniquement)
    USER_PERE="${USER_PERE:-pere}"
    PASS_PERE="${PASS_PERE:-azerty123}"
    USER_FILS="${USER_FILS:-fils}"
    PASS_FILS="${PASS_FILS:-azerty123}"

    local users=("${USER_PERE}:${PASS_PERE}" "${USER_FILS}:${PASS_FILS}")

    for user_info in "${users[@]}"; do
        local user=$(echo "$user_info" | cut -f1 -d:)
        local pass=$(echo "$user_info" | cut -f2 -d:)

        if ! arch-chroot "$MOUNT_POINT" id "$user" &>/dev/null; then
            # Ajout direct au groupe famille dès la création
            arch-chroot "$MOUNT_POINT" useradd -m -s /bin/bash -G wheel,famille "$user" \
                || die "Impossible de créer $user"

            echo "$user:$pass" | arch-chroot "$MOUNT_POINT" chpasswd \
                || die "Impossible de définir mot de passe pour $user"

            log_success "Utilisateur $user créé et ajouté au groupe famille"
        else
            log_warn "Utilisateur $user existe déjà"
            # S'il existe, on s'assure qu'il est dans le groupe
            arch-chroot "$MOUNT_POINT" usermod -aG famille "$user"
        fi
    done
}

shared_folder(){
    log_info "Configuration dossier partagé"

    # On définit le chemin relatif au système installé pour le chown
    # Si ton LVM "shared" est monté sur /mnt/home/shared, on utilise ce chemin
    local INTERNAL_PATH="/home/shared"
    
    # Création du dossier si nécessaire (depuis l'ISO, donc avec $MOUNT_POINT)
    if [ ! -d "$MOUNT_POINT$INTERNAL_PATH" ]; then
        mkdir -p "$MOUNT_POINT$INTERNAL_PATH"
    fi

    # Application des permissions via chroot pour les IDs de groupe
    arch-chroot "$MOUNT_POINT" chown :famille "$INTERNAL_PATH"
    arch-chroot "$MOUNT_POINT" chmod 770 "$INTERNAL_PATH"
    arch-chroot "$MOUNT_POINT" chmod +t "$INTERNAL_PATH"

    log_success "Dossier $INTERNAL_PATH configuré pour le groupe famille"
}

run_users(){
    log_info "===== USERS PHASE ====="
    user_create
    shared_folder
}