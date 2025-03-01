#!/bin/bash
# allows tracing output separated from error messages
[ ! -z "${DEBUG}" ] && set -x

REPO_ROOT=$(git rev-parse --show-toplevel)

echo "Load configuration ..."
BUILD_CONFIG=$REPO_ROOT/scripts/config/build.conf
source $BUILD_CONFIG && echo "$BUILD_CONFIG was sourced!" || echo "Failed to source config: $BUILD_CONFIG" | exit 1

IMAGE_CONFIG=$REPO_ROOT/scripts/config/${MACHINE}-image.conf
source $IMAGE_CONFIG && echo "$IMAGE_CONFIG was sourced!" || { echo "Failed to source config: $IMAGE_CONFIG. please check the if the machine type is valid  " ; exit 1; }

HELPERS=$REPO_ROOT/scripts/helpers.sh
source $HELPERS && echo "$HELPERS was sourced!" || echo "Failed to source config: $HELPERS"

#PULL_PKG_SCRIPT=$REPO_ROOT/scripts/pull-packages.sh
#source $PULL_PKG_SCRIPT && echo "$PULL_PKG_SCRIPT was sourced!" || echo "Failed to source config: $PULL_PKG_SCRIPT"

VERSION_FILE=$REPO_ROOT/version
VERSION=$(cat version) || echo "Failed to read version file: $VERSION_FILE"


DEBOOTSTRAP_CMD="$(which debootstrap)"
QEMU_DEBOOTSTRAP_CMD="$(which qemu-debootstrap)"

export DEBIAN_FRONTEND=noninteractive

# ===============================================
# FUNCTIONS - ABOUT / USAGE
# ===============================================

