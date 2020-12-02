#!/bin/bash

[ ! -z "${DEBUG}" ] && set -x

echo ""
echo "############################################"
echo "# Ubuntu image creator                     #"
echo "# -----------------------------------------#"
echo "# Author: Benjamin Federau                 #"
echo "#         <benjamin.federau@basyskom.com>  #"
echo "############################################"
echo ""

####################### Variables #######################

SCRIPT_PATH="$(dirname $(readlink -f $0))"
# debootstrap defaults
APT_CMD="apt"
ARCH="amd64"
DISTRO="focal"
DEBOOTSTRAP_OPTIONS=""

# default (file) paths
INSTALLER_SCRIPT="${SCRIPT_PATH}/image-installer.sh"
ROOTFS_IMAGE_FILE="${SCRIPT_PATH}/rootfs.img"
ROOTFS_TARBALL="${SCRIPT_PATH}/rootfs.tar.bz2"
ROOTFS_PATH="${SCRIPT_PATH}/rootfs"
CONF_PATH="${SCRIPT_PATH}/confs"
PKG_DEB_PATH="${SCRIPT_PATH}/packages/deb"
PKG_TARBALLS_PATH="${SCRIPT_PATH}/packages/tarballs"
PKG_BINARIES_PATH="${SCRIPT_PATH}/packages/binaries"

# default image configs
IMAGE_USER="polar"
IMAGE_PASSWORD="evis32"
IMAGE_HOSTNAME="ubuntu"
QT_VERSION="5.15.0"

# default options
CLEAN="NO"
ENTER_CHROOT="NO"
IMAGE_TYPE="production"

# package lists
QT_SHORT_VERSION="$(echo ${QT_VERSION%.*} | tr -d '.')"
BASE_IMAGE_PACKAGES="sudo apt-utils"
RUNTIME_IMAGE_PACKAGES="less wget vim ssh linux-image-generic nodm xinit openbox xterm network-manager x11-xserver-utils libmbedtls12 apt-offline"
DEV_IMAGE_PACKAGES="git xvfb flex bison libxcursor-dev libxcomposite-dev build-essential libssl-dev libxcb1-dev libgl1-mesa-dev libmbedtls-dev"
DEB_DEV_PACKAGES="dpkg-dev dh-make devscripts git-buildpackage quilt"
INSTALLATION_IMAGE_PACKAGES="gdisk"
QT_IMAGE_PACKAGES="qt${QT_SHORT_VERSION}declarative qt${QT_SHORT_VERSION}quickcontrols2 qt${QT_SHORT_VERSION}graphicaleffects qt${QT_SHORT_VERSION}svg qt${QT_SHORT_VERSION}serialport"

# option lists
ARCH_LIST="i386 amd64 armel armhf"
IMAGE_TYPE_LIST="production development installation"

####################### Functions #######################

function usage() {
    echo "Usage: $(basename $0) <options>"
    echo ""
    echo "Options:"
    echo "  --arch <architecture-string> :"
    echo "      Sets the architecture for the rootfs. Available architectures: ${ARCH_LIST// /, }"
    echo "      Default: ${ARCH}"
    echo ""
    echo "  --distro <distribution-string> :"
    echo "      Sets the Debian/Ubuntu distribution for the rootfs. E.g. xenial, bionic, focal, ..."
    echo "      Default: ${DISTRO}"
    echo ""
    echo "  --image-target <string> :"
    echo "      Specifies the image target. The option string can be either \"loop\", /dev/sdX, \"tarball\" or \"installer\"."
    echo ""
    echo "  --image-type <string> :"
    echo "      Specifies the image type. Available image types: ${IMAGE_TYPE_LIST// /, }"
    echo "      Default: ${IMAGE_TYPE}"
    echo ""
    echo "  --clean :"
    echo "      Cleans the image-creator environment (rootfs, image files, tarballs, ...)."
    echo ""
    echo "  --enter-chroot :"
    echo "      Starts a chroot environment after image creation."
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
        --arch)
            ARCH="$2"
            shift
            shift
            ;;
        --distro)
            DISTRO="$2"
            shift
            shift
            ;;
        --clean)
            CLEAN="YES"
            rm -rf "${ROOTFS_PATH}"
            shift
            ;;
        --enter-chroot)
            ENTER_CHROOT="YES"
            shift
            ;;
        --image-target)
            IMAGE_TARGET="$2"
            shift
            shift
            ;;
        --image-type)
            IMAGE_TYPE="$2"
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

[ "$(whoami)" != "root" ] && console_log "You must be root or use the sudo command!" && exit 1

DEBOOTSTRAP_CMD="$(which debootstrap)"
QEMU_DEBOOTSTRAP_CMD="$(which qemu-debootstrap)"

