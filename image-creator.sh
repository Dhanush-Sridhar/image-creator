#!/bin/bash

# ===============================================
# Image Creator Script
# ===============================================
# This script uses debootstrap to creates an
# installer whichs wipes and fromats the SSD on
# /dev/sda and installs the system.
#
# Debootstrap uses the host OS; thus the script
# used to be run on a Ubuntu-based machine.
#
# Further Information:
# https://wiki.ubuntuusers.de/Installation_mit_debootstrap/
# ===============================================

# allows tracing output separated from error messages
[ ! -z "${DEBUG}" ] && set -x


# Machines Serial Number for Sitemanager / WiMotion Identification
IMAGE_HOSTNAME="pcm-cutter-<machine-id>"


# ===============================================
# WORK / SCRIPT PATH
# ===============================================
SCRIPT_PATH="$(dirname $(readlink -f $0))"
WORK_PATH="$PWD"

# ===============================================
# DEBOOTSTRAP (DEFAULTS)
# ===============================================
APT_CMD="apt"
ARCH="amd64"
DISTRO="focal"
DEBOOTSTRAP_OPTIONS=""

# ===============================================
# FILE PATHS
# ===============================================
INSTALLER_SCRIPT="${WORK_PATH}/image-installer.sh"
ROOTFS_IMAGE_FILE="${WORK_PATH}/rootfs.img"
ROOTFS_TARBALL="${WORK_PATH}/rootfs.tar.bz2"
ROOTFS_PATH="${WORK_PATH}/rootfs"
DATAFS_PATH="${WORK_PATH}/rootfs/data"

# ===============================================
# CONF PATHS
# ===============================================
ROOTFS_CONF_PATH="${WORK_PATH}/confs/system"
APP_CONF_PATH="${WORK_PATH}/confs/app"
PERMISSIONS_CONF="${ROOTFS_CONF_PATH}/permissions.conf"


# ===============================================
# PACKAGE PATHS
# ===============================================
PKG_DEB_PATH="${WORK_PATH}/packages/deb"                     # copy <HMI>.deb here
PKG_TARBALLS_PATH="${WORK_PATH}/packages/tarballs"
PKG_BINARIES_PATH="${WORK_PATH}/packages/binaries"
PKG_SITEMANAGER_PATH="${WORK_PATH}/packages/sitemanager"     # copy sitemanager tarball here
PKG_DRIVER_PATH="${WORK_PATH}/packages/drivers/"

# ===============================================
# IMAGE CONFIGS (DEFAULTS)
# ===============================================
IMAGE_USER="polar"
IMAGE_PASSWORD="evis32"
MACHINE_TYPE_PLACEHOLDER="PACE"
VNC_PASSWORD="${IMAGE_PASSWORD}"
#IMAGE_HOSTNAME="pcm-cutter-12345"
#QT_VERSION="5.15.0"

# ===============================================
# OPTIONS (DEFAULT)
# ===============================================
CLEAN="NO"
INSTALL_QT="NO"
INSTALL_WIFI="NO"
ENTER_CHROOT="NO"
IMAGE_TYPE="production"
IMAGE_TARGET="installer"

# ===============================================
# PACKAGE LISTS
# ===============================================
PKG_BASE_IMAGE="sudo apt-utils"
PKG_RUNTIME_IMAGE="less wget vim ssh linux-image-generic nodm xinit openbox xterm \
    network-manager x11-xserver-utils libmbedtls12 apt-offline psmisc dosfstools lsscsi \
    x11vnc vsftpd libxcb-* libxkbcommon-x11-0 htop nano usbutils unzip lshw lsof neofetch"
PKG_DEVELOP="git xvfb flex bison libxcursor-dev libxcomposite-dev build-essential \
    libssl-dev libxcb1-dev libgl1-mesa-dev libmbedtls-dev"