function about() {
  cat <<EOF
┌──────────────────────────────────────────────────┐
│      Polar OS Image Creator                      │
│ ------------------------------------------------ │
│ Author:   Benjamin Federau                       │
│           Suria Reddy                            │
│           Dhanush Sridhar                        │
│ Version:  ${VERSION}        │
│ ------------------------------------------------ │
│ Purpose: Builds a Linux rootfs and installer     │
│          as base image for Box-PC applications.  │
└──────────────────────────────────────────────────┘
EOF
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
    echo "  --machine <string> :"
    echo "      Specifies the image type. Available image types: ${MACHINE_LIST// /, }"
    echo "      Default: ${MACHINE}"
    echo ""
    echo "  --install-qt :"
    echo "      Installs the Stephan Binner qt version 5.15.0 ubuntu package."
    echo "      Default: ${INSTALL_QT5}"
    echo ""
    echo "  --install-wifi :"
    echo "      Installs Wi-Fi driver for Edimax N150 (EW7811UnV2/EW-7611ULB)"
    echo "      Default: ${INSTALL_WIFI}"
    echo ""
    echo "  --pull-packages :"
    echo "	Pull packages from app repo (i.e. Nexus)"
    echo "      Default: ${PULL_PACKAGES}"
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

function print_env() {
    step_log "BUILD CONFIG"
    echo "Image-Creator v$VERSION"
    echo "Architecture: ${ARCH}"
    echo "Distro: ${DISTRO}"
    echo "Image Type: ${IMAGE_TYPE}"
    echo "Image Target: ${IMAGE_TARGET}"
    echo "Machine Type : ${MACHINE}"
    echo
}

# ===============================================
# ROOT CHECK
# ===============================================
function root_check() {
    [ "$(whoami)" != "root" ] && console_log "You must be root or use the sudo command!" && exit 1
}

# ===============================================
# FUNCTIONS - MOUNT /DEV /SYS /PROC
# ===============================================
function mount_dev_sys_proc() {
    local _ROOTFS_PATH="$1"
    step_log "### Mount dev, proc, sys to rootfs ###"
    [ -e "${_ROOTFS_PATH}" ] || error "Path ${_ROOTFS_PATH} not found!"

    local dev="${_ROOTFS_PATH}/dev"
    local pts="${_ROOTFS_PATH}/dev/pts"
    local sys="${_ROOTFS_PATH}/sys"
    local proc="${_ROOTFS_PATH}/proc"

    mount -o bind /dev      "$dev"  && echo "$dev mounted"  || echo "Failed to mount $dev"
    mount -o bind /dev/pts  "$pts"  && echo "$pts mounted"  || echo "Failed to mount $pts"
    mount -o bind /sys      "$sys"  && echo "$sys mounted"  || echo "Failed to mount $sys"
    mount -t proc /proc     "$proc" && echo "$proc mounted" || echo "Failed to mount $proc"
}

function umount_dev_sys_proc() {
    local _ROOTFS_PATH="$1"
    step_log "### Unmount dev, proc, sys from rootfs ###"
    [ -e "${_ROOTFS_PATH}" ] || error "Path ${_ROOTFS_PATH} not found!"

    local pts="${_ROOTFS_PATH}/dev/pts"
    local dev="${_ROOTFS_PATH}/dev"
    local sys="${_ROOTFS_PATH}/sys"
    local proc="${_ROOTFS_PATH}/proc"

    umount "$pts"   && echo "$pts unmounted"  || echo "Failed to unmount $pts"
    umount "$dev"   && echo "$dev unmounted"  || echo "Failed to unmount $dev"
    umount "$sys"   && echo "$sys unmounted"  || echo "Failed to unmount $sys"
    umount "$proc"  && echo "$proc unmounted" || echo "Failed to unmount $proc"
}

# ===============================================
# FUNCTIONS - CREATE PARTITIONS
# ===============================================
function create_partitions() {
    step_log "### Create partitions for ${_IMAGE_TARGET} ###"

    local _IMAGE_TARGET="$1"
    local _BOOT_PARTITION="$2"
    local _ROOTFS_PARTITION="$3"
    local _DATAFS_PARTITION="$4"

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

# ===============================================
# FUNCTIONS - INSTALL POLAR FONT
# ===============================================

if [ $INSTALL_POLAR_FONT -eq 1 ]; then
    step_log "### Install Polar fonts ###"
 
    readonly FONT_CONF_DIR="${ROOTFS_CONF_PATH}/font/polar/"
    readonly FONT_ROOTFS_DIR="${ROOTFS_PATH}/usr/share/fonts/truetype/polar"

    function install_fonts() {
        mkdir -p ${FONT_ROOTFS_DIR}
        local font_files=("arialuni.ttf" "fonts.dir" "fonts.scale")
        for file in "${font_files[@]}"; do
            install -m 0644 "${FONT_CONF_DIR}/${file}" "${FONT_ROOTFS_DIR}/${file}" && console_log "Font file ${file} installed successfully."
            if [ $? -ne 0 ]; then
                console_log "Error: Failed to install font file ${file}."
            fi
        done
    }
else
    step_log "### remove Polar fonts ###"
    rm -r ${ROOTFS_PATH}/fonts
fi


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
            root_check
            [ -e "${ROOTFS_PATH}" ] && umount_dev_sys_proc "${ROOTFS_PATH}" || echo "No remaining mount to rootfs. Clean canvas! :)"
            rm -rvf "${ROOTFS_PATH}" && exit 0
            shift
            ;;
        --install-qt)
            INSTALL_QT5="YES"
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
        --machine)
            MACHINE="$2"
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


root_check

# ===============================================
# HOST INIT
# ===============================================
if [ -z "${DEBOOTSTRAP_CMD}" ] || [ -z "${QEMU_DEBOOTSTRAP_CMD}" ]; then
    step_log "### Installing needed host packages ###"
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
  if [ "${DISTRO}" = "${DISTRO_NAME}" ]; then
    DISTRO_OK="true"
    break
  fi
done
  