if [ -z "${DEBOOTSTRAP_CMD}" -o -z "${QEMU_DEBOOTSTRAP_CMD}" ]
then
    console_log "### Installing needed host packages ###"
    ${APT_CMD} update
    ${APT_CMD} -y install debootstrap qemu-user-static || error "Could not install host packages!"
    DEBOOTSTRAP_CMD="$(which debootstrap)"
    QEMU_DEBOOTSTRAP_CMD="$(which qemu-debootstrap)"
fi

DISTRO_LIST=$(find /usr/share/debootstrap/scripts/ -type l -print | xargs -I {} basename {})

DISTRO_OK="false"
for DISTRO_NAME in ${DISTRO_LIST}
do
  if [ "${DISTRO}" = "${DISTRO_NAME}" ]
  then
    DISTRO_OK="true"
    break
  fi
done
  
if [ "${DISTRO_OK}" = "false" ]
then
    console_log "Unknown distribution name ${DISTRO}!"
    console_log "Available distributions: "
    console_log "${DISTRO_LIST}"
    console_log ""
    exit 1 
fi

ARCH_OK="false"
for ARCH_NAME in ${ARCH_LIST}
do
  if [ "${ARCH}" = "${ARCH_NAME}" ]
  then
    ARCH_OK="true"
    break
  fi
done
  
if [ "${ARCH_OK}" = "false" ]
then
    console_log "Unknown architecture ${ARCH}!"
    console_log "Available architectures: ${ARCH_LIST// / | }"
    console_log ""
    exit 1 
fi

if [ ! -z "${IMAGE_TARGET}" ]
then
    case ${IMAGE_TARGET} in
        loop)
            IMAGE_TARGET_TYPE="loop"
            [ "${CLEAN}" = "YES" ] && rm -f "${SCRIPT_PATH}/*.img"
            ;;
        *dev*)
            IMAGE_TARGET_TYPE="dev"
            [ -e "${IMAGE_TARGET}" ] || error "Device ${IMAGE_TARGET} not found!"
            PART_TOOL="$(which sgdisk)"
            [ -e "${PART_TOOL}" ] || error "No partition tool found!"
            ;;
        tarball)
            IMAGE_TARGET_TYPE="tarball"
            [ "${CLEAN}" = "YES" ] && rm -f "${SCRIPT_PATH}/*.tar.*"
            ;;
        installer)
            IMAGE_TARGET_TYPE="installer"
            [ "${CLEAN}" = "YES" ] && rm -f "${SCRIPT_PATH}/*.tar.*"
            ;;
        *)
            console_log "Unknown image target ${IMAGE_TARGET}!"
            console_log "Available image types: loop | /dev/sdX | tarball | installer"
            console_log ""
            exit 1
            ;;
    esac
fi

if [ ! -z "${IMAGE_TYPE}" ]
then
    case ${IMAGE_TYPE} in
        production)
            IMAGE_PACKAGE_LIST="${RUNTIME_IMAGE_PACKAGES} ${QT_IMAGE_PACKAGES}"
            ;;
        development)
            IMAGE_PACKAGE_LIST="${QT_IMAGE_PACKAGES} ${DEV_IMAGE_PACKAGES} ${DEB_DEV_PACKAGES}"
            ;;
        installation)
            IMAGE_PACKAGE_LIST="${INSTALLATION_IMAGE_PACKAGES} ${RUNTIME_IMAGE_PACKAGES}"
            ;;
        *)
            console_log "Unknown image type ${IMAGE_TYPE}!"
            console_log "Available image types: ${IMAGE_TYPE_LIST// / | }"
            console_log ""
            exit 1
            ;;
    esac

    ROOTFS_IMAGE_FILE="${ROOTFS_IMAGE_FILE//rootfs/rootfs-${IMAGE_TYPE}}"
    ROOTFS_TARBALL="${ROOTFS_TARBALL//rootfs/rootfs-${IMAGE_TYPE}}"
fi

mkdir -p "${ROOTFS_PATH}" "${PKG_DEB_PATH}" "${PKG_TARBALLS_PATH}" "${PKG_BINARIES_PATH}"

####################### Main #######################

export DEBIAN_FRONTEND=noninteractive

if [ "${IMAGE_TARGET_TYPE}" = "loop" ]
then
    if [ ! -e "${ROOTFS_IMAGE_FILE}" ]
    then
        dd if=/dev/zero of="${ROOTFS_IMAGE_FILE}" bs=100M count=160
    fi

    losetup -D
    losetup -fP "${ROOTFS_IMAGE_FILE}"
    losetup -a
    IMAGE_TARGET="$(losetup -ln -O NAME)"
    
    BOOT_PARTITION="${IMAGE_TARGET}p1"
    ROOTFS_PARTITION="${IMAGE_TARGET}p2"
    DATAFS_PARTITION="${IMAGE_TARGET}p3"
    
    create_partitions "${IMAGE_TARGET}" "${BOOT_PARTITION}" "${ROOTFS_PARTITION}" "${DATAFS_PARTITION}"
    
    mount "${ROOTFS_PARTITION}" "${ROOTFS_PATH}" || error "Could not mount ${ROOTFS_PARTITION} to ${ROOTFS_PATH}!"