PKG_BUILD="dpkg-dev dh-make devscripts git-buildpackage quilt make dkms" #linux-headers-generic
PKG_INSTALLATION_IMAGE="gdisk"
PKG_BLUETOOTH="bluez"
PKG_NETWORK="net-tools nmap tcpdump ethtool netdiscover w3m"
PKG_TIME_SERVER="chrony"

PKG_WEBVIEW_PACKAGES="libnss3 libevent-dev libopus-dev libvpx6 libwebp-dev libssl-dev \
    libxcursor-dev libxcomposite-dev libxdamage-dev libxrandr-dev libfontconfig1-dev libxss-dev \
    libwebp-dev libjsoncpp-dev libopus-dev libminizip-dev libavutil-dev libavformat-dev \
    libavcodec-dev libevent-dev libvpx-dev libsnappy-dev libre2-dev libprotobuf-dev protobuf-compiler \
    libnss3-dev libpci-dev libpulse-dev libudev-dev libxtst-dev \
    nodejs gyp ninja-build bison build-essential gperf flex python2 \
    libasound2-dev libcups2-dev libdrm-dev libegl1-mesa-dev"
    # TODO: remove unused packages later

# install qt
#QT_SHORT_VERSION="$(echo ${QT_VERSION%.*} | tr -d '.')"
#QT_IMAGE_PACKAGES="qt${QT_SHORT_VERSION}declarative qt${QT_SHORT_VERSION}quickcontrols2 qt${QT_SHORT_VERSION}graphicaleffects qt${QT_SHORT_VERSION}svg qt${QT_SHORT_VERSION}serialport"


# ===============================================
# OPTION LIST
# ===============================================
ARCH_LIST="i386 amd64 armel armhf"
IMAGE_TYPE_LIST="production development installation"


# ==================== FUNCTIONS ====================== #

# ===============================================
# FUNCTIONS - ABOUT / USAGE
# ===============================================
function about() {
echo "############################################"
echo "# Ubuntu image creator                     #"
echo "# ---------------------------------------- #"
echo "# Author: Benjamin Federau                 #"
echo "#         <benjamin.federau@basyskom.com>  #"
echo "# ---------------------------------------- #"
echo "# (c) Adolf Mohr Maschinenfabrik           #"
echo "############################################"
echo""
}

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
    echo "      Specifies the image target. The option string can be either \"loop\", /dev/sdX, \"tarball\", \"installer\" or \"none\"."
    echo ""
    echo "  --image-type <string> :"
    echo "      Specifies the image type. Available image types: ${IMAGE_TYPE_LIST// /, }"
    echo "      Default: ${IMAGE_TYPE}"
    echo ""
    echo "  --install-qt :"
    echo "      Installs the Stephan Binner qt version 5.15.0 ubuntu package."
    echo ""
    echo "  --install-wifi :"
    echo "      Installs Wi-Fi driver for Edimax N150 (EW7811UnV2/EW-7611ULB)"
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

# ===============================================
# FUNCTIONS - LOG
# ===============================================
function console_log() {
    echo "$1"
}

function error() {
    echo "$1"
    exit 1
}

# ===============================================
# FUNCTIONS - MOUNT /DEV /SYS /PROC
# ===============================================
function mount_dev_sys_proc() {
    local _ROOTFS_PATH="$1"
    console_log "=========================================================="
    console_log "### Mount dev, proc, sys to rootfs ###"
    console_log "=========================================================="
    [ -e "${_ROOTFS_PATH}" ] || error "Path ${_ROOTFS_PATH} not found!"
    mount -o bind /dev "${_ROOTFS_PATH}/dev"
    mount -o bind /dev/pts "${_ROOTFS_PATH}/dev/pts"
    mount -o bind /sys "${_ROOTFS_PATH}/sys"
    mount -t proc /proc "${_ROOTFS_PATH}/proc"
}

