#!/bin/bash

set -eo pipefail

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
readonly IMAGE_FILE="$TMP_DIR/polar-live-$(date +"%Y%m%d").img"
readonly BOOT_PARTITION_SIZE=20 # in MB
readonly ROOT_PARTITION_KERNEL_SIZE=2304 # in MB
readonly BOOT_MNT=/mnt/boot
readonly ROOT_MNT="$TMP_DIR/mnt"
LOOP_DEV_NAME="$TMP_DIR/loop_dev"


readonly BINARY_FILE="$TMP_DIR/production-image-installer_latest.bin"

#readonly SCRIPT_FILE="auto-install.sh"
#readonly SERVICE_NAME="auto-install.service"

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


function mount_virtual_fs(){
    # Mount virtual filesystems
    mount --bind /dev $1/dev
    mount --bind /proc $1/proc
    mount --bind /sys $1/sys
}

function umount_virtual_fs(){
    # Unmount virtual filesystems
    ! mountpoint -q $1/dev || umount $1/dev
    ! mountpoint -q $1/proc || umount $1/proc
    ! mountpoint -q $1/sys || umount $1/sys
}

function create_rootfs(){

    mkdir -p $ROOTFS_LIVE_DIR

    debootstrap --variant=minbase --arch=$ARCH $DISTRO $ROOTFS_LIVE_DIR $REPO

    # Mount virtual filesystems
    mount --bind /dev $ROOTFS_LIVE_DIR/dev
    mount --bind /proc $ROOTFS_LIVE_DIR/proc
    mount --bind /sys $ROOTFS_LIVE_DIR/sys

    mount_virtual_fs $ROOTFS_LIVE_DIR

# Configure rootfs
chroot $ROOTFS_LIVE_DIR /bin/bash <<EOF

apt-get update
apt-get install -y systemd-sysv gdisk dosfstools pciutils passwd usbutils e2fsprogs vim coreutils
#apt-get --no-install-recommends install busybox linux-image-amd64 systemd-sysv pciutils usbutils passwd
EOF

## Auto-Login
chroot $ROOTFS_LIVE_DIR /bin/bash <<EOF
mkdir - /etc/systemd/system/getty@tty1.service.d
cat <<EOT > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin root %I $TERM
EOT
EOF

## Auto Install Service
chroot $ROOTFS_LIVE_DIR /bin/bash <<EOF
cat <<EOT > /etc/systemd/system/auto-install.service
[Unit]
Description=Run auto-install script

[Service]
ExecStart=/root/production-image-installer_latest.bin
Type=oneshot

[Install]
WantedBy=multi-user.target
EOT

chmod 0644 /etc/systemd/system/auto-install.service
EOF


# Copy binary installer into rootfs
    cp -v $BINARY_FILE $ROOTFS_LIVE_DIR/root/

# Unmount virtual filesystems
    umount_virtual_fs $ROOTFS_LIVE_DIR
}

