#!/bin/bash

#set -e  # errexit = exit if a command exits with non zero 
#set -u  # treat undefined vars as erros 
#set -o pipefail

# ===========================
# VARIABLES
# ===========================
SCRIPTDIR="$(dirname $(readlink -f $0))"

# LOGS
TUILOG="${SCRIPTDIR}/tui.log"
ERRORLOG="${SCRIPTDIR}/error.log"

# TUI VARS
BACKTITLE="Polar Image Flasher 1.0"
WIDTH=70

# Options INSTALLER Bin name

INSTALLER_BIN=""

# Parse options
while getopts "i:" opt; do
  case $opt in
    i)
      INSTALLER_BIN="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# ===========================
# FRAMEBUFFER RESOLUTION
# ===========================
# https://man.archlinux.org/man/fbset.8.en
# Otherwise default 640x480 is used
fbset -g 1920 1080 1920 1080 32

# ===========================
# COLORS WHIPTAIL
# ===========================
export STANDARD='
    root=,blue
    checkbox=,blue
    entry=,blue
    label=blue,
    actlistbox=,blue
    helpline=,blue
    roottext=,blue
    emptyscale=blue
    disabledentry=blue,
'

export REDBLUE='
    root=,red
    checkbox=,blue
    entry=,blue
    label=blue,
    actlistbox=,blue
    helpline=,blue
    roottext=,blue
    emptyscale=blue
    disabledentry=blue,
'

# Hint:
### Options
# root = background: blue
#root                  root fg, bg
#border                border fg, bg
#window                window fg, bg
#shadow                shadow fg, bg
#title                 title fg, bg
#button                button fg, bg
#actbutton             active button fg, bg
#checkbox              checkbox fg, bg
#actcheckbox           active checkbox fg, bg
#entry                 entry box fg, bg
#label                 label fg, bg
#listbox               listbox fg, bg
#actlistbox            active listbox fg, bg
#textbox               textbox fg, bg
#acttextbox            active textbox fg, bg
#helpline              help line
#roottext              root text
#emptyscale            scale full
#fullscale             scale empty
#disentry              disabled entry fg, bg
#compactbutton         compact button fg, bg
#actsellistbox         active & sel listbox
#sellistbox            selected listbox

### Colors ###
#color0  or black
#color1  or red
#color2  or green
#color3  or brown
#color4  or blue
#color5  or magenta
#color6  or cyan
#color7  or lightgray
#color8  or gray
#color9  or brightred
#color10 or brightgreen
#color11 or yellow
#color12 or brightblue
#color13 or brightmagenta
#color14 or brightcyan
#color15 or white

# chosen color profile
export NEWT_COLORS=$REDBLUE


# ===========================
# MAIN MENU
# ===========================
MAIN_MENU_TITLE=" Flash Menu"
INFOTEXT=" Welcome to Polar Image Flasher! \n
Please select the desired option from the menu below. \n\n\n"
             

function main()
{
    log "Main menu displayed"
    CHOICE=$(
        whiptail --backtitle "${BACKTITLE}" \
        --title "${MAIN_MENU_TITLE}" --menu \
        "${INFOTEXT}" \
        --ok-button "Select" 16 ${WIDTH} 0 \
            1 "Flash Production (Entire Partition)" \
            2 "Flash Service (System Partition)" \
            3 "Shutdown" \
            3>&2 2>&1 1>&3 )

    case $CHOICE in
    1)
        log "Production flash selected"
        systemConfirmation "WARNING: You are about to flash the entire disk.\n\n
            THIS WILL ERASE CUSTOMER DATA.\n\n\n
            Do you want to continue?"
        
	    if [ $? -ne 0 ]; then 
            main
        fi
        
        flash_production
        log "Production flash sucessfully completed"
        infobox "Production flash completed.  The system will shutdown now. please remove the USB and press the power button to boot the system."
        log "Shutting down....."
        /sbin/poweroff
        ;;
    2)
        log "Service flash selected"
        systemConfirmation "WARNING: You are about to flash the system partition only.\n\
         Customer data will remain on the data partition.\n\n\n\
             Do you want to continue?"
        
	    if [ $? -ne 0 ]; then 
            main
        fi
        log "Starting service flash"
        flash_service
        if [ $? -ne 0 ]; then
            main
        fi  
       
        log "Service flash sucessfully completed"
        infobox "Service flash sucessfully completed. The system will shutdown now. please remove the USB and press the power button to boot the system."
        log "Shutting down....."
        /sbin/poweroff
        ;;
    3)
        log "Shutdown selected"
        shutdown
        ;;
    *)
        log "Invalid option selected"
        exit
        ;;
    esac
  
}

# ===========================
# FLASH MENU
# ===========================
### FLASH ENTIRE DISK ###
### FOR PRODUCTION ###
function flash_production()
{
    log "Starting production flash"
    ./$INSTALLER_BIN
}