function umount_dev_sys_proc() {
    local _ROOTFS_PATH="$1"
    console_log "=========================================================="
    console_log "### Unmount dev, proc, sys from rootfs ###"
    console_log "=========================================================="
    [ -e "${_ROOTFS_PATH}" ] || error "Path ${_ROOTFS_PATH} not found!"
    umount "${_ROOTFS_PATH}/dev/pts"
    umount "${_ROOTFS_PATH}/dev"
    umount "${_ROOTFS_PATH}/sys"
    umount "${_ROOTFS_PATH}/proc"
}

# ===============================================
# FUNCTIONS - CREATE PARTITIONS
# ===============================================
function create_partitions() {
    local _IMAGE_TARGET="$1"
    local _BOOT_PARTITION="$2"
    local _ROOTFS_PARTITION="$3"
    local _DATAFS_PARTITION="$4"

    console_log "=========================================================="
    console_log "### Create partitions for ${_IMAGE_TARGET} ###"
    console_log "=========================================================="
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

# ===============================================
# FUNCTIONS - CREATE PARTITIONS
# ===============================================
function mount_rootfs_datafs() {
    local _ROOTFS_PARTITION="$1"
    local _ROOTFS_PATH="$2"
    local _DATAFS_PARTITION="$3"
    local _DATAFS_PATH="$4"

    mount "${_ROOTFS_PARTITION}" "${_ROOTFS_PATH}" || error "Could not mount ${_ROOTFS_PARTITION} to ${_ROOTFS_PATH}!"
    mkdir -p "${_DATAFS_PATH}"
    mount "${_DATAFS_PARTITION}" "${_DATAFS_PATH}" || error "Could not mount ${_DATAFS_PARTITION} to ${_DATAFS_PATH}!"
}



# ==================== PARAMETERS ====================== #

# ===============================================
# PARAMETERS - CLI ARGUMENTS / TRIGGER
# ===============================================
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
            [ -e "${ROOTFS_PATH}" ] && umount_dev_sys_proc "${ROOTFS_PATH}" || echo "No remaining mount to rootfs. Clean canvas! :)"
            rm -rf "${ROOTFS_PATH}"
            shift
            ;;
        --install-qt)
            INSTALL_QT="YES"
            shift
            ;;
        --install-wifi)
            INSTALL_WIFI="YES"
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
            about
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


# ==================== CHECKS ====================== #

[ "$(whoami)" != "root" ] && console_log "You must be root or use the sudo command!" && exit 1

# ===============================================
# DEBOOTSTRAP
# ===============================================
DEBOOTSTRAP_CMD="$(which debootstrap)"
QEMU_DEBOOTSTRAP_CMD="$(which qemu-debootstrap)"

console_log "Generate target=${IMAGE_TARGET} type=${IMAGE_TYPE}"
console_log ""

if [ -z "${DEBOOTSTRAP_CMD}" -o -z "${QEMU_DEBOOTSTRAP_CMD}" ]
then
    console_log "=========================================================="
    console_log "### Installing needed host packages ###"
    console_log "=========================================================="
    ${APT_CMD} update
    ${APT_CMD} -y install debootstrap qemu-user-static || error "Could not install host packages!"
    DEBOOTSTRAP_CMD="$(which debootstrap)"
    QEMU_DEBOOTSTRAP_CMD="$(which qemu-debootstrap)"
fi

# ===============================================
# DISTRO
# ===============================================
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

