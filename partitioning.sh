#!/bin/bash


# PARTITIONING & STORAGE SETUP

DISK=""
EFI_PART=""
LUKS_PART=""

CRYPT_NAME="cryptlvm"
VG_NAME="vg_arch"
MOUNT_POINT="/mnt"

get_infos(){
    log_info "Checking requirements.."

    DISK="/dev/$(lsblk -ndo NAME,TYPE | grep "disk" | cut -d " " -f 1)"
    EFI_PART="${DISK}1"
    LUKS_PART="${DISK}2"
}

partition_disk() {
    log_info "GPT Partitioning of the disk"
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB set 1 esp on
    parted -s "$DISK" mkpart PRIMARY 513MiB 100%
    mkfs.fat -F32 "$EFI_PART"

    log_success "UEFI partitioning done"
}

luks_setup(){
    log_info "LUKS setup"
    echo -n "azerty123" | cryptsetup luksFormat --type luks2 --batch-mode "$LUKS_PART" -
    echo -n "azerty123" | cryptsetup open "$LUKS_PART" "$CRYPT_NAME" -

    log_success "LUKS container opened"
}

lvm_setup(){
    log_info "LVM setup"

    pvcreate "/dev/mapper/${CRYPT_NAME}"
    vgcreate "$VG_NAME" "/dev/mapper/${CRYPT_NAME}"

    lvcreate -L 20G "$VG_NAME" -n root
    lvcreate -L  4G "$VG_NAME" -n swap
    lvcreate -L 25G "$VG_NAME" -n virtualbox
    lvcreate -L  5G "$VG_NAME" -n shared
    lvcreate -L 10G "$VG_NAME" -n secret
    lvcreate -l 100%FREE "$VG_NAME" -n home

    log_success "LVM created"
}

format_and_mount(){
    log_info "Formatting and mounting"

    [[ -b "/dev/${VG_NAME}/root" ]] || die "LV root not found"

    mkfs.ext4 "/dev/${VG_NAME}/root"
    mkfs.ext4 "/dev/${VG_NAME}/home"
    mkfs.ext4 "/dev/${VG_NAME}/virtualbox"
    mkfs.ext4 "/dev/${VG_NAME}/shared"

    mkswap "/dev/${VG_NAME}/swap"
    swapon "/dev/${VG_NAME}/swap"

    mount "/dev/${VG_NAME}/root" "$MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"/{boot/efi,home,var/lib/virtualbox,var/shared}
    mount "$EFI_PART" "$MOUNT_POINT/boot/efi"
    mount "/dev/${VG_NAME}/home" "$MOUNT_POINT/home"
    mount "/dev/${VG_NAME}/virtualbox" "$MOUNT_POINT/var/lib/virtualbox"
    mount "/dev/${VG_NAME}/shared" "$MOUNT_POINT/var/shared"

    log_success "Mount completed"
}

install_base_system() {
    log_info "Installation of base system (pacstrap)"

    pacstrap "$MOUNT_POINT" base linux linux-firmware lvm2 grub efibootmgr || die "Echec pacstrap"

    log_success "Base system installed"
}

generate_fstab() {
    log_info "fstab generation"

    genfstab -U "$MOUNT_POINT" >> "$MOUNT_POINT/etc/fstab"

    log_success "fstab generated"
}

configure_initramfs() {
    log_info "Configuration of mkinitcpio (encrypt + lvm2)"

    arch-chroot "$MOUNT_POINT" sed -i \
        's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' \
        /etc/mkinitcpio.conf

    arch-chroot "$MOUNT_POINT" mkinitcpio -P || die "Echec mkinitcpio"

    log_success "Initramfs configured"
}


configure_grub_luks() {
    log_info "Grub Configuration for LUKS"

    local luks_uuid
    luks_uuid=$(blkid -s UUID -o value "$LUKS_PART") || die "Can't get UUID LUKS"

    arch-chroot "$MOUNT_POINT" sed -i 's/^#\?GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub

    arch-chroot "$MOUNT_POINT" sed -i \
      "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${luks_uuid}:${CRYPT_NAME} root=/dev/${VG_NAME}/root\"|" \
      /etc/default/grub

    log_success "GRUB LUKS configured"
}

install_grub() {
    log_info "Installation of GRUB (EFI)"

    mkdir -p "$MOUNT_POINT/boot/efi"
    
    if ! mountpoint -q "$MOUNT_POINT/boot/efi"; then
        log_info "Mounting /dev/sda1 to /boot/efi..."
        mount /dev/sda1 "$MOUNT_POINT/boot/efi" || die "Impossible de monter la partition EFI"
    fi

    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed grub efibootmgr || die "Fail to install grub packages"

    arch-chroot "$MOUNT_POINT" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=GRUB \
        --recheck || die "Fail grub-install"

    local uuid_luks=$(blkid -s UUID -o value /dev/sda2)
    
    log_info "Configuring GRUB for LUKS (UUID: $uuid_luks)"
    
    arch-chroot "$MOUNT_POINT" sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=$uuid_luks:cryptlvm root=/dev/mapper/vg_arch-root\"|" /etc/default/grub
    arch-chroot "$MOUNT_POINT" sed -i 's/^GRUB_PRELOAD_MODULES="/GRUB_PRELOAD_MODULES="lvm /' /etc/default/grub

    arch-chroot "$MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg \
        || die "Fail grub-mkconfig"

    log_success "GRUB installed and configured for LUKS/LVM"
}

run_partitioning(){
    log_info "===== PARTITIONING PHASE ====="

    get_infos
    partition_disk
    luks_setup
    lvm_setup
    format_and_mount

    install_base_system
    generate_fstab
    configure_initramfs
    configure_grub_luks
    install_grub
}
