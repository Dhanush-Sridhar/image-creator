#!/bin/bash
# reusable Helper function in every scripts
#
# Created on := 20.02.2023

# specify the source for configuration file
#source ConfigurationFiles/00_configuration-file.txt 

#Recive  messsages and write to the  log file
function log() {
    echo $1
    #echo $1 - `date`>> log.txt
}

#error handling recive error messsages and write to the error log file
function errLog() {
    echo "Error: $1"
    #echo $1 - `date` >> Errlog.txt
    # echo "image creation was terminated due to an error! do you want to unmount the partitions?"
    # echo "[y or n]"
    # read answer
    # if [[ $answer == *[yY]* ]]; then 
    #BashScripts/05_cleanup.sh
    #fi

    exit 1
}

STEPCOUNTER=1
function logstep()
{
    echo
    echo "=========================================="
    echo " STEP $STEPCOUNTER: $1"
    echo "=========================================="
    STEPCOUNTER=$((STEPCOUNTER+1))
}

#Check if root user
function checkRoot(){
if [ $UID != 0 ]; then 
 echo "Not a root user!"
 #echo "Not a root user! - `date` ">> Errlog.txt
 exit 1
fi
}

# mount virtual filesystems
function mount_dev_sys_proc() 
{
    log "Mount dev, proc, sys to rootfs"
    local _ROOTFS_PATH="$1"
    [ -e "${_ROOTFS_PATH}" ] || errlog "Path ${_ROOTFS_PATH} not found!"
    mount -o bind /dev "${_ROOTFS_PATH}/dev"
    mount -o bind /dev/pts "${_ROOTFS_PATH}/dev/pts"
    mount -o bind /sys "${_ROOTFS_PATH}/sys"
    mount -t proc /proc "${_ROOTFS_PATH}/proc"
}

# unmount virtual filesystems
function umount_dev_sys_proc() 
{
    local _ROOTFS_PATH="$1"
    log "Unmount dev, proc, sys from rootfs"
    [ -e "${_ROOTFS_PATH}" ] || errlog "Path ${_ROOTFS_PATH} not found!"
    umount "${_ROOTFS_PATH}/dev/pts"
    umount "${_ROOTFS_PATH}/dev"
    umount "${_ROOTFS_PATH}/sys"
    umount "${_ROOTFS_PATH}/proc"
}