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
BACKTITLE="Geshem Flasher"
WIDTH=70


# ===========================
# FRAMEBUFFER RESOLUTION
# ===========================
# https://man.archlinux.org/man/fbset.8.en
# Otherwise default 640x480 is used

# TODO: reload - works only properly after "Cancel"
fbset -g 1920 1080 1920 1080 32

# ===========================
# COLORS WHIPTAIL
# ===========================
export REDBLUE='
    root=,brightblue
    checkbox=,blue
    entry=,blue
    label=blue,
    actlistbox=,blue
    helpline=,blue
    roottext=,blue
    emptyscale=blue
    disabledentry=blue,
'
### Colors ###
# red, green, brown, blue, magenta, cyan, yellow
# brightred, brightcyan, brightblue, brightgreen, brightmagenta
# black, white, gray, lightgray

### Options
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

# chosen color profile
export NEWT_COLORS=$REDBLUE


# ===========================
# MAIN MENU
# ===========================
MAIN_MENU_TITLE="Production Flash Menu"
INFOTEXT="You will flash the entire hard drive with a new image.\n\n\n"

function main()
{
    CHOICE=$(
        whiptail --backtitle "${BACKTITLE}" \
        --title "${MAIN_MENU_TITLE}" --menu \
        "${INFOTEXT}" \
        --ok-button "Select" 16 ${WIDTH} 0 \
            1 "Flash (full)" \
            2 "Expert Mode" \
            3 "Shutdown" \
            3>&2 2>&1 1>&3 )
    case $CHOICE in
    1)
        flash_production
        ;;
    2)
        expert_mode
        ;;
    3)
        shutdown
        ;;       
    *)
        exit
        ;;
    esac
}

function expert_mode()
{
    CHOICE=$(
        whiptail --backtitle "${BACKTITLE}" \
        --title "Expert Mode" --menu \
        "This mode is mainly for developers!" \
        --ok-button "Select" 16 ${WIDTH} 0 \
            1 "Clonzilla" \
            2 "Clone (full)" \
            3 "Clone (system-only)" \
            4 "Terminal" \
            3>&2 2>&1 1>&3 )
    case $CHOICE in
    1)
        clonezilla && main
        ;;
    2)
        clone_full && main # clone_sda
        ;;
    3)
        clone_system && main # clone_sda2
        ;;    
    4)
        tmux && main
        ;;    
    *)
        exit
        ;;
    esac
}



# ===========================
# FLASH MENU
# ===========================
### FLASH SYSTEM PARTITION ONLY ### 
### FOR SERVICE UPDATE ###

