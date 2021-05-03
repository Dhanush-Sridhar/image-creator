#!/bin/bash

echo ""
echo "############################################"
echo "# Ubuntu image installer                   #"
echo "# -----------------------------------------#"
echo "# Author: Benjamin Federau                 #"
echo "#         <benjamin.federau@basyskom.com>  #"
echo "############################################"
echo ""

####################### Variables #######################

SCRIPT_PATH="$(dirname $(readlink -f $0))"
IMAGE_TARGET="/dev/sda"
ROOTFS_PATH="/stage"
DATAFS_PATH="${ROOTFS_PATH}/data"
IMAGE_USER="polar"

####################### Functions #######################

function usage() {
    echo "Usage: $(basename $0) <options>"
    echo ""
    echo "Options:"
    echo "  --image-target </dev/sdX> :"
    echo "      Set the target device to install the image."
    echo "      Default: ${IMAGE_TARGET}"
    echo ""
    echo "  -h|--help :"
    echo "      This help dialog."
    echo ""
}

function console_log() {
    echo "$1"
}

function error() {
    echo "$1"
    exit 1
}

function mount_dev_sys_proc() {
    local _ROOTFS_PATH="$1"
    console_log "### Mount dev, proc, sys to rootfs ###"
    [ -e "${_ROOTFS_PATH}" ] || error "Path ${_ROOTFS_PATH} not found!"
    mount -o bind /dev "${_ROOTFS_PATH}/dev"
    mount -o bind /dev/pts "${_ROOTFS_PATH}/dev/pts"
    mount -o bind /sys "${_ROOTFS_PATH}/sys"
    mount -t proc /proc "${_ROOTFS_PATH}/proc"
}

function umount_dev_sys_proc() {
    local _ROOTFS_PATH="$1"
    console_log "### Unmount dev, proc, sys from rootfs ###"
    [ -e "${_ROOTFS_PATH}" ] || error "Path ${_ROOTFS_PATH} not found!"
    umount "${_ROOTFS_PATH}/dev/pts"
    umount "${_ROOTFS_PATH}/dev"
    umount "${_ROOTFS_PATH}/sys"
    umount "${_ROOTFS_PATH}/proc"
}

function create_partitions() {
    local _IMAGE_TARGET="$1"
    local _BOOT_PARTITION="$2"
    local _ROOTFS_PARTITION="$3"
    local _DATAFS_PARTITION="$4"

    console_log "### Create partitions for ${_IMAGE_TARGET} ###"
    sgdisk -Z ${_IMAGE_TARGET}

    # boot partition
    sgdisk -n 1:2048:18431 -t 1:EF02 ${_IMAGE_TARGET}
    # rootfs partition
    sgdisk -n 2:18432:15917054 -t 2:8300 ${_IMAGE_TARGET}
    # Datafs partition
    DEVICE_END_SECTOR=$(sgdisk -E ${_IMAGE_TARGET})
    sgdisk -n 3:15917056:${DEVICE_END_SECTOR} -t 3:8300 ${_IMAGE_TARGET}

    wipefs -a ${_BOOT_PARTITION}
    wipefs -a ${_ROOTFS_PARTITION}
    wipefs -a ${_DATAFS_PARTITION}

    mkfs.ext4 ${_ROOTFS_PARTITION}
    mkfs.vfat ${_DATAFS_PARTITION}
}

####################### Parameters #######################

POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --image-target)
            IMAGE_TARGET="$2"
            shift
            shift
            ;;
        -h|--help)
            usage
            exit 0
            shift
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            echo "Unknown argument: ${POSITIONAL}"
            usage
            exit 1
            shift
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

####################### Checks #######################

PART_TOOL="$(which sgdisk)"

if [ ! -e "${PART_TOOL}" ]
then
    error "sgdisk partition tool not found!"
fi

if [ ! -e "${IMAGE_TARGET}" ]
then
    error "${IMAGE_TARGET} not found!"
fi

mkdir -p "${ROOTFS_PATH}"

####################### Main #######################

BOOT_PARTITION="${IMAGE_TARGET}1"
ROOTFS_PARTITION="${IMAGE_TARGET}2"
DATAFS_PARTITION="${IMAGE_TARGET}3"

create_partitions "${IMAGE_TARGET}" "${BOOT_PARTITION}" "${ROOTFS_PARTITION}" "${DATAFS_PARTITION}"

mount "${ROOTFS_PARTITION}" "${ROOTFS_PATH}" || error "Could not mount ${ROOTFS_PARTITION} to ${ROOTFS_PATH}!"
mkdir -p "${DATAFS_PATH}"
mount "${DATAFS_PARTITION}" "${DATAFS_PATH}" || error "Could not mount ${DATAFS_PARTITION} to ${DATAFS_PATH}!"

console_log "### Installing RootFS to Internal Flash ###"
# determine the line number of this script where the payload begins
PAYLOAD_LINE=`awk '/^__PAYLOAD__/ {print NR + 1; exit 0; }' $0`

# use the tail command and the line number we just determined to skip
# past this leading script code and pipe the payload to tar
tail -n+$PAYLOAD_LINE $0 | tar xjv -C "${ROOTFS_PATH}/"

mount_dev_sys_proc "${ROOTFS_PATH}"

echo "### Configuring RootFS on Internal Flash ###"
console_log "## Install fstab ##"
UUID_ROOTFS=$(/bin/lsblk -o UUID -n ${ROOTFS_PARTITION})
UUID_DATAFS=$(/bin/lsblk -o UUID -n ${DATAFS_PARTITION})
cat <<EOF > ${ROOTFS_PATH}/etc/fstab
UUID=${UUID_ROOTFS}  /          ext4  errors=remount-ro  0  1
UUID=${UUID_DATAFS}  /data      vfat  uid=${IMAGE_USER},gid=${IMAGE_USER}  0  2
EOF

console_log "## Install bootloader ##"
chmod -x "${ROOTFS_PATH}/etc/grub.d/30_os-prober"
chroot "${ROOTFS_PATH}" grub-install --force ${IMAGE_TARGET}
chroot "${ROOTFS_PATH}" update-grub

umount_dev_sys_proc "${ROOTFS_PATH}"

umount "${DATAFS_PATH}"
umount "${ROOTFS_PATH}"

exit 0

# the 'exit 0' immediately above prevents this line from being executed
__PAYLOAD__