# ===============================================
# IMAGE TARGET
# ===============================================
if [ ! -z "${IMAGE_TARGET}" ]
then
    case ${IMAGE_TARGET} in
        loop)
            IMAGE_TARGET_TYPE="loop"
            [ "${CLEAN}" = "YES" ] && rm -f "${WORK_PATH}/"*.img
            ;;
        *dev*)
            IMAGE_TARGET_TYPE="dev"
            [ -e "${IMAGE_TARGET}" ] || error "Device ${IMAGE_TARGET} not found!"
            PART_TOOL="$(which sgdisk)"
            [ -e "${PART_TOOL}" ] || error "No partition tool found!"
            ;;
        tarball)
            IMAGE_TARGET_TYPE="tarball"
            [ "${CLEAN}" = "YES" ] && rm -f "${WORK_PATH}/"*.tar.*
            ;;
        installer)
            IMAGE_TARGET_TYPE="installer"
            [ "${CLEAN}" = "YES" ] && rm -f "${WORK_PATH}/"*.tar.* "${WORK_PATH}/"*.bin
            ;;
        none)
            IMAGE_TARGET_TYPE="none"
            [ "${CLEAN}" = "YES" ] && rm -f "${WORK_PATH}/"*.tar.* "${WORK_PATH}/"*.bin "${WORK_PATH}/"*.img
            ##echo $SUDO_USER
            exit 0
            ;;
        *)
            console_log "Unknown image target ${IMAGE_TARGET}!"
            console_log "Available image types: loop | /dev/sdX | tarball | installer | none"
            console_log ""  
            exit 1
            ;;
    esac
fi

# ===============================================
# PACKAGES TO INSTALL
# ===============================================
if [ ! -z "${IMAGE_TYPE}" ]
then
    case ${IMAGE_TYPE} in
        production)
            IMAGE_PACKAGE_LIST="${PKG_RUNTIME_IMAGE} ${PKG_BLUETOOTH} ${PKG_BUILD} ${PKG_NETWORK} ${PKG_TIME}"
            ;;
        development)
            IMAGE_PACKAGE_LIST="${PKG_DEV_IMAGE}"
            ;;
        installation)
            IMAGE_PACKAGE_LIST="${PKG_INSTALLATION_IMAGE} ${PKG_RUNTIME_IMAGE}"
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

mkdir -p "${ROOTFS_PATH}"
sudo -u $SUDO_USER mkdir -p "${PKG_DEB_PATH}" "${PKG_TARBALLS_PATH}" "${PKG_BINARIES_PATH}"


# ====================== MAIN ======================== #

export DEBIAN_FRONTEND=noninteractive

console_log "====================================================="
console_log "#   Image-Creator v1.0                              #"
console_log "#                                                   #"
console_log "#   Building an installer/image with ...            #"
console_log "#   ${ARCH}                                         #"
console_log "#   ${DISTRO}                                       #"
console_log "#   ${IMAGE_TYPE}                                   #"
console_log "#   ${IMAGE_TARGET}                                 #"
console_log "#                                                   #"
console_log "====================================================="



# ===============================================
# IMAGE-TARGET: LOOP
# ===============================================
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
    
    mount_rootfs_datafs "${ROOTFS_PARTITION}" "${ROOTFS_PATH}" "${DATAFS_PARTITION}" "${DATAFS_PATH}"
fi

# ===============================================
# IMAGE-TARGET: DEV
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "dev" ]
then
    BOOT_PARTITION="${IMAGE_TARGET}1"
    ROOTFS_PARTITION="${IMAGE_TARGET}2"
    DATAFS_PARTITION="${IMAGE_TARGET}3"

    create_partitions "${IMAGE_TARGET}" "${BOOT_PARTITION}" "${ROOTFS_PARTITION}" "${DATAFS_PARTITION}"

    mount_rootfs_datafs "${ROOTFS_PARTITION}" "${ROOTFS_PATH}" "${DATAFS_PARTITION}" "${DATAFS_PATH}"
fi

# ===============================================
# create an initial rootfs using debootstrap
# ===============================================
if [ ! -e "${ROOTFS_PATH}/etc/os-release" ]
then
    console_log "=========================================================="
    console_log "### Create rootfs ### "
    console_log "=========================================================="
    if [ "${ARCH}" != "i386" -o "${ARCH}" != "amd64" ]
    then
        HOSTNAME=${IMAGE_HOSTNAME} ${QEMU_DEBOOTSTRAP_CMD} --no-check-gpg ${DEBOOTSTRAP_OPTIONS} --arch=${ARCH} ${DISTRO} ${ROOTFS_PATH} --include "${PKG_BASE_IMAGE}"
    else
        HOSTNAME=${IMAGE_HOSTNAME} ${DEBOOTSTRAP_CMD} --no-check-gpg ${DEBOOTSTRAP_OPTIONS} --arch=${ARCH} ${DISTRO} ${ROOTFS_PATH} --include "${PKG_BASE_IMAGE}"
    fi