fi

if [ "${IMAGE_TARGET_TYPE}" = "dev" ]
then
    BOOT_PARTITION="${IMAGE_TARGET}1"
    ROOTFS_PARTITION="${IMAGE_TARGET}2"
    DATAFS_PARTITION="${IMAGE_TARGET}3"

    create_partitions "${IMAGE_TARGET}" "${BOOT_PARTITION}" "${ROOTFS_PARTITION}" "${DATAFS_PARTITION}"

    mount "${ROOTFS_PARTITION}" "${ROOTFS_PATH}" || error "Could not mount ${ROOTFS_PARTITION} to ${ROOTFS_PATH}!"
fi

# create an initial rootfs using debootstrap
IMAGE_HOSTNAME="${IMAGE_HOSTNAME}-${ARCH}"
if [ ! -e "${ROOTFS_PATH}/etc/os-release" ]
then
    console_log "### Create rootfs ### "
    if [ "${ARCH}" != "i386" -o "${ARCH}" != "amd64" ]
    then
        HOSTNAME=${IMAGE_HOSTNAME} ${QEMU_DEBOOTSTRAP_CMD} --no-check-gpg ${DEBOOTSTRAP_OPTIONS} --arch=${ARCH} ${DISTRO} ${ROOTFS_PATH} --include "${BASE_IMAGE_PACKAGES}"
    else
        HOSTNAME=${IMAGE_HOSTNAME} ${DEBOOTSTRAP_CMD} --no-check-gpg ${DEBOOTSTRAP_OPTIONS} --arch=${ARCH} ${DISTRO} ${ROOTFS_PATH} --include "${BASE_IMAGE_PACKAGES}"
    fi
fi
DISTRO_ID="$(source rootfs/etc/os-release && echo $ID)"

mount_dev_sys_proc "${ROOTFS_PATH}"

# create the sources.list files for apt:
console_log "### Create sources.list ###"

if [ "${DISTRO_ID}" = "ubuntu" ]
then
    TMP_REPOS="${DISTRO} ${DISTRO}-updates ${DISTRO}-security ${DISTRO}-backports"
    if [ "${ARCH}" = "armel" -a "${ARCH}" = "armhf" ]
    then
        REPO_URL="http://ports.ubuntu.com"
    else
        REPO_URL="http://de.archive.ubuntu.com/ubuntu"
    fi
    
    REPO_COMPONENTS="main universe multiverse"

    echo "" > "${ROOTFS_PATH}/etc/apt/sources.list"

    for REPO in ${TMP_REPOS}
    do
        echo "deb ${REPO_URL} ${REPO} ${REPO_COMPONENTS}" >> "${ROOTFS_PATH}/etc/apt/sources.list"
        #echo "deb-src ${REPO_URL} ${REPO} ${REPO_COMPONENTS}" >> "${ROOTFS_PATH}/etc/apt/sources.list"
    done
    
    if [ "${IMAGE_TYPE}" != "installation" ]
    then
        chroot ${ROOTFS_PATH} ${APT_CMD} update
        chroot ${ROOTFS_PATH} ${APT_CMD} -y install software-properties-common
        chroot ${ROOTFS_PATH} add-apt-repository -y ppa:beineri/opt-qt-${QT_VERSION}-${DISTRO}
    fi
fi

console_log "### Configure locales ###"
chroot ${ROOTFS_PATH} locale-gen de_DE.UTF-8

console_log "### Configure dash/bash ###"
chroot ${ROOTFS_PATH} /bin/bash -c 'echo "dash dash/sh boolean false" | debconf-set-selections'
chroot ${ROOTFS_PATH} /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash'

# update rootfs
console_log "### Update rootfs ###"
cp /etc/resolv.conf ${ROOTFS_PATH}/etc
chroot ${ROOTFS_PATH} ${APT_CMD} update
POLICY_RC_D_FILE="${ROOTFS_PATH}/usr/sbin/policy-rc.d"
install -m 0644 ${CONF_PATH}/policy-rc.d ${POLICY_RC_D_FILE}
chroot ${ROOTFS_PATH} ${APT_CMD} -y dist-upgrade

