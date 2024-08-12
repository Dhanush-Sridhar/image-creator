#!/bin/bash

set -eo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel) 

echo "Load configuration ..."
BUILD_CONFIG=$REPO_ROOT/config/build.conf
source $BUILD_CONFIG && echo "$BUILD_CONFIG was sourced!" || echo "Failed to source config: $BUILD_CONFIG"
HELPER_FUNCTIONS=$REPO_ROOT/scripts/helpers.sh
source $HELPER_FUNCTIONS && echo "$HELPER_FUNCTIONS was sourced!" || echo "Failed to source config: $BUILD_CONFIG"

readonly LIVE_SYS_DISTRO="jammy"
readonly TMP_DIR="${REPO_ROOT}/tmp"
readonly ROOTFS_IMAGE_CREATOR_DIR="$TMP_DIR/rootfs"
readonly ROOTFS_LIVE_DIR="$TMP_DIR/live-rootfs"
readonly ISO_NAME="$TMP_DIR/polar-live-$(date +"%Y%m%d").iso"
readonly ISO_NAME_LATEST="$TMP_DIR/polar-live-latest.iso"
readonly IMAGE_FILE="$TMP_DIR/polar-live-$(date +"%Y%m%d").img"
readonly IMAGE_FILE_LATEST_SYMLINK="$TMP_DIR/polar-live-latest.img"
readonly BOOT_PARTITION_SIZE=20 # in MB
readonly ROOT_PARTITION_KERNEL_SIZE=2600 # in MB (vmlinuz + initrd.img)
readonly BOOT_MNT=/mnt/boot
readonly ROOT_MNT="$TMP_DIR/mnt"
LOOP_DEV_NAME="$TMP_DIR/loop_dev"

BINARY_INSTALLER=$TMP_DIR/production-image-installer-latest.bin

readonly ARCH=amd64
#readonly DISTRO=jammy
readonly REPO="http://archive.ubuntu.com/ubuntu/"
#readonly PACKAGES="busybox linux-image-amd64 systemd-sysv pciutils usbutils passwd exfat-fuse exfat-utils"
readonly PACKAGES="systemd-sysv gdisk dosfstools pciutils passwd usbutils e2fsprogs vim coreutils bzip2 parted locales fbset whiptail"

readonly  STARTUP_SCRIPT_SOURCE=$REPO_ROOT/scripts/tui/tui_main_menu.sh
readonly  STARTUP_SCRIPT=tui_main_menu.sh

readonly INSTALLER_SOURCE=$REPO_ROOT/scripts/installer/production-image-installer-latest.bin
readonly INSTALLER_BIN=production-image-installer-latest.bin


VMLINUZ=$ROOTFS_IMAGE_CREATOR_DIR/boot/vmlinuz
INITRD=$ROOTFS_IMAGE_CREATOR_DIR/boot/initrd.img


help()
{
cat << EOM
Build Polar Live OS for flashing Box-PC's with SSD drive from USB.

Usage:
  ./build [--options]

Options:
  -h, --help        Show this help message.
  --init            Install dependencies on host
  --rootfs          Build rootfs and iso file.
  --mkrootfs        Create root file system.
  --mkiso           Generate the iso.
  --kernel          Path to custom kernel.
  --initrd          Path to custom initial ram disk.
  --clean	        Delete rootfs.
  -c | --compress   Compress Image  # TODO: choose with option: gzip, xz, zip
  --test-iso        Test the ISO with qemu.
  --test-img        Test the IMG with qemu.
  --all-img         Build rootfs, iso and run qemu test.

Know issues:
- stop at 'Chosen extractor for .deb packages: ar' - delete rootfs ==> use --clean
- stop with 'tried to extract package, but file already exists. Exit.' ==> use --clean
EOM
}

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
  apt update
  apt install -y debootstrap grub-pc-bin grub-efi-amd64-bin mtools xorriso 
  apt install ovmf # for Q-EMU EFI Boot
}


# =======================
# ROOTFS
# =======================

function create_rootfs(){

    mkdir -p $ROOTFS_LIVE_DIR

    debootstrap --variant=minbase --arch=$ARCH $LIVE_SYS_DISTRO $ROOTFS_LIVE_DIR $REPO
    mount_virtfs $ROOTFS_LIVE_DIR

    # Configure rootfs
    chroot $ROOTFS_LIVE_DIR apt update
    chroot $ROOTFS_LIVE_DIR apt install -y --no-install-recommends $PACKAGES


## Auto-Login
chroot $ROOTFS_LIVE_DIR /bin/bash <<EOF
mkdir - /etc/systemd/system/getty@tty1.service.d
cat <<EOT > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin root %I $TERM
EOT
EOF

## Start TUI Menu on Login
echo ./$STARTUP_SCRIPT -i $INSTALLER_BIN >>  $ROOTFS_LIVE_DIR/root/.bashrc


## Auto-Login
chroot $ROOTFS_LIVE_DIR /bin/bash <<EOF
cat <<EOT > /etc/vconsole.conf
KEYMAP=de
EOT
EOF

    # copy TUI scripts to opt
    if [ ! -e $STARTUP_SCRIPT_SOURCE ] ; then
        echo "TUI scripts $STARTUP_SCRIPT_SOURCE not found!"
        return 1
    fi

    cp -v $STARTUP_SCRIPT_SOURCE $ROOTFS_LIVE_DIR/root/ || echo "Failed to copy TUI scripts to image"

    # Copy binary installer into rootfs
    if [ ! -e $BINARY_INSTALLER ] ; then
        echo "Binary Installer $BINARY_INSTALLER symlink not found!"
    else
        cp -v $BINARY_INSTALLER $ROOTFS_LIVE_DIR/root/ || echo "Failed to copy binary installer to image"
    fi
    
    echo "Root FS was build successfully in $ROOTFS_LIVE_DIR."
}


# =======================
# IMAGE
# =======================
function create_img(){

    echo "Create Polar Live OS Image ..."

    #check if rootfs exists
    if [ ! -d $ROOTFS_LIVE_DIR ]; then
        echo "ERROR: RootFS does not exists. Run --rootfs first."
        exit 1
    fi
    # just in case if not unmounted in previous run
    unmount_virtfs $ROOTFS_LIVE_DIR

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
    mount_virtfs $ROOT_MNT

    #Install Kernal 
    if ! chroot $ROOT_MNT apt install -y linux-image-generic; then
        echo "ERROR: Could not install kernel."
       clean_img
       exit 1
    fi

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
    set timeout=0

    menuentry "Install PolarOS" {
        linux /boot/vmlinuz root=UUID=$ROOTFS_UUID
        initrd /boot/initrd.img

    }
EOF
    
    # configure fstab

cat <<EOF > $ROOT_MNT/etc/fstab
    UUID=$ROOTFS_UUID / ext4 defaults 0 1
   
EOF


    echo "Create symlink to latest image build for easy automation!"
    chown 1000:1000 $IMAGE_FILE 
    ln -sf $IMAGE_FILE $IMAGE_FILE_LATEST_SYMLINK

    echo "Image file created successfully."
}



# =======================
# MAKE ISO (READ-ONLY)
# =======================
function create_iso(){

    if !exist $ROOTFS; then 
        echo "ERROR: RootFS does not exists. Run --rootfs first." && exit 1
    fi

cat <<EOF > $ROOTFS_LIVE_DIR/boot/grub/grub.cfg
    set default=0
    set timeout=0

    menuentry "Install PolarOS" {
        linux /boot/vmlinuz root=/dev/sr0
        initrd /boot/initrd
}
EOF

    grub-mkrescue -o $ISO_NAME $ROOTFS_LIVE_DIR && echo "ISO image $ISO_NAME created successfully." && ln -sf $ISO_NAME $ISO_NAME_LATEST
}

function compress_img(){

    # compression with multi-threading
    xz -vT3 $(readlink $IMAGE_FILE_LATEST_SYMLINK)
}


# =======================
# CLEAN FUNCTIONS
# =======================

function clean_rootfs(){
        sudo rm -rvf $ROOTFS_LIVE_DIR
}

function clean_img(){

    unmount_virtfs $ROOT_MNT
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

# =======================
# Q-EMU TEST FUNCTIONS 
# =======================
function test_iso(){
    #qemu-system-x86_64 -enable-kvm -boot menu=on -m 4G -cpu host -smp 2 -curses -cdrom $ISO_NAME
    #qemu-system-x86_64 -boot menu=on -display curses -cdrom $ISO_NAME
    if ! test -f $TMP_DIR/geshem.img; then echo "Test Image does not exists. Create one."; qemu-img create -f qcow virt-geshem.img 10G; fi
    qemu-system-x86_64 -enable-kvm -boot menu=on -m 4G -cpu host -smp 2 -vga virtio -display sdl,gl=on -drive file=virt-geshem.img -cdrom $ISO_NAME_LATEST
}

function test_img(){
    if ! test -f $IMAGE_FILE_LATEST_SYMLINK; then echo "No Image file found! Create image first with --img."; exit 1; fi
    #UEFI:qemu-system-x86_64 -enable-kvm -boot menu=on -bios /usr/share/ovmf/OVMF.fd -m 4G -cpu host -smp 2 -vga virtio -display sdl,gl=on -drive format=raw,file=$IMAGE_FILE_LATEST_SYMLINK
    qemu-system-x86_64  -boot menu=on -m 4G  -smp 2 -vga virtio -display sdl,gl=on -drive format=raw,file=$IMAGE_FILE_LATEST_SYMLINK
}

# =======================
# MAIN CLI
# =======================
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

        --bin)
            BINARY_INSTALLER=$1
            shift
        ;;

        --rootfs)
            root_check
            create_rootfs
            unmount_virtfs $ROOTFS_LIVE_DIR
            shift
        ;;

        --img)
            root_check
            create_img
            clean_img
            exit 0

        ;;

        --iso)
            root_check
            create_iso
            shift
        ;;

        --clean-rootfs)
            root_check
            unmount_virtfs $ROOTFS_LIVE_DIR
            clean_rootfs
            exit 0
        ;;

        --clean-img)
            root_check
            unmount_virtfs $ROOT_MNT
            clean_img
            exit 0
        ;;

        -c|--compress)
            compress_img # TODO: choose with option: gzip, xz, zip
            exit 0
        ;;


        --test-img)
            test_img
            shift
        ;;

        --all-img)
            root_check
            unmount_virtfs $ROOTFS_LIVE_DIR
            clean_rootfs
            create_rootfs
            unmount_virtfs $ROOTFS_LIVE_DIR
            create_img
            clean_img
            test_img
            shift
        ;;

        --all-iso)
            root_check
            clean
            create_rootfs
            unmount_virtfs $ROOTFS_LIVE_DIR
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