fi
DISTRO_ID="$(source rootfs/etc/os-release && echo $ID)"

mount_dev_sys_proc "${ROOTFS_PATH}"

# ===============================================
# create the sources.list files for apt:
# ===============================================
console_log "=========================================================="
console_log "### Create sources.list ###"
console_log "=========================================================="

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
        #chroot ${ROOTFS_PATH} add-apt-repository -y ppa:beineri/opt-qt-${QT_VERSION}-${DISTRO}
    fi
fi

console_log "=========================================================="
console_log "### Configure locales ###"
console_log "=========================================================="
chroot ${ROOTFS_PATH} locale-gen de_DE.UTF-8

console_log "=========================================================="
console_log "### Configure dash/bash ###"
console_log "=========================================================="
chroot ${ROOTFS_PATH} /bin/bash -c 'echo "dash dash/sh boolean false" | debconf-set-selections'
chroot ${ROOTFS_PATH} /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash'

# update rootfs
console_log "=========================================================="
console_log "### Update rootfs ###"
console_log "=========================================================="
cp /etc/resolv.conf ${ROOTFS_PATH}/etc
chroot ${ROOTFS_PATH} ${APT_CMD} update
POLICY_RC_D_FILE="${ROOTFS_PATH}/usr/sbin/policy-rc.d"
install -m 0644 ${ROOTFS_CONF_PATH}/policy-rc.d ${POLICY_RC_D_FILE}
chroot ${ROOTFS_PATH} ${APT_CMD} -y dist-upgrade

# install some fundamental packages
console_log "=========================================================="
console_log "### Install packages in rootfs ###"
console_log "=========================================================="
chroot ${ROOTFS_PATH} ${APT_CMD} update
chroot ${ROOTFS_PATH} ${APT_CMD} -y install ${IMAGE_PACKAGE_LIST}
chroot ${ROOTFS_PATH} ${APT_CMD} -y clean

# ===============================================
# IMAGE-TYPE: NOT INSTALLATION
# ===============================================

