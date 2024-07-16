#!/bin/bash

# https://docs.lavasoftware.org/lava/bootimages.html


readonly REPO_ROOT=$(git rev-parse --show-toplevel) 
readonly TMP_DIR="${REPO_ROOT}/tmp"

IMG_FILE="$TMP_DIR/usb-live.img"
ROOTFS_DIR="$TMP_DIR/live-rootfs"
IMG_SIZE="10G"
BOOT_PART_SIZE="200M"
LOOP_DEV=""


function root_check(){
    if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
    fi
}

root_check

# .img Datei erstellen
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1024 seek=${IMG_SIZE}
#qemu-image create test.img
 sudo dd if=/dev/zero of=test.img bs=1M count=1024
# Loop Device erstellen
LOOP_DEV=$(losetup -f --show ${IMG_FILE})

# Partitionstabelle erstellen
parted ${LOOP_DEV} mklabel msdos
parted -a optimal ${LOOP_DEV} mkpart primary fat32 1MiB ${BOOT_PART_SIZE}
parted -a optimal ${LOOP_DEV} mkpart primary ext4 ${BOOT_PART_SIZE} 100%

# Partitionen formatieren
mkfs.vfat ${LOOP_DEV}p1
mkfs.ext4 ${LOOP_DEV}p2

# Mount Points erstellen
BOOT_MOUNT=$(mktemp -d)
ROOTFS_MOUNT=$(mktemp -d)

# Partitionen mounten
mount ${LOOP_DEV}p1 ${BOOT_MOUNT}
mount ${LOOP_DEV}p2 ${ROOTFS_MOUNT}

# RootFS auf die rootfs-Partition kopieren
cp -r ${ROOTFS_DIR}/* ${ROOTFS_MOUNT}

# Bootloader installieren (Annahme: GRUB wird verwendet)
grub-install --root-directory=${ROOTFS_MOUNT} --boot-directory=${BOOT_MOUNT} --target=i386-pc ${LOOP_DEV}

# Partitionen unmounten
umount ${BOOT_MOUNT}
umount ${ROOTFS_MOUNT}

# Temporäre Verzeichnisse entfernen
rmdir ${BOOT_MOUNT}
rmdir ${ROOTFS_MOUNT}

# Loop Device loslassen
losetup -d ${LOOP_DEV}

echo "Image-Datei ${IMG_FILE} erfolgreich erstellt."
