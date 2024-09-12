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


function step_log() {
    echo
    echo "======================================="
    echo "$1"
    echo "======================================="
}
#Check if root user
function checkRoot(){
if [ $UID != 0 ]; then 
 echo "Not a root user!"
 #echo "Not a root user! - `date` ">> Errlog.txt
 exit 1
fi
}

function breakPoint(){
    echo "at $1"
    echo "Press any key to continue..."
    read -n 1 -s
}

###
# Mount/unmount virtual filesystems
# usage: mount_virtfs $ROOTFS_PATH
###
function mount_virtfs(){
    ! mountpoint -q $1/dev     && mount --bind /dev     $1/dev
    ! mountpoint -q $1/dev/pts && mount --bind /dev/pts $1/dev/pts
    ! mountpoint -q $1/sys     && mount --bind /sys     $1/sys
    ! mountpoint -q $1/proc    && mount -t proc /proc   $1/proc
}

function unmount_virtfs() {
    ! mountpoint -q $1/dev/pts || umount $1/dev/pts
    ! mountpoint -q $1/dev     || umount $1/dev
    ! mountpoint -q $1/sys     || umount $1/sys
    ! mountpoint -q $1/proc    || umount $1/proc
}