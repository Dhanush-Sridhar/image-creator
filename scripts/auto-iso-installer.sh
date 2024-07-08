#!/bin/bash

set -eo pipefail

### TODO:
# end Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
# https://askubuntu.com/questions/41930/kernel-panic-not-syncing-vfs-unable-to-mount-root-fs-on-unknown-block0-0

# kernel and inird option not working
# 

help()
{
cat << EOM
Build Linux Live ISO for running the binary production installer from USB.

Usage:
  ./build [--options]

Options:
  -h, --help    	  Show this help message.
  --init            Install dependencies on host
  --rootfs           Build rootfs and iso file.
  --mkrootfs        Create root file system.
  --mkiso           Generate the iso.
  --kernel          Path to custom kernel.
  --initrd          Path to custom Initial RamDisk.
  --clean	          Delete rootfs.
  --test            Test the ISO with qemu.
  --all             Build rootfs, iso and run qemu test.


Know issues:
- stop at 'Chosen extractor for .deb packages: ar' - delete rootfs ==> use --clean
- stop with 'tried to extract package, but file already exists. Exit.' ==> use --clean
EOM
}

readonly REPO_ROOT=$(git rev-parse --show-toplevel) 
readonly TMP_DIR="${REPO_ROOT}/tmp"

readonly ROOTFS_LIVE_DIR="$TMP_DIR/live-rootfs"
readonly ISO_NAME="$TMP_DIR/polar-live-$(date +"%Y%m%d").iso"
readonly ISO_NAME_LATEST="$TMP_DIR/polar-live-latest.iso"

readonly BINARY_FILE="$TMP_DIR/production-image-installer_latest.bin"
readonly SCRIPT_FILE="auto-install.sh"
readonly SERVICE_NAME="auto-install.service"

readonly ARCH=amd64
readonly DISTRO=jammy
readonly REPO="http://archive.ubuntu.com/ubuntu/"

#readonly ROOTFS_PACKAGES="busybox linux-image-amd64 systemd-sysv pciutils usbutils passwd exfat-fuse exfat-utils"

VMLINUZ=$TMP_DIR/rootfs/boot/vmlinuz
INITRD=$TMP_DIR/rootfs/boot/initrd.img


function root_check(){
    if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
    fi
}

function get_kernel(){
    echo "Use custom kernel ..."
    VMLINUZ="$2"
}

function get_initrd(){
    echo "Use custom initrd ..."
    INITRD="$2"
}

# Install dependecies on host
function check_host_setup(){

  if [ ! $(command -v mksquashfs) ]; then
  	echo "ERROR: mksquashfs not found. Run --init first! "
  	exit 1
  fi

  if [ ! $(command -v xorriso) ]; then
  	echo "ERROR: xorriso not found! Run --init first!"
  	exit 1
  fi

}

function host_setup(){
  apt-get update
  apt-get install -y debootstrap grub-pc-bin grub-efi-amd64-bin mtools xorriso
}

function create_rootfs(){

    mkdir -p $ROOTFS_LIVE_DIR

    debootstrap --variant=minbase --arch=$ARCH $DISTRO $ROOTFS_LIVE_DIR $REPO

    # Mount virtual filesystems
    mount --bind /dev $ROOTFS_LIVE_DIR/dev
    mount --bind /proc $ROOTFS_LIVE_DIR/proc
    mount --bind /sys $ROOTFS_LIVE_DIR/sys

# Configure rootfs
chroot $ROOTFS_LIVE_DIR /bin/bash <<EOF

apt-get update
apt-get install -y systemd-sysv 
#apt-get --no-install-recommends install busybox linux-image-amd64 systemd-sysv pciutils usbutils passwd

# Erstellen des auto-install.sh Skripts
cat <<EOT > /root/$SCRIPT_FILE
#!/bin/bash
echo "Auto install script executed" > /root/auto-install.log

# Hier weitere Befehle hinzufügen ...
EOT

chmod +x /root/$SCRIPT_FILE

# Erstellen des Systemdienstes
cat <<EOT > /etc/systemd/system/$SERVICE_NAME
[Unit]
Description=Run auto-install script

[Service]
ExecStart=/root/$SCRIPT_FILE
Type=oneshot

[Install]
WantedBy=multi-user.target
EOT

systemctl enable $SERVICE_NAME
EOF

# Auto-Login einrichten
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOT > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin root %I $TERM
EOT

# Copy binary installer into rootfs
cp -v $BINARY_FILE $ROOTFS_LIVE_DIR/root/

# Unmount virtual filesystems
    ! mountpoint -q $ROOTFS_LIVE_DIR/dev || umount $ROOTFS_LIVE_DIR/dev
    ! mountpoint -q $ROOTFS_LIVE_DIR/proc || umount $ROOTFS_LIVE_DIR/proc
    ! mountpoint -q $ROOTFS_LIVE_DIR/sys || umount $ROOTFS_LIVE_DIR/sys
}

function create_iso(){

    if !exist $ROOTFS; then 
        echo "ERROR: RootFS does not exists. Run --rootfs first." && exit 1
    fi

    mkdir -p $ROOTFS_LIVE_DIR/boot/grub

    echo "Copy kernel ..." && cp -v $VMLINUZ $ROOTFS_LIVE_DIR/boot/vmlinuz
    #cp -v $ROOTFS_LIVE_DIR/boot/vmlinuz-* $TMP_DIR/iso/boot/vmlinuz

    echo "Copy Initrd ..." && cp -v $INITRD $ROOTFS_LIVE_DIR/boot/initrd
    #cp -v $ROOTFS_LIVE_DIR/boot/initrd.img-* $TMP_DIR/iso/boot/initrd

cat <<EOF > $ROOTFS_LIVE_DIR/boot/grub/grub.cfg
set default=0
set timeout=5

menuentry "Install PolarOS" {
    linux /boot/vmlinuz root=/dev/sr0
    initrd /boot/initrd
}
EOF

grub-mkrescue -o $ISO_NAME $ROOTFS_LIVE_DIR && echo "ISO image $ISO_NAME created successfully." && ln -sf $ISO_NAME $ISO_NAME_LATEST
}

function make_iso(){
  echo "NEW TEST";
}

function clean(){
    ! mountpoint -q $ROOTFS_LIVE_DIR/dev  || umount $ROOTFS_LIVE_DIR/dev
    ! mountpoint -q $ROOTFS_LIVE_DIR/proc || umount $ROOTFS_LIVE_DIR/proc
    ! mountpoint -q $ROOTFS_LIVE_DIR/sys  || umount $ROOTFS_LIVE_DIR/sys

    sudo rm -rvf $ROOTFS_LIVE_DIR
}

function test_iso(){
    #qemu-system-x86_64 -enable-kvm -boot menu=on -m 4G -cpu host -smp 2 -curses -cdrom $ISO_NAME
    #qemu-system-x86_64 -boot menu=on -display curses -cdrom $ISO_NAME
    qemu-system-x86_64 -enable-kvm -boot menu=on -m 4G -cpu host -smp 2 -vga virtio -display sdl,gl=on -cdrom $ISO_NAME_LATEST
}


while [[ $# -gt 0 ]]; do
    argument="$1"

    case $argument in
        -h | --help)
            help
            exit 0
        ;;

        --init)
            root_check
            host_setup
            shift
        ;;

        --kernel)
            get_kernel
            shift
        ;;

        --initrd)
            get_initrd
            shift
        ;;

        --rootfs)
            root_check
            create_rootfs
    
            shift
        ;;

        --iso)
            create_iso
            shift
        ;;

        --clean)
            root_check
            clean
            shift
        ;;

        --test)
            test_iso
            shift
        ;;

        *)
			echo -e "ERROR: Invalid option: $1 \n"
            help
            break
        ;;
    esac
done