if [ "${DISTRO_OK}" = "false" ]; then
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
            [ "${CLEAN}" = "YES" ] && rm -f "${TMP_PATH}/"*.img
            ;;
        *dev*)
            IMAGE_TARGET_TYPE="dev"
            [ -e "${IMAGE_TARGET}" ] || error "Device ${IMAGE_TARGET} not found!"
            PART_TOOL="$(which sgdisk)"
            [ -e "${PART_TOOL}" ] || error "No partition tool found!"
            ;;
        tarball)
            IMAGE_TARGET_TYPE="tarball"
            [ "${CLEAN}" = "YES" ] && rm -f "${TMP_PATH}/"*.tar.*
            ;;
        installer)
            IMAGE_TARGET_TYPE="installer"
            [ "${CLEAN}" = "YES" ] && rm -f "${TMP_PATH}/"*.tar.* "${TMP_PATH}/"*.bin
            ;;
        none)
            IMAGE_TARGET_TYPE="none"
            [ "${CLEAN}" = "YES" ] && rm -f "${TMP_PATH}/"*.tar.* "${TMP_PATH}/"*.bin "${TMP_PATH}/"*.img
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
            IMAGE_PACKAGE_LIST="${PKG_BASE_IMAGE} ${PKG_RUNTIME_IMAGE}"
            ;;
        development)
            IMAGE_PACKAGE_LIST="${PKG_BASE_IMAGE} ${PKG_DEV_IMAGE}"
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
# remove rootfs if exists
umount_dev_sys_proc "${ROOTFS_PATH}"

if [ -d "${ROOTFS_PATH}" ]; then
    step_log "### removing exsisting rootfs###"
    rm -r ${ROOTFS_PATH}
fi


mkdir -p "${ROOTFS_PATH}"
sudo -u $SUDO_USER mkdir -p "${PKG_DEB_PATH}" "${PKG_TARBALLS_PATH}" "${PKG_BINARIES_PATH}"


# ====================== MAIN ======================== #



print_env

# ===============================================
# IMAGE-TARGET: LOOP
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "loop" ]; then

    if [ ! -e "${ROOTFS_IMAGE_FILE}" ]; then
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
if [ "${IMAGE_TARGET_TYPE}" = "dev" ]; then
    BOOT_PARTITION="${IMAGE_TARGET}1"
    ROOTFS_PARTITION="${IMAGE_TARGET}2"
    DATAFS_PARTITION="${IMAGE_TARGET}3"

    create_partitions "${IMAGE_TARGET}" "${BOOT_PARTITION}" "${ROOTFS_PARTITION}" "${DATAFS_PARTITION}"

    mount_rootfs_datafs "${ROOTFS_PARTITION}" "${ROOTFS_PATH}" "${DATAFS_PARTITION}" "${DATAFS_PATH}"
fi

# ===============================================
# create an initial rootfs using debootstrap
# ===============================================


# check if full image cache exists
if [ -e "${ROOTFS_BASE_CACHE_PATH}/etc/os-release" ]; then

    step_log "### Copy rootfs from base cache ###"
    cp -r ${ROOTFS_BASE_CACHE_PATH}/* ${ROOTFS_PATH}
    chroot ${ROOTFS_PATH} chmod 666 /dev/null
    chroot ${ROOTFS_PATH} chown root:root /dev/null
    chroot ${ROOTFS_PATH}  chmod 1777 /tmp
    chroot ${ROOTFS_PATH}  chown root:root /tmp

else
    step_log "### Create rootfs from scratch ###"
    if [ "${ARCH}" != "i386" ] && [ "${ARCH}" != "amd64" ]; then
        HOSTNAME=${IMAGE_HOSTNAME} ${QEMU_DEBOOTSTRAP_CMD} --no-check-gpg ${DEBOOTSTRAP_OPTIONS} --arch=${ARCH} ${DISTRO} ${ROOTFS_PATH}
    else
        HOSTNAME=${IMAGE_HOSTNAME} ${DEBOOTSTRAP_CMD} --no-check-gpg ${DEBOOTSTRAP_OPTIONS} --arch=${ARCH} ${DISTRO} ${ROOTFS_PATH}
    fi

    # create cache  of roofts
    mkdir -p ${ROOTFS_BASE_CACHE_PATH}
    cp -r ${ROOTFS_PATH}/* ${ROOTFS_BASE_CACHE_PATH}
fi


DISTRO_ID="$(source ${ROOTFS_PATH}/etc/os-release && echo $ID)"

mount_dev_sys_proc "${ROOTFS_PATH}"

# ===============================================
# create the sources.list files for apt:
# ===============================================


if [ "${DISTRO_ID}" = "ubuntu" ]; then
    step_log "### Create sources.list ###"
 
    TMP_REPOS="${DISTRO} ${DISTRO}-updates ${DISTRO}-security ${DISTRO}-backports"
    if [ "${ARCH}" = "armel" -a "${ARCH}" = "armhf" ]; then
        REPO_URL="http://de.archive.ubuntu.com/ubuntu"
        REPO_URL=$REPO_URL_ARM
    else
        REPO_URL=$REPO_URL_X86
        REPO_URL="http://de.archive.ubuntu.com/ubuntu"
    fi

    echo "" > "${ROOTFS_PATH}/etc/apt/sources.list"

    for REPO in ${TMP_REPOS}
    do
        echo "deb ${REPO_URL} ${REPO} ${REPO_COMPONENTS}" >> "${ROOTFS_PATH}/etc/apt/sources.list"
        #echo "deb-src ${REPO_URL} ${REPO} ${REPO_COMPONENTS}" >> "${ROOTFS_PATH}/etc/apt/sources.list"
    done

    if [ ${INSTALL_NEXUS_PKG} = "YES" ]; then
         ## add nexus key to keyring
         wget -O ${ROOTFS_PATH}/${KEYRING_PATH} ${NEXUS_REPO_KEYRING}
         ## add nexus repository to source list 
        echo "deb [arch=${ARCH} signed-by=${KEYRING_PATH}]  ${NEXUS_APT_URL}" >> "${ROOTFS_PATH}/etc/apt/sources.list"
    fi
    
    if [ "${IMAGE_TYPE}" != "installation" ]; then
        chroot ${ROOTFS_PATH} ${APT_CMD} update  
        chroot ${ROOTFS_PATH} ${APT_CMD} -y install software-properties-common
        #chroot ${ROOTFS_PATH} add-apt-repository -y ppa:beineri/opt-qt-${QT_VERSION}-${DISTRO}
    fi
fi




# ===============================================
# DASH / BASH
# ===============================================
step_log "### Configure dash/bash ###"
chroot ${ROOTFS_PATH} /bin/bash -c 'echo "dash dash/sh boolean false" | debconf-set-selections'
chroot ${ROOTFS_PATH} /bin/bash -c 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash'

# ===============================================
# UPDATE ROOTFS
# ===============================================
step_log "### Update rootfs ###"
cp -v /etc/resolv.conf ${ROOTFS_PATH}/etc # TODO: error msg
chroot ${ROOTFS_PATH} ${APT_CMD} update
POLICY_RC_D_FILE="${ROOTFS_PATH}/usr/sbin/policy-rc.d"
install -m 0644 ${ROOTFS_CONF_PATH}/policy-rc.d ${POLICY_RC_D_FILE}
chroot ${ROOTFS_PATH} ${APT_CMD} -y dist-upgrade

# ===============================================
# USER MANAGEMENT
# ===============================================
step_log "### User management ###"

echo -e "${IMAGE_PASSWORD}\n${IMAGE_PASSWORD}\n" | chroot ${ROOTFS_PATH} passwd root

chroot ${ROOTFS_PATH} adduser --gecos "" --disabled-password ${IMAGE_USER}
chroot ${ROOTFS_PATH} usermod -a -G sudo,video,audio,plugdev ${IMAGE_USER}

chroot ${ROOTFS_PATH} adduser --gecos "" --disabled-password --force-badname BoxPC     #TODO: changePW
echo -e "BoxPC\nBoxPC\n" | chroot ${ROOTFS_PATH} passwd BoxPC                          #TODO: changePW

echo -e "${IMAGE_PASSWORD}\n${IMAGE_PASSWORD}\n" | chroot ${ROOTFS_PATH} passwd ${IMAGE_USER}

# ===============================================
# INSTALL PACKAGES
# ===============================================
step_log "### Install packages in rootfs ###"
chroot ${ROOTFS_PATH} ${APT_CMD} update
chroot ${ROOTFS_PATH} ${APT_CMD} -y upgrade

echo ${IMAGE_PACKAGE_LIST}

chroot ${ROOTFS_PATH} ${APT_CMD} -y install ${IMAGE_PACKAGE_LIST} 2>&1 
if  [ $? -ne 0 ]; then
    
    umount_dev_sys_proc "${ROOTFS_PATH}"
    exit 1
fi

if [ ${INSTALL_NEXUS_PKG} = "YES" ]; then
    chroot ${ROOTFS_PATH} ${APT_CMD} -y install ${NEXUS_PACKAGES}
fi
chroot ${ROOTFS_PATH} ${APT_CMD} -y clean

# ===============================================
# INSTALL POLAR PACKAGES
# ===============================================
step_log "### Install local packages to the rootfs ###"
if [ "${IMAGE_TYPE}" != "installation" ]; then

    #################### Pull Debian packages from Nexus #######################
    if [ ${PULL_PACKAGES} = "YES" ]; then
	    $PULL_PKG_SCRIPT || echo "Failed to pull packages!"
    fi

    #################### Qt 5.15.0 by Stephan Binner ###########################
    if [ ${INSTALL_QT5} = "YES" ]; then
        step_log "### Install Qt 5.15.0 by Stephan Binner ###"
        wget -O ${ROOTFS_PATH}/tmp/qt_5-15-15_amd64.deb http://nexus-repository.polar-mohr-cloud.com:8081/repository/polar-general/pool/q/qt/qt_5-15-15_amd64.deb
        chroot "${ROOTFS_PATH}" dpkg -i /tmp/qt_5-15-15_amd64.deb
        chroot "${ROOTFS_PATH}" rm /tmp/qt_5-15-15_amd64.deb
  
    fi
    #################### Install Site Manager ###########################
    if [ ${INSTALL_SITE_MANAGER} = "YES" ]; then
        step_log "### Install Site Manager ###"
        wget -O ${ROOTFS_PATH}/tmp/site_manager.deb http://nexus-repository.polar-mohr-cloud.com:8081/repository/polar-general/pool/s/sitemanager/sitemanager_1.0.0_amd64.deb
        chroot "${ROOTFS_PATH}" dpkg -i /tmp/site_manager.deb
        chroot "${ROOTFS_PATH}" rm /tmp/site_manager.deb
    fi

    #################### Debian packages ########################################
    mount -o bind "${PKG_DEB_PATH}" "${ROOTFS_PATH}/mnt"
    for DEB_FILE in $(ls -1 ${PKG_DEB_PATH}/*.deb)
    do
        console_log ""
        console_log "-- Install $(basename ${DEB_FILE}) to rootfs ##"
        chroot "${ROOTFS_PATH}" dpkg -i "/mnt/$(basename ${DEB_FILE})"
    done
    umount "${ROOTFS_PATH}/mnt"

    ## Binary files
    find ${PKG_BINARIES_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ${ROOTFS_PATH} \;

    # Polar font
    step_log "### Install Polar truetype font (Arial Unicode) ###"
    install_fonts
fi

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


# ===============================================
# INSTALL KERNAL 
# ===============================================
step_log "### Install Kernel ###"
if ! chroot "${ROOTFS_PATH}" ${APT_CMD} install -y ${KERNEL_PKG}; then
    echo "ERROR: Could not install kernel."
    exit 1
fi


# ===============================================
# LOCALES
# ===============================================
step_log "### Configure locales ###"
chroot ${ROOTFS_PATH} locale-gen de_DE.UTF-8


# ===============================================
# COPY CONFIG FILES TO ROOTFS
# ===============================================
step_log "### Install (pre)config files to rootfs ###"
find ${ROOTFS_CONF_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -r {} ${ROOTFS_PATH} \;

# ===============================================
# reconfigure NetworkFiles
# ===============================================
step_log "### Configuring NetworkManager Files ###"
rm -r ${ROOTFS_PATH}/etc/NetworkManager/system-connections/*
cp ${ROOTFS_CONF_PATH}/etc/NetworkManager/system-connections/${MACHINE}/* ${ROOTFS_PATH}/etc/NetworkManager/system-connections/

# ===============================================
# HOSTNAME
# ===============================================
step_log "Hostname"
echo "${IMAGE_HOSTNAME}" > ${ROOTFS_PATH}/etc/hostname && echo "Hostname was set to ${IMAGE_HOSTNAME}"
sed -i "s/replace-me/${IMAGE_HOSTNAME}/g" ${ROOTFS_PATH}/etc/hosts

# ===============================================
# Keyboard Settings
# ===============================================
sudo sed -i 's/XKBLAYOUT=".*"/XKBLAYOUT="de"/' ${ROOTFS_PATH}/etc/default/keyboard
chroot ${ROOTFS_PATH} loadkeys de
chroot ${ROOTFS_PATH} service keyboard-setup restart

# ===============================================
# IMAGE-TYPE: DEVELOPMENT
# ===============================================
if [ "${IMAGE_TYPE}" != "development" ]; then
    sed -i "s/NODM_ENABLED=false/NODM_ENABLED=true/g" ${ROOTFS_PATH}/etc/default/nodm
    sed -i "s/NODM_USER=root/NODM_USER=${IMAGE_USER}/g" ${ROOTFS_PATH}/etc/default/nodm
    sed -i "s/NODM_X_OPTIONS='-nolisten tcp'/NODM_X_OPTIONS='-nolisten tcp -nocursor'/g" ${ROOTFS_PATH}/etc/default/nodm

    mkdir -p ${ROOTFS_PATH}/home/${IMAGE_USER}/.config/openbox
    install -m 0644 ${ROOTFS_CONF_PATH}/autostart-${MACHINE} ${ROOTFS_PATH}/home/${IMAGE_USER}/.config/openbox/autostart
    chroot "${ROOTFS_PATH}" chown -R ${IMAGE_USER}:${IMAGE_USER} /home/${IMAGE_USER}/.config/

    mkdir -p ${ROOTFS_PATH}/home/${IMAGE_USER}/.vnc/
    chroot "${ROOTFS_PATH}" x11vnc -storepasswd ${VNC_PASSWORD} /home/${IMAGE_USER}/.vnc/passwd
    chroot "${ROOTFS_PATH}" chown -R ${IMAGE_USER}:${IMAGE_USER} /home/${IMAGE_USER}/.vnc/
fi

# ===============================================
# IMAGE-TYPE: PRODUCTION - APP & ISPV
# ===============================================
if [ "${IMAGE_TYPE}" = "production" ]  && [ "${INSTALL_APP_DATA}" = "YES" ]; then
    chroot "${ROOTFS_PATH}" ln -sf /data/ispv_root /ispv_root
    find ${APP_CONF_PATH} -mindepth 1 -maxdepth 1 -type d -exec cp -a {} ${ROOTFS_PATH} \;
fi

# ===============================================
# PERMISSIONS / OWNER
# ===============================================
step_log "### Configure file permissions and owner ###"
for PERMS in $(cat ${PERMISSIONS_CONF})
do
    FILE_NAME=$(echo "${PERMS}" | cut -d, -f1)
    FILE_PERM=$(echo "${PERMS}" | cut -d, -f2)
    FILE_OWNER=$(echo "${PERMS}" | cut -d, -f3)
    chroot "${ROOTFS_PATH}" chown ${FILE_OWNER} ${FILE_NAME}
    chroot "${ROOTFS_PATH}" chmod ${FILE_PERM} ${FILE_NAME}
done

# ===============================================
# NTP / CHRONY
# ===============================================
step_log "### NTP configuration ###"
mv ${ROOTFS_PATH}/etc/ntp.conf ${ROOTFS_PATH}/etc/ntp.conf.standard
install -m 0644 ${ROOTFS_CONF_PATH}/etc/ntp.conf ${ROOTFS_PATH}/etc/
#install -m 0644 ${ROOTFS_CONF_PATH}/etc/chrony.conf ${ROOTFS_PATH}/etc/

# ===============================================
# SUDOERS
# ===============================================

step_log "### Configuring Sudoers ###"
rm -r ${ROOTFS_PATH}/etc/sudoers.d/*
cp ${ROOTFS_CONF_PATH}/etc/sudoers.d/${MACHINE}/* ${ROOTFS_PATH}/etc/sudoers.d/
# show sudeors file on console:
ls -al ${ROOTFS_PATH}/etc/sudoers.d/



# ===============================================
#  REDUCE ROOTFS SIZE
# ===============================================
step_log "Remove man page files"
rm -rv "${ROOTFS_PATH}/usr/share/doc"
rm -rv "${ROOTFS_PATH}/usr/share/doc-base"
rm -rv "${ROOTFS_PATH}/usr/share/man"
rm -rv "${ROOTFS_PATH}/usr/share/man-db"



# ===============================================
#  VERSION FILE
# ===============================================
step_log "Copy version file"
cp -v "$REPO_ROOT/version" "${ROOTFS_PATH}/opt/version"


# ===============================================
# OPTION: ENTER CHROOT
# ===============================================
if [ "${ENTER_CHROOT}" = "YES" ]; then
    step_log "### Enter chroot ###"
    chroot "${ROOTFS_PATH}" /bin/bash
fi

# ===============================================
# IMAGE-TARGET: DEV / LOOP
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "dev" ] || [ "${IMAGE_TARGET_TYPE}" = "loop" ]; then
    step_log "### Install fstab ###"
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
    step_log "### Install grub bootloader ###"
    chmod -x "${ROOTFS_PATH}/etc/grub.d/30_os-prober"
    chroot "${ROOTFS_PATH}" grub-install --force ${IMAGE_TARGET}
    chroot "${ROOTFS_PATH}" update-grub
    ls -al ${ROOTFS_PATH}/boot
fi

# ===============================================
# ROOTFS DONE - SYNC
# ===============================================
rm -f ${POLICY_RC_D_FILE}
sync

## done with rootfs
## unmount virt fs
umount_dev_sys_proc "${ROOTFS_PATH}"


# ===============================================
# TARBALL / INSTALLER
# ===============================================
if [ "${IMAGE_TARGET_TYPE}" = "tarball" ] || [ "${IMAGE_TARGET_TYPE}" = "installer" ]; then
    step_log "### Create rootfs tarball ###"
    pushd "${ROOTFS_PATH}" &> /dev/null
    tar -cjf ${ROOTFS_TARBALL} * || exit 1
    chgrp $SUDO_GID "${ROOTFS_TARBALL}"
    chown $SUDO_USER "${ROOTFS_TARBALL}"
    popd &> /dev/null

    # NOTE: important step
    if [ "${IMAGE_TARGET_TYPE}" = "installer" ] || [ "${IMAGE_TYPE}" = "installation" ]; then
        step_log "### Create installer/installation ###"
        # Create binary installer with install script and rootfs tarball
        cat "${INSTALLER_SCRIPT}" "${ROOTFS_TARBALL}" > "${INSTALLER_BINARY}"

        # Change permissions and make it executeable
        chmod +x "${INSTALLER_BINARY}"
        chgrp $SUDO_GID "${INSTALLER_BINARY}"
        chown $SUDO_USER "${INSTALLER_BINARY}"

        # Create symlink
        echo "Create symlink from ${INSTALLER_BINARY} to ${INSTALLER_SYMLINK}"
        [ -L ${INSTALLER_SYMLINK} ] && sudo unlink "${INSTALLER_SYMLINK}" && echo "Old symlink was removed!"
        sudo ln -sf "${INSTALLER_BINARY}" "${INSTALLER_SYMLINK}" || sudo -u $SUDO_USER ln -sf "${INSTALLER_BINARY}" "${INSTALLER_SYMLINK}" || echo "ERROR: Failed to create symlink!"
    fi
fi

# ===============================================
# IMAGE-TYPE: INSTALLATION (LIVE-CD)
# ===============================================
if [ "${IMAGE_TYPE}" = "installation" ]; then
    LATEST_INSTALLER_BINARY="$(readlink -f "${TMP_PATH}/${IMAGE_TYPE}-image-installer_latest.bin")"
    if [ -e "${LATEST_INSTALLER_BINARY}" ]; then
        cp -v "${LATEST_INSTALLER_BINARY}" "${ROOTFS_PATH}/home/${IMAGE_USER}/"
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
if [ "${IMAGE_TARGET_TYPE}" = "dev" ] || [ "${IMAGE_TARGET_TYPE}" = "loop" ]; then
    losetup -D
    umount "${DATAFS_PATH}"
    umount "${ROOTFS_PATH}"
fi

step_log "### DONE! ###"