console_log "=========================================================="
console_log "### Install local packages to the rootfs ###"
console_log "=========================================================="
if [ "${IMAGE_TYPE}" != "installation" ]
then
    #################### Qt 5.15.0 by Stephan Binner ###########################
    if [ ${INSTALL_QT} = "YES" ]
    then
        ## Tarball packages
        for TAR_FILE in $(ls -1 ${PKG_TARBALLS_PATH}/*.tar*)
        do  
            console_log "## Install $(basename ${TAR_FILE}) to rootfs ##"
            console_log "=========================================================="
            tar -xf ${TAR_FILE} -C ${ROOTFS_PATH}
        done
    fi


    #################### Debian packages ########################################
    mount -o bind "${PKG_DEB_PATH}" "${ROOTFS_PATH}/mnt"
    for DEB_FILE in $(ls -1 ${PKG_DEB_PATH}/*.deb)
    do
        console_log "## Install $(basename ${DEB_FILE}) to rootfs ##"
        console_log "=========================================================="
        chroot "${ROOTFS_PATH}" dpkg -i "/mnt/$(basename ${DEB_FILE})"
    done
    umount "${ROOTFS_PATH}/mnt"

    ## Binary files
    find ${PKG_BINARIES_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ${ROOTFS_PATH} \;
fi


# ===============================================
# SITEMANAGER
# ===============================================

console_log "Install Site-Manager for Remote Maintenance"
    
for TAR_FILE in $(ls -1 ${PKG_SITEMANAGER_PATH}/*.tar*)
do
    console_log "## Install $(basename ${TAR_FILE}) to rootfs ##"
    console_log "=========================================================="
    tar -xvf ${TAR_FILE} -C ${ROOTFS_PATH}/tmp
    chroot "${ROOTFS_PATH}" ls -al "/tmp/"
# Hint: this is formated because of EOF to pipe the install.sh script to chroot
# ---
cat <<EOF | chroot "${ROOTFS_PATH}" 
cd /tmp/SiteManager_Installer/
./install.sh || echo "Failed to remove the directory"
EOF
# ---
    chroot "${ROOTFS_PATH}" rm -r "/tmp/SiteManager_Installer" && chroot "${ROOTFS_PATH}" rm -r "/tmp/INSTALL_SITEMANAGER"
done


# ===============================================
# WIFI
# ===============================================
# Get Driver here
# https://www.edimax.com/edimax/download/download/data/edimax/global/download/for_home/wireless_adapters/wireless_adapters_n150/ew-7611ulb

if [ ${INSTALL_WIFI} = "YES" ]
then
    for TAR_FILE in $(ls -1 ${PKG_DRIVER_PATH}/*.tar.gz*)
    do
        console_log "## Install $(basename ${TAR_FILE}) to rootfs ##"
        console_log "=========================================================="
        tar -xvzf ${TAR_FILE} -C ${ROOTFS_PATH}/tmp
        chroot "${ROOTFS_PATH}" ls -al "/tmp/"
    # Hint: this is formated because of EOF to pipe the install.sh script to chroot
    # ---
cat <<EOF | chroot "${ROOTFS_PATH}" 
cd /tmp/rtl8723BU_WiFi_linux_v5.2.17.1_20190123/
make
sudo make install
sudo modprobe -v 8723bu
EOF
    # ---
        chroot "${ROOTFS_PATH}" rm -r "/tmp/rtl8723BU_WiFi_linux_v5.2.17.1_20190123/"
    done
fi


console_log "=========================================================="
console_log "### User management ###"
console_log "=========================================================="
echo -e "${IMAGE_PASSWORD}\n${IMAGE_PASSWORD}\n" | chroot ${ROOTFS_PATH} passwd root

chroot ${ROOTFS_PATH} adduser --gecos "" --disabled-password ${IMAGE_USER}
chroot ${ROOTFS_PATH} usermod -a -G sudo,video,audio,plugdev ${IMAGE_USER}

chroot ${ROOTFS_PATH} adduser --gecos "" --disabled-password --force-badname BoxPC     #TODO: changePW
echo -e "BoxPC\nBoxPC\n" | chroot ${ROOTFS_PATH} passwd BoxPC                          #TODO: changePW

echo -e "${IMAGE_PASSWORD}\n${IMAGE_PASSWORD}\n" | chroot ${ROOTFS_PATH} passwd ${IMAGE_USER}

console_log "=========================================================="
console_log "### Configure rootfs ###"
console_log "=========================================================="

## install (pre)config files to rootfs
find ${ROOTFS_CONF_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ${ROOTFS_PATH} \;

echo "${IMAGE_HOSTNAME}" > ${ROOTFS_PATH}/etc/hostname
sed -i "s/replace-me/${IMAGE_HOSTNAME}/g" ${ROOTFS_PATH}/etc/hosts

# ===============================================
# IMAGE-TYPE: DEVELOPMENT
# ===============================================
if [ "${IMAGE_TYPE}" != "development" ]
then
    sed -i "s/NODM_ENABLED=false/NODM_ENABLED=true/g" ${ROOTFS_PATH}/etc/default/nodm
    sed -i "s/NODM_USER=root/NODM_USER=${IMAGE_USER}/g" ${ROOTFS_PATH}/etc/default/nodm
    sed -i "s/NODM_X_OPTIONS='-nolisten tcp'/NODM_X_OPTIONS='-nolisten tcp -nocursor'/g" ${ROOTFS_PATH}/etc/default/nodm

    mkdir -p ${ROOTFS_PATH}/home/${IMAGE_USER}/.config/openbox
    install -m 0644 ${ROOTFS_CONF_PATH}/autostart ${ROOTFS_PATH}/home/${IMAGE_USER}/.config/openbox
    chroot "${ROOTFS_PATH}" chown -R ${IMAGE_USER}:${IMAGE_USER} /home/${IMAGE_USER}/.config/

    mkdir -p ${ROOTFS_PATH}/home/${IMAGE_USER}/.vnc/
    chroot "${ROOTFS_PATH}" x11vnc -storepasswd ${VNC_PASSWORD} /home/${IMAGE_USER}/.vnc/passwd
    chroot "${ROOTFS_PATH}" chown -R ${IMAGE_USER}:${IMAGE_USER} /home/${IMAGE_USER}/.vnc/
fi

# ===============================================
# IMAGE-TYPE: PRODUCTION
# ===============================================
if [ "${IMAGE_TYPE}" = "production" ]
then
    chroot "${ROOTFS_PATH}" ln -sf /data/ispv_root /ispv_root
    find ${APP_CONF_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -a {} ${ROOTFS_PATH} \;
fi

# ===============================================
# PERMISSIONS / OWNER
# ===============================================
## configure file permissions and owner
for PERMS in $(cat ${PERMISSIONS_CONF})
do
    FILE_NAME=$(echo "${PERMS}" | cut -d, -f1)
    FILE_PERM=$(echo "${PERMS}" | cut -d, -f2)
    FILE_OWNER=$(echo "${PERMS}" | cut -d, -f3)
    chroot "${ROOTFS_PATH}" chown ${FILE_OWNER} ${FILE_NAME}
    chroot "${ROOTFS_PATH}" chmod ${FILE_PERM} ${FILE_NAME}
done

# ===============================================
# NTP
# ===============================================
console_log "=========================================================="
console_log "### ntp configuration ###"
console_log "=========================================================="
mv ${ROOTFS_PATH}/etc/ntp.conf ${ROOTFS_PATH}/etc/ntp.conf.standard
# copy target ntp configuration
install -m 0644 ${ROOTFS_CONF_PATH}/etc/ntp.conf ${ROOTFS_PATH}/etc/
#install -m 0644 ${ROOTFS_CONF_PATH}/etc/chrony.conf ${ROOTFS_PATH}/etc/

## add system tool calls for application in sudoers (mount, etc...)
##
# ALL       ALL =(ALL) NOPASSWD: /bin/mount
# ALL       ALL =(ALL) NOPASSWD: /bin/umount
# ALL       ALL =(ALL) NOPASSWD: /bin/date
# ALL       ALL =(ALL) NOPASSWD: /sbin/reboot
# ALL       ALL =(ALL) NOPASSWD: /sbin/halt
# ALL       ALL =(ALL) NOPASSWD: /sbin/hwclock
##
console_log "=========================================================="
console_log "### Configure sudoers ###"
console_log "=========================================================="
chroot "${ROOTFS_PATH}" chmod +w /etc/sudoers
echo -e "\n## Polar Cutter Application Calls" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "ALL\tALL =(ALL) NOPASSWD: /bin/mount" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "ALL\tALL =(ALL) NOPASSWD: /bin/umount" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "ALL\tALL =(ALL) NOPASSWD: /bin/date" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "ALL\tALL =(ALL) NOPASSWD: /sbin/reboot" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "ALL\tALL =(ALL) NOPASSWD: /sbin/halt" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "ALL\tALL =(ALL) NOPASSWD: /sbin/hwclock" >> ${ROOTFS_PATH}/etc/sudoers
echo -e "## ---\n" >> ${ROOTFS_PATH}/etc/sudoers
chroot "${ROOTFS_PATH}" chmod -w /etc/sudoers




# ===============================================
# OPTION: ENTER CHROOT
# ===============================================
if [ "${ENTER_CHROOT}" = "YES" ]
then
    chroot "${ROOTFS_PATH}"
fi

# ===============================================
# IMAGE-TARGET: DEV / LOOP
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "dev" -o "${IMAGE_TARGET_TYPE}" = "loop" ]
then
    console_log "=========================================================="
    console_log "### Install fstab ###"
    console_log "=========================================================="
    UUID_ROOTFS=$(/bin/lsblk -o UUID -n ${ROOTFS_PARTITION})
    UUID_DATAFS=$(/bin/lsblk -o UUID -n ${DATAFS_PARTITION})
    echo "Default fstab before modification:"
    cat /etc/fstab
# write fstab
# ---
cat <<EOF > ${ROOTFS_PATH}/etc/fstab
UUID=${UUID_ROOTFS}  /          ext4  errors=remount-ro  0  1
UUID=${UUID_DATAFS}  /data      vfat  uid=${IMAGE_USER},gid=${IMAGE_USER}  0  2
EOF
# ---
    console_log "=========================================================="
    console_log "### Install bootloader ###"
    console_log "=========================================================="
    chmod -x "${ROOTFS_PATH}/etc/grub.d/30_os-prober"
    chroot "${ROOTFS_PATH}" grub-install --force ${IMAGE_TARGET}
    chroot "${ROOTFS_PATH}" update-grub
fi

rm -f ${POLICY_RC_D_FILE}
sync

umount_dev_sys_proc "${ROOTFS_PATH}"

# ===============================================
# TARBALL / INSTALLER
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "tarball" -o "${IMAGE_TARGET_TYPE}" = "installer" ]
then
    console_log "=========================================================="
    console_log "### Create rootfs tarball ###"
    console_log "=========================================================="
    pushd "${ROOTFS_PATH}" &> /dev/null
    tar -cjf ${ROOTFS_TARBALL} * || exit 1
    chgrp $SUDO_GID "${ROOTFS_TARBALL}"
    chown $SUDO_USER "${ROOTFS_TARBALL}"
    popd &> /dev/null

    if [ "${IMAGE_TARGET_TYPE}" = "installer" -o "${IMAGE_TYPE}" = "installation" ]
    then
        INSTALLER_BINARY="${WORK_PATH}/${IMAGE_TYPE}-image-installer_$(date '+%Y-%m-%d_%H-%M-%S').bin"
        cat "${INSTALLER_SCRIPT}" "${ROOTFS_TARBALL}" > "${INSTALLER_BINARY}"
        chmod +x "${INSTALLER_BINARY}"
        chgrp $SUDO_GID "${INSTALLER_BINARY}"
        chown $SUDO_USER "${INSTALLER_BINARY}"
        sudo -u $SUDO_USER ln -sf "${INSTALLER_BINARY}" "${WORK_PATH}/${IMAGE_TYPE}-image-installer_latest.bin"
        ##echo installer done here...
        ##ls -l "${INSTALLER_BINARY}"
    fi
fi

# ===============================================
# IMAGE-TYPE: INSTALLATION
# ===============================================
if [ "${IMAGE_TYPE}" = "installation" ]
then
    LATEST_INSTALLER_BINARY="$(readlink -f "${WORK_PATH}/${IMAGE_TYPE}-image-installer_latest.bin")"
    if [ -e "${LATEST_INSTALLER_BINARY}" ]
    then
        cp ${LATEST_INSTALLER_BINARY} "${ROOTFS_PATH}/home/${IMAGE_USER}/"
    else
        console_log "Image installer binary not found!"
        console_log "Please create a ${IMAGE_TYPE} image installer binary first!"
        console_log "e.g.: $0 --arch amd64 --distro focal --image-target installer --image-type production"
        exit 1
    fi
fi

# ===============================================
# IMAGE-TYPE: DEV / LOOP
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "dev" -o "${IMAGE_TARGET_TYPE}" = "loop" ]
then
    losetup -D
    umount "${DATAFS_PATH}"
    umount "${ROOTFS_PATH}"
fi

console_log "=========================================================="
console_log "### DONE! ###"
console_log "=========================================================="
