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

# Options for production and Service scripts 

PRODUCTION_SCRIPT=""
SERVICE_SCRIPT=""

# Parse options
while getopts "p:s:" opt; do
  case $opt in
    p)
      PRODUCTION_SCRIPT="$OPTARG"
      ;;
    s)
      SERVICE_SCRIPT="$OPTARG"
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
INFOTEXT="You will flash the entire system partition with a new image. Customer data will remain on the data partition.\n\n\n"

function main()
{
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
        systemConfirmation "WARNING: You are about to flash the entire disk.\n\n
            THIS WILL ERASE CUSTOMER DATA.\n\n\n
            Do you want to continue?"
        
	    if [ $? -eq 0 ]; then 
            flash_production
            systemMsg "Production flash completed. remove the USB and reboot the system."
        else
            main
        fi
        
        ;;
    2)
        systemConfirmation "WARNING: You are about to flash the system partition only.\n\
         Customer data will remain on the data partition.\n\n\n\
             Do you want to continue?"
        
	    if [ $? -eq 0 ]; then 
            flash_service
            systemMsg "Service flash completed. remove the USB and reboot the system."
        else
            main
        fi
        
        ;;
    3)
        shutdown
        ;;
    *)
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
    systemMsg "This is the production flash $PRODUCTION_SCRIPT"   
}

### FLASH SYSTEM PARTITION ONLY ### 
### FOR SERVICE UPDATE ###
function flash_service()
{
    systemMsg "This is the service flash $SERVICE_SCRIPT"   
}


# mount image repo 
function mount_home()
{
    REPO=/dev/sdb4
    TO=/mnt/usb
    mkdir -p $TO && \
    mount $REPO $TO && \
    log "Mounting $REPO to $TO ..."
}

# decompress and flash - system partition only
function flash_sda2()
{
    FROM="$1"
    TO=/dev/sda2
    log "Flashing $FROM to $TO ..."
    cat $FROM | gunzip -c | partclone.ext4 -N -d -r -s - -o $TO && \
    log "Flashing $FROM to $TO succesful."
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
    errorlog "$*"
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

# ===========================
# MAIN LOOP
# ===========================
main