function create_img(){

    #check if rootfs exists
    if [ ! -d $ROOTFS_LIVE_DIR ]; then
        echo "ERROR: RootFS does not exists. Run --rootfs first."
        exit 1
    fi
    # just in case if not unmounted in previous run
    umount_virtual_fs $ROOTFS_LIVE_DIR

    #get the size of the rootfs directory
    ROOT_PARTITION_SIZE=$(du -s $ROOTFS_LIVE_DIR | awk '{print $1}')

    echo "Rootfs size: $ROOT_PARTITION_SIZE"
    #Totalt size of the image file
    readonly KBYTE=1024
    
    # calculate the size of the image file
    DD_Count=$(echo "$ROOT_PARTITION_SIZE+($ROOT_PARTITION_KERNEL_SIZE*$KBYTE)" | bc)

    # convert the size to human readable format just for display
    Image_Size=$((echo "$DD_Count*$KBYTE" | bc) | numfmt --to=si)

    echo "Total size of the image file: $Image_Size"
    echo "Creating image file $IMAGE_FILE of size $Image_Size"

    # create the image file
    dd if=/dev/zero of=$IMAGE_FILE bs=1K count=$DD_Count

    if [ $? -ne 0 ]; then
        echo "ERROR: Could not create image."
        exit 1
    fi


    # create a MBR partition table
    parted -s $IMAGE_FILE mklabel msdos
    parted -s $IMAGE_FILE mkpart primary ext4 1MiB 100%

    # attach the image file to a loop device
    LOOP_DEV=$(losetup -fP --show $IMAGE_FILE)

    # create persitant loop device for further use
    mkdir -p $LOOP_DEV_NAME
    ln -s $LOOP_DEV $LOOP_DEV_NAME


    # Create the file system
    mkfs.ext4 ${LOOP_DEV}p1 && echo "Rootfs partition created" || echo "Could not create rootfs partition."



    # Mount the image file
    if [ -d $ROOT_MNT ]; then
        rm -rf $ROOT_MNT
    fi

    # create rootfs mount directory
    mkdir -p $ROOT_MNT
    # mount rootfs partition
    mount ${LOOP_DEV}p1 $ROOT_MNT

    if [ $? -ne 0 ]; then
        echo "ERROR: Could not mount rootfs partition."
        return  1
    fi

    #create efi boot directory
    mkdir -p $ROOT_MNT/boot/grub

   
    echo "Image file mounted successfully."

    # copy the rootfs to the image file
    cp -a $ROOTFS_LIVE_DIR/* $ROOT_MNT

   #mount dev, proc and sys
    mount_virtual_fs $ROOT_MNT


    # install grub BIOS bootloader
    grub-install --target=i386-pc --boot-directory=$ROOT_MNT/boot --recheck $LOOP_DEV

    if [ $? -ne 0 ]; then
        echo "ERROR: Could not install grub."
        clean_img
        
    else
        echo "Grub installed successfully."
    fi

    # get boot partition UUID
    ROOTFS_UUID=$(blkid -s UUID -o value ${LOOP_DEV}p1)


    # update the grub configuration
cat <<EOF > $ROOT_MNT/boot/grub/grub.cfg
    set default=0
    set timeout=5

    menuentry "Install PolarOS" {
        linux /boot/vmlinuz root=UUID=$ROOTFS_UUID
        initrd /boot/initrd.img

    }
EOF
    
    # configure fstab

cat <<EOF > $ROOT_MNT/etc/fstab
    UUID=$ROOTFS_UUID / ext4 defaults 0 1
   
EOF

    # copy kernel and initrd
    cp -v $VMLINUZ $ROOT_MNT/boot/ && echo "Kernel copied successfully." || echo "Could not copy kernel."
    cp -v $INITRD $ROOT_MNT/boot/ && echo "Initrd copied successfully." || echo "Could not copy initrd."

    echo "Image file created successfully."
}

function clean_img(){

    umount_virtual_fs $ROOT_MNT
    # Unmount the image file
    
    #! mountpoint -q $ROOT_MNT/boot/efi || umount $ROOT_MNT/boot/efi
    ! mountpoint -q $ROOT_MNT || umount $ROOT_MNT

    rm -rf $ROOT_MNT

    # detach the image file from the loop device
    losetup -d "$(readlink -f ${LOOP_DEV_NAME}/*)" && echo "Image file detached from loop device." || echo "Could not detach image file from loop device."

    # remove the loop device
    rm -rf $LOOP_DEV_NAME

    # remove the image file
   # rm -rf $IMAGE_FILE
}

function create_iso(){

    if !exist $ROOTFS; then 
        echo "ERROR: RootFS does not exists. Run --rootfs first." && exit 1
    fi


    # install linux kernel

    
  

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


function clean(){
    ! mountpoint -q $ROOTFS_LIVE_DIR/dev  || umount $ROOTFS_LIVE_DIR/dev
    ! mountpoint -q $ROOTFS_LIVE_DIR/proc || umount $ROOTFS_LIVE_DIR/proc
    ! mountpoint -q $ROOTFS_LIVE_DIR/sys  || umount $ROOTFS_LIVE_DIR/sys

    sudo rm -rvf $ROOTFS_LIVE_DIR
}

function test_iso(){
    #qemu-system-x86_64 -enable-kvm -boot menu=on -m 4G -cpu host -smp 2 -curses -cdrom $ISO_NAME
    #qemu-system-x86_64 -boot menu=on -display curses -cdrom $ISO_NAME
    if ! test -f $TMP_DIR/geshem.img; then echo "Test Image does not exists. Create one."; qemu-img create -f qcow virt-geshem.img 10G; fi

    qemu-system-x86_64 -enable-kvm -boot menu=on -m 4G -cpu host -smp 2 -vga virtio -display sdl,gl=on -drive file=virt-geshem.img -cdrom $ISO_NAME_LATEST
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

        --img)
            root_check
            create_img
            clean_img
            exit 0

        ;;

        --clean)
            root_check
            clean_img
            exit 0

        ;;

        --iso)
            root_check
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

        --all)
            root_check
            clean
            create_rootfs
            create_iso
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