function flash_production()
{
    FILE_SELECTED=""
    if mount | grep -w /data > /dev/null; then
        STARTDIR="/data"
        EXTENSION="*.gz"
        filebrowser "Filebrowser" "$STARTDIR" "$EXTENSION"
        log "Selected image: $FILE_SELECTED" && log "Selected image path: $FILE_SELECTED_PATH"
        if [ ! -z $FILE_SELECTED ]; then
            flash_sda $FILE_SELECTED_PATH && infobox "Flashing complete. Please check if Box-PC is booting. I am going to shutdown now!" && shutdown
        else
            log "Filebrowser - No file selected!" && infobox "Filebrowser - No file selected!" && main
        fi    
    else
        errorbox "Data partition (/data) is not mounted! Contact the developer!"
    fi        
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

function flash_full()
{
    if mount | grep -w /data > /dev/null; then
        
        TEMPDIR=/data/nprohd_full_flashing
        BOOT=/dev/sda1
        SYS=/dev/sda2
        DATA=/dev/sda3

        FROMBOOT=$(find . -maxdepth 1 -name \*"boot"\*.pcl)
        FROMSYS=$(find . -maxdepth 1 -name \*"system"\*.pcl)
        FROMDATA=$(find . -maxdepth 1 -name \*"data"\*.pcl)  

        mkdir -p $TEMPDIR && cd $TEMPDIR 
        tar -xvf *.tgz

        # TODO: check image before flash 
        # partclone.chkimg -C -N -s $FROMSYSTEM --logfile $TEMPDIR/partclone.log 
        # -C don't check free space and device size

        # Step 1: Clone boot partition
        # https://partclone.org/usage/partclone.dd.php
        log "Flashing $FROMBOOT to $BOOT ..."
        partclone.dd    -N -s $FROMBOOT     -o $BOOT && \
        
        # Step 2: Clone system partition
        log "Flashing $FROMSYS to $SYS ..."
        partclone.ext4  -N -r -s $FROMSYS  -o $SYS && \
          
        # Step 3: Clone data partition
        log "Flashing $FROMDATA to $DATA ..."
        partclone.vfat  -N -r -s $FROMDATA  -o $DATA && \
        
        infobox "Flashing full drive complete."   
    else
        errorbox "Data partition (/data) is not mounted! Contact the developer!"
    fi  

    #cat $FROM | gunzip -c | partclone.dd -N -d  -s - -o $TO && \
}

function reboot_prompt()
{
    infobox "Flashing was successful. Reboot now!"
    reboot
}


# ===========================
# CLONE MENU
# ===========================

# clone & compress - system partition only
function clone_system()
{
    if mount | grep -w /data > /dev/null; then
        FROM=/dev/sda2
        TO=/data/nprohd_sda2_$(date +%F_%H-%M-%S).img.gz
        log "Cloning $FROM to $TO ..."
        partclone.ext4 -N -c -s $FROM | gzip -c -6 > $TO && \
        log "Cloning $FROM to $TO succesful." 
    else
        errorbox "Data partition (/data) is not mounted! Contact the developer!"
    fi  
}

# clone & compress - whole drive
function clone_full()
{
    if mount | grep -w /data > /dev/null; then
        
        TEMPDIR=/data/nprohd_full 
        BOOT=/dev/sda1
        SYS=/dev/sda2
        DATA=/dev/sda3
        
        TOBOOT=/data/${TEMPDIR}/nprohd_sda1_boot_$(date +%F--%H-%M-%S).pcl
        TOSYS=/data/${TEMPDIR}/nprohd_sda2_system_$(date +%F--%H-%M-%S).pcl
        TODATA=/data/${TEMPDIR}/nprohd_sda3_data_$(date +%F--%H-%M-%S).pcl

        mkdir -p $TEMPDIR && cd $TEMPDIR 

        # Step 1: Clone boot partition
        # https://partclone.org/usage/partclone.dd.php
        log "Cloning $BOOT to $TOBOOT ..."
        partclone.dd    -N -s $BOOT     -o $TOBOOT && \
        
        # Step 2: Clone system partition
        log "Cloning $SYS to $TOSYS ..."
        partclone.ext4  -N -c -s $SYS  -o $TOSYS && \
          
        # Step 3: Clone data partition
        log "Cloning $DATA to $TODATA ..."
        partclone.vfat  -N -c -s $DATA  -o $TODATA && \
        
        # Step 4: Compression 
        tar -czvf nprohd_full_$(date +%F--%H-%M-%S).tgz .

        # Step 5: Cleanup (if prefered)
        # rm -v *.pcl

        infobox "Flashing full drive complete. Check if boot works properly!"   
    else
        errorbox "Data partition (/data) is not mounted! Contact the developer!"
    fi   
}


# ===========================
# HELPERS - FILEBROWSER
# ===========================
function filebrowser
{
    local TITLE=${1:-$MSG_INFO_TITLE}
    local LOCAL_PATH=${2:-$(pwd)}
    local FILE_MASK=${3:-"*"} #.img.gz
    local ALLOW_BACK=${4:-yes}
    local FILES=()

    [ "$ALLOW_BACK" != "no" ] && FILES+=(".." "..")

    # First add folders
    for DIR in $(find $LOCAL_PATH -maxdepth 1 -mindepth 1 -type d -printf "%f " 2> /dev/null)
    do
        FILES+=($DIR "folder")
    done

    # Then add the files
    for FILE in $(find $LOCAL_PATH -maxdepth 1 -type f -name "$FILE_MASK" -printf "%f %s " 2> /dev/null)
    do
        FILES+=($FILE)
    done

    while true
    do
        FILE_SELECTED=$(whiptail --clear --backtitle "$BACK_TITLE" --title "$TITLE" --menu "$LOCAL_PATH" 16 $WIDTH 0 ${FILES[@]} 3>&1 1>&2 2>&3)

        if [ -z "$FILE_SELECTED" ]; then
            return 1
        else
            if [ "$FILE_SELECTED" = ".." ] && [ "$ALLOW_BACK" != "no" ]; then
                return 0

            elif [ -d "$LOCAL_PATH/$FILE_SELECTED" ] ; then
                if filebrowser "$TITLE" "$LOCAL_PATH/$FILE_SELECTED" "$FILE_MASK" "yes" ; then
                    if [ "$FILE_SELECTED" != ".." ]; then
                        return 0
                    fi
                else
                    return 1
                fi

            elif [ -f "$LOCAL_PATH/$FILE_SELECTED" ] ; then
                FILE_SELECTED="$FILE_SELECTED"
                FILE_SELECTED_PATH="$LOCAL_PATH/$FILE_SELECTED"
                return 0
            fi
        fi
    done
}

# ===========================
# HELPERS - LOG/ERROR
# ===========================

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
        /sbin/poweroff || /sbin/shutdown now
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
