#!/bin/bash

# Script to create, format, and partition an image file
# Created on: 20.02.2023

# Load configuration and helper functions
REPO_ROOT=$(git rev-parse --show-toplevel) 

# Load configuration and helper functions
source $REPO_ROOT/config/usb-img.conf
source $REPO_ROOT/scripts/helpers.sh

# Check if the script is running as root
checkRoot

# Check if the output directory exists, if not, create it
if [ ! -d "$TMP_DIR" ]; then
  mkdir "$TMP_DIR"
fi

# Get current date and time for the image file name
DATE_TIME=$(date +%d%m%y_%H%M%S)

# Define the image file name with date and time
IMAGE_FILE="${TMP_DIR}/${IMAGE_FILE_NAME}_${DATE_TIME}.img"

# Log the steps and configuration parameters
logstep "CREATE IMG - FORMAT & PARTITIONING"
log "Creating Image File with the following parameters"
log "IMAGE_FILE: $IMAGE_FILE"
log "BOOT_PARTITION_SIZE: $BOOT_PARTITION_SIZE"
log "ROOT_PARTITION_SIZE: $ROOT_PARTITION_SIZE"
log "DATA_PARTITION_SIZE: $DATA_PARTITION_SIZE"
log "BOOT_PARTITION_TYPE: $BOOT_PARTITION_TYPE"
log "ROOT_PARTITION_TYPE: $ROOT_PARTITION_TYPE"
log "DATA_PARTITION_TYPE: $DATA_PARTITION_TYPE"
log "BOOT_PARTITION_LABEL: $BOOT_PARTITION_LABEL"
log "ROOT_PARTITION_LABEL: $ROOT_PARTITION_LABEL"
log "DATA_PARTITION_LABEL: $DATA_PARTITION_LABEL"

# Deactivate automount service if it is active
if systemctl is-active --quiet udisk2.service; then
  log "Temporarily Deactivating udisk2 service"
  systemctl stop udisk2.service
fi

# Calculate the total image size
BYTE=1024
MB=$((BYTE * 1024))
GB=$((MB * 1024))

TOTAL_SIZE=$(echo "$BOOT_PARTITION_SIZE*$MB + $ROOT_PARTITION_SIZE*$GB + $DATA_PARTITION_SIZE*$GB" | bc)
log "Total image size: $TOTAL_SIZE"

# Calculate dd count for creating the image file
DD_COUNT=$(echo "$BOOT_PARTITION_SIZE + $ROOT_PARTITION_SIZE * $BYTE + $DATA_PARTITION_SIZE * $BYTE" | bc)
log "DD count: $DD_COUNT"

# Create the image file with dd
dd if=/dev/zero of="$IMAGE_FILE" bs=1M count="$DD_COUNT"
if [ $? -ne 0 ]; then
  errLog "Error in dd"
  exit 1
fi

# Create a loop device for the image file
LOOP_DEVICE=$(losetup -Pf --show "$IMAGE_FILE") && log "Loop device created: $LOOP_DEVICE" || { errLog "Error in creating loop device"; exit 1; }

# Create a symbolic link for easy access
mkdir -p "$LOOP_DEVICE_NAME"
ln -s "$LOOP_DEVICE" "$LOOP_DEVICE_NAME"

# Partition the image file
{
  echo o  # Create a new empty DOS partition table
  echo n  # Add a new partition
  echo p  # Primary partition
  echo 1  # Partition number
  echo    # First sector (default)
  echo +${BOOT_PARTITION_SIZE}M  # Last sector
  echo t  # Change partition type
  echo $BOOT_PARTITION_TYPE  # Partition type
  echo n  # Add a new partition
  echo p  # Primary partition
  echo 2  # Partition number
  echo    # First sector (default)
  echo +${ROOT_PARTITION_SIZE}G  # Last sector
  echo t  # Change partition type
  echo 2  # Partition number
  echo $ROOT_PARTITION_TYPE  # Partition type
  echo n  # Add a new partition
  echo p  # Primary partition
  echo 3  # Partition number
  echo    # First sector (default)
  echo    # Last sector (default, use remaining space)
  echo t  # Change partition type
  echo 3  # Partition number
  echo $DATA_PARTITION_TYPE  # Partition type
  echo w  # Write changes
} | fdisk "$LOOP_DEVICE" && log "Partitioned $LOOP_DEVICE" || { errLog "Error in partitioning $LOOP_DEVICE"; exit 1; }

# Create filesystems on the partitions
mkfs.vfat -n "$BOOT_PARTITION_LABEL" ${LOOP_DEVICE}p1 && log "Formatted $BOOT_PARTITION_LABEL" || errLog "Error in formatting $BOOT_PARTITION_LABEL"
mkfs.ext4 -L "$ROOT_PARTITION_LABEL" ${LOOP_DEVICE}p2 && log "Formatted $ROOT_PARTITION_LABEL" || errLog "Error in formatting $ROOT_PARTITION_LABEL"
mkfs.ext4 -L "$DATA_PARTITION_LABEL" ${LOOP_DEVICE}p3 && log "Formatted $DATA_PARTITION_LABEL" || errLog "Error in formatting $DATA_PARTITION_LABEL"

# Clean partition mount points if they exist
rm -rf /mnt/$BOOT_PARTITION_LABEL /mnt/$ROOT_PARTITION_LABEL /mnt/$DATA_PARTITION_LABEL

# Create mount points for the partitions
mkdir -p /mnt/$BOOT_PARTITION_LABEL && log "Created directory: /mnt/$BOOT_PARTITION_LABEL" || errLog "Error in creating directory: /mnt/$BOOT_PARTITION_LABEL"
mkdir -p /mnt/$ROOT_PARTITION_LABEL && log "Created directory: /mnt/$ROOT_PARTITION_LABEL" || errLog "Error in creating directory: /mnt/$ROOT_PARTITION_LABEL"
mkdir -p /mnt/$DATA_PARTITION_LABEL && log "Created directory: /mnt/$DATA_PARTITION_LABEL" || errLog "Error in creating directory: /mnt/$DATA_PARTITION_LABEL"

# Mount the partitions
mount ${LOOP_DEVICE}p1 /mnt/$BOOT_PARTITION_LABEL && log "Mounted: /mnt/$BOOT_PARTITION_LABEL" || errLog "Error in mounting: /mnt/$BOOT_PARTITION_LABEL"
mount ${LOOP_DEVICE}p2 /mnt/$ROOT_PARTITION_LABEL && log "Mounted: /mnt/$ROOT_PARTITION_LABEL" || errLog "Error in mounting: /mnt/$ROOT_PARTITION_LABEL"
mount ${LOOP_DEVICE}p3 /mnt/$DATA_PARTITION_LABEL && log "Mounted: /mnt/$DATA_PARTITION_LABEL" || errLog "Error in mounting: /mnt/$DATA_PARTITION_LABEL"

log "Partitions mounted on /mnt/$BOOT_PARTITION_LABEL, /mnt/$ROOT_PARTITION_LABEL, and /mnt/$DATA_PARTITION_LABEL"