# install some fundamental packages
console_log "### Install packages in rootfs ###"
chroot ${ROOTFS_PATH} ${APT_CMD} update
chroot ${ROOTFS_PATH} ${APT_CMD} -y install ${IMAGE_PACKAGE_LIST}
chroot ${ROOTFS_PATH} ${APT_CMD} -y clean

console_log "### User management ###"
echo -e "${IMAGE_PASSWORD}\n${IMAGE_PASSWORD}\n" | chroot ${ROOTFS_PATH} passwd root

chroot ${ROOTFS_PATH} adduser --gecos "" --disabled-password ${IMAGE_USER}
chroot ${ROOTFS_PATH} usermod -a -G sudo,video,audio,plugdev ${IMAGE_USER}

echo -e "${IMAGE_PASSWORD}\n${IMAGE_PASSWORD}\n" | chroot ${ROOTFS_PATH} passwd ${IMAGE_USER}

if [ "${ENTER_CHROOT}" = "YES" ]
then
    chroot "${ROOTFS_PATH}"
fi

console_log "### Configure rootfs ###"
## install (pre)config files to rootfs
find ${CONF_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ${ROOTFS_PATH} \;

echo "${IMAGE_HOSTNAME}" > ${ROOTFS_PATH}/etc/hostname
sed -i "s/replace-me/${IMAGE_HOSTNAME}/g" ${ROOTFS_PATH}/etc/hosts

sed -i "s/NODM_ENABLED=false/NODM_ENABLED=true/g" ${ROOTFS_PATH}/etc/default/nodm
sed -i "s/NODM_USER=root/NODM_USER=${IMAGE_USER}/g" ${ROOTFS_PATH}/etc/default/nodm
sed -i "s/NODM_X_OPTIONS='-nolisten tcp'/NODM_X_OPTIONS='-nolisten tcp -nocursor'/g" ${ROOTFS_PATH}/etc/default/nodm

mkdir -p ${ROOTFS_PATH}/home/${IMAGE_USER}/.config/openbox
install -m 0644 ${CONF_PATH}/autostart ${ROOTFS_PATH}/home/${IMAGE_USER}/.config/openbox


if [ "${IMAGE_TARGET_TYPE}" = "dev" -o "${IMAGE_TARGET_TYPE}" = "loop" ]
then
    console_log "### Install fstab ###"
    UUID_ROOTFS=$(/bin/lsblk -o UUID -n ${ROOTFS_PARTITION})
cat <<EOF > ${ROOTFS_PATH}/etc/fstab
UUID=${UUID_ROOTFS}  /          ext4  errors=remount-ro  0  1
EOF

    console_log "### Install bootloader ###"
    chmod -x "${ROOTFS_PATH}/etc/grub.d/30_os-prober"
    chroot "${ROOTFS_PATH}" grub-install --force ${IMAGE_TARGET}
    chroot "${ROOTFS_PATH}" update-grub
fi

rm -f ${POLICY_RC_D_FILE}
sync

umount_dev_sys_proc "${ROOTFS_PATH}"

if [ "${IMAGE_TARGET_TYPE}" = "tarball" -o "${IMAGE_TARGET_TYPE}" = "installer" ]
then
    console_log "### Create rootfs tarball ###"
    pushd "${ROOTFS_PATH}" &> /dev/null
    tar -cjf ${ROOTFS_TARBALL} *
    popd &> /dev/null

    if [ "${IMAGE_TARGET_TYPE}" = "installer" ]
    then
        INSTALLER_BINARY="${SCRIPT_PATH}/${IMAGE_TYPE}-image-installer_$(date '+%Y%m%d%H%M%S').bin"
        cat "${INSTALLER_SCRIPT}" "${ROOTFS_TARBALL}" > "${INSTALLER_BINARY}"
        chmod +x "${INSTALLER_BINARY}"
        ln -sf "${INSTALLER_BINARY}" "${SCRIPT_PATH}/${IMAGE_TYPE}-image-installer_latest.bin"
    fi
fi

if [ "${IMAGE_TARGET_TYPE}" = "installation" ]
then
    LATEST_INSTALLER_BINARY="$(readlink -f "${SCRIPT_PATH}/${IMAGE_TYPE}-image-installer_latest.bin")"
    if [ -e "${LATEST_INSTALLER_BINARY}" ]
    then
        cp ${LATEST_INSTALLER_BINARY} "${ROOTFS_PATH}/home/${IMAGE_USER}/"
    else
        console_log "Image installer binary not found!"
        console_log "Please create a \"${IMAGE_TYPE}\" image installer binary first!"
        exit 1
    fi
fi

if [ "${IMAGE_TARGET_TYPE}" = "dev" -o "${IMAGE_TARGET_TYPE}" = "loop" ]
then
    losetup -D
    umount "${ROOTFS_PATH}"
fi