### FLASH SYSTEM PARTITION ONLY ### 
### FOR SERVICE UPDATE ###
function flash_service()
{
    log "Starting service flash"
    create_data_partion

    if [ $? -ne 0 ]; then

        return 1
    fi

    mountDataPartition

    if [ $? -ne 0 ]; then
        errorlog "Failed to mount data partition "
        return 1
    fi

    rsync -avz  /mnt/data/ /data/ 
    if [ $? -ne 0 ]; then
        errorlog "rsync failed to  backup data partition. ERROR ID : $?"
        errorbox "Failed to copy data partition. Error ID : $?"
        return 1
    fi

    umount /mnt/data

    ./$INSTALLER_BIN

    mountDataPartition

    if [ $? -ne 0 ]; then
        errorlog "Failed to mount data partition "
        return 1
    fi

    rsync -avz /data/ /mnt/data/ 
    if [ $? -ne 0 ]; then
        errorlog "rsync failed to  restore data partition. ERROR ID : $?"
        errorbox "Failed to restore data partition. Error ID : $?"
        return 1
    fi
    mkdir -p /mnt/data/logs
    cp $TUILOG /mnt/data/logs/tui.log
    umount /mnt/data

    umount /data
    return 0
}


function mountDataPartition(){
    DISK="/dev/sda"
    partition=/dev/$(lsblk -no NAME $DISK | tail -n 1 | sed 's/.*-\(.*\)/\1/')

    # Loop through each partition

    mkdir -p /mnt/data  # Create a mount point

    if [ $? -ne 0 ]; then
        errorlog "Failed to create mount point."
        errorbox "Failed to create mount point."
        return 1
    fi

    mount $partition /mnt/data  # Mount the partition

    if [ $? -ne 0 ]; then
        errorlog "Failed to mount partition."
        errorbox "Failed to mount partition."
        return 1
    fi

    return 0
}




# ===========================
# HELPERS - LOG/ERROR
# ===========================
### system message dialog ###
function systemMsg()
{
    whiptail --title "System Message" --msgbox "$1" 16 ${WIDTH}  
} 


### system dialog yes no confirmation ###
function systemConfirmation()
{
    if whiptail --title "System Dialog" --yesno "$1" 16 ${WIDTH}; then 
        return 0

    else
        return 1
    fi

}


### box functions ###
function infobox()
{
    whiptail --title "INFO" --msgbox "\n'$*'" 0 0
}

function errorbox()
{
    whiptail --title "ERROR" --msgbox "\n$*" 0 0
    
}

### Log functions ###
function log()
{
    echo "$(date +'%Y/%m/%d - %T') $*" >> $TUILOG
}

function errorlog()
{
    echo "$(date +'%Y/%m/%d - %T') - $*" >> $ERRORLOG
}

# ===========================
# SHUTDOWN / REBOOT
# ===========================
function shutdown()
{
    if (whiptail --title "Shutdown" --yesno "I am going to shut down now ..." 0 0 0); then
        /sbin/poweroff
    else
        main
    fi
}

function reboot()
{
    if (whiptail --title "Reboot" --yesno "I am going to reboot now ..." 0 0 0); then
        /sbin/reboot
    else
        main
    fi
}


function create_data_partion(){

    log "Creating data partition"

    # check if there is enough space to create a data partition



    PARTITION=$(findmnt -n -o SOURCE /)
    DEVICE=$(echo $PARTITION | sed 's/[0-9]//g')
    NUMBER_OF_PARTITIONS=$(lsblk -lno NAME $DEVICE | wc -l)
    log "Number of partitions: $NUMBER_OF_PARTITIONS"

    while [ $NUMBER_OF_PARTITIONS -gt 2 ]; do
        DELETE_PARTITION_NUMBER=$((NUMBER_OF_PARTITIONS - 1))
        log "Removing existing partitions: $DELETE_PARTITION_NUMBER"
        parted -s $DEVICE rm $DELETE_PARTITION_NUMBER  >> $TUILOG 2>&1
        NUMBER_OF_PARTITIONS=$(lsblk -lno NAME $DEVICE | wc -l)
    done


    log "Creating Data Partion on USB Device : $DEVICE mounted on $PARTITION"
    log "Found partition: $PARTITION" 
    log "Device: $DEVICE" 

    
    TOTAL_FREE_DISK_SIZE=$(parted -m $DEVICE unit b print free | tail -n 1 | awk -F: '{print $3}' | sed 's/B//g') 
    log "Total disk size: $TOTAL_FREE_DISK_SIZE bytes" 


    MINIMUN_DISK_SIZE=$((4 * 1024 * 1024 * 1024)) # 4GB

    if [ $TOTAL_FREE_DISK_SIZE -lt $MINIMUN_DISK_SIZE ]; then
        errorlog "ERROR : Not enough space to create a data partition.  required $TOTAL_DISK_SIZE actual $MINIMUM_DISK_SIZE"
        errorbox "Not enough space to create a data partition, please use USB with at least 8GB of space.\n required $TOTAL_DISK_SIZE actual $MINIMUM_DISK_SIZE"
        return 1
    fi

    # Create data partition
    echo "Creating data partition"
    START=$(parted -m $DEVICE unit MB print free | tail -n 1 | awk -F: '{print $2}')
    log "Creating data partition starting at $START MB"
    parted -s $DEVICE mkpart primary fat32 ${START}MB 100% >> $TUILOG 2>&1

    if [ $? -ne 0 ]; then
        errorlog " ERROR : error in parted"
        errorbox "partion creation failed \n $TUILOG"
        return 1
    fi

    # Get the new partition name (assuming it's the next available partition number)
    NEW_PARTITION="/dev/$(lsblk -no NAME $DEVICE | tail -n 1 | sed 's/.*-\(.*\)/\1/')"
    echo "New partition: $NEW_PARTITION" 

    mkfs.fat -F32 $NEW_PARTITION

    mkdir -p /data

    mount $NEW_PARTITION /data

    return 0




}
# ===========================
# MAIN LOOP
# ===========================
log "Starting TUI"
main
