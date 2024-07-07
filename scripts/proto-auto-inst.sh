#!/bin/bash

# Image und Skript Variablen
readonly REPO_ROOT=$(git rev-parse --show-toplevel) 
readonly TMP_PATH="${REPO_ROOT}/tmp"

readonly TARGET_DIR="$TMP_PATH/live-rootfs"
readonly ISO_NAME="$TMP_PATH/polar-live.iso"
readonly BINARY_FILE="$TMP_PATH/production-installer.bin"
readonly SCRIPT_FILE="auto-install.sh"
readonly SERVICE_NAME="auto-install.service"
readonly VMLINUZ="vmlinuz-6.9.3-76060903-generic"
readonly INITRD="initrd.img-6.9.3-76060903-generic"

# Überprüfen, ob root-Rechte vorhanden sind
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Installieren der benötigten Pakete
apt-get update
apt-get install -y debootstrap grub-pc-bin grub-efi-amd64-bin mtools xorriso

# Erstellen des Zielverzeichnisses
mkdir -p $TARGET_DIR

# Bootstrap des minimalen Ubuntu-Systems
debootstrap --arch=amd64 jammy $TARGET_DIR http://archive.ubuntu.com/ubuntu/

# Einbinden der erforderlichen Dateisysteme
mount --bind /dev $TARGET_DIR/dev
mount --bind /proc $TARGET_DIR/proc
mount --bind /sys $TARGET_DIR/sys

# Konfiguration des Root-Dateisystems
chroot $TARGET_DIR /bin/bash <<EOF
apt-get update
apt-get install -y systemd-sysv

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

# Kopieren der Binärdatei in das Root-Dateisystem
cp -v $BINARY_FILE $TARGET_DIR/root/

# Aufräumen
umount $TARGET_DIR/dev
umount $TARGET_DIR/proc
umount $TARGET_DIR/sys

# Erstellen des ISO-Abbilds
mkdir -p $TMP_PATH/iso/boot/grub
echo "Copy kernel ..."
#cp -v $TARGET_DIR/boot/vmlinuz-* $TMP_PATH/iso/boot/vmlinuz
cp -v /boot/$VMLINUZ $TMP_PATH/iso/boot/vmlinuz
echo "Copy Initrd ..."
#cp -v $TARGET_DIR/boot/initrd.img-* $TMP_PATH/iso/boot/initrd
cp -v /boot/$INITRD $TMP_PATH/iso/boot/initrd.img

cat <<EOF > $TMP_PATH/iso/boot/grub/grub.cfg
set default=0
set timeout=5

menuentry "Install Ubuntu" {
    linux /boot/vmlinuz root=/dev/sr0
    initrd /boot/initrd
}
EOF

grub-mkrescue -o $ISO_NAME $TMP_PATH/iso

echo "ISO image $ISO_NAME created successfully."

