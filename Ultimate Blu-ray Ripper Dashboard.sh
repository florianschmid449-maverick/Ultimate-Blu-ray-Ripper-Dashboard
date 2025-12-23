#!/bin/bash

# =========================================
# Ultimate Blu-ray Ripper Dashboard
# Fully Resumable + Split + SHA256 + Visual Progress + Retry Color Codes
# =========================================

DESKTOP="$HOME/Desktop"
MASTER_LOG="$DESKTOP/disc_rip_master_log.csv"
SESSION_DISCS=0
SESSION_LIST=""
MAX_RETRIES=3
SPLIT_SIZE=$((4*1024*1024*1024))  # 4GB

# Colors for dashboard
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Ensure dependencies
command -v ddrescue &>/dev/null || sudo apt update && sudo apt install -y gddrescue
command -v pv &>/dev/null || sudo apt install -y pv

detect_drive() {
    DEVICES=($(lsblk -dpno NAME,TYPE | grep "rom$" | awk '{print $1}'))
    [ ${#DEVICES[@]} -gt 0 ] && echo "${DEVICES[0]}" || echo ""
}

# Initialize CSV
[ ! -f "$MASTER_LOG" ] && echo "timestamp,filename,size_bytes,sha256,num_parts" > "$MASTER_LOG"

notify() { command -v notify-send &>/dev/null && notify-send "Disc Ripper" "$1"; }

# Trap Ctrl+C to safely stop
trap 'echo -e "\n🛑 Interrupted. Total discs ripped: $SESSION_DISCS"; notify "Batch complete: $SESSION_DISCS discs"; exit 0' INT

echo -e "${CYAN}🎬 Ultimate Blu-ray Ripper Dashboard Started${RESET}"

while true; do
    DVD_DEVICE=$(detect_drive)
    [ -z "$DVD_DEVICE" ] && sleep 2 && continue
    blkid "$DVD_DEVICE" &>/dev/null || sleep 2 && continue

    echo -e "${CYAN}📀 Disc detected: $DVD_DEVICE${RESET}"
    DISC_TYPE=$(blkid "$DVD_DEVICE" 2>/dev/null | grep -o "iso9660")
    BS=$([ "$DISC_TYPE" == "iso9660" ] && echo 2048 || echo 1M)

    DATE_STR=$(date +%Y%m%d_%H%M%S)
    BASE_NAME="disc_rip_$DATE_STR"
    FILENAME="$BASE_NAME.iso"
    COUNTER=1
    while [ -e "$DESKTOP/$FILENAME" ]; do FILENAME="${BASE_NAME}_$COUNTER.iso"; ((COUNTER++)); done
    OUTPUT_FILE="$DESKTOP/$FILENAME"
    LOG_FILE="$DESKTOP/${FILENAME}.log"

    DISC_SIZE=$(blockdev --getsize64 "$DVD_DEVICE" 2>/dev/null || echo 4700000000)
    FREE_SPACE=$(df --output=avail "$DESKTOP" | tail -1)
    FREE_SPACE=$((FREE_SPACE * 1024))
    if [ "$FREE_SPACE" -lt "$DISC_SIZE" ]; then
        echo -e "${RED}❌ Not enough space. Ejecting disc.${RESET}"
        sudo eject "$DVD_DEVICE"; sleep 5; continue
    fi

    echo -e "${CYAN}⏳ Ripping disc with progress bar...${RESET}"

    # Function to rip with colored visual progress
    rip_part() {
        local input="$1"
        local output="$2"
        local log="$3"
        local part_name="$4"
        local retries="$5"

        echo -e "${YELLOW}📊 $part_name | Retry: $retries${RESET}"

        # Pipe ddrescue output through pv for real-time progress
        sudo ddrescue -b "$BS" -n "$input" "$output" "$log" --no-split &
        DD_PID=$!
        while kill -0 $DD_PID 2>/dev/null; do
            sleep 1
            # Show pv-style progress: speed and estimated time
            SIZE_DONE=$(stat -c%s "$output" 2>/dev/null || echo 0)
            PERCENT=$(awk "BEGIN {printf \"%.2f\",($SIZE_DONE/$DISC_SIZE)*100}")
            SPEED=$(awk "BEGIN {printf \"%.2f\",$SIZE_DONE/1024/1024/1}") # rough MB done
            ETA=$(awk "BEGIN {if($SIZE_DONE>0) printf \"%d\",(($DISC_SIZE-$SIZE_DONE)/($SIZE_DONE/1)) else printf \"?\"}")
            echo -ne "${CYAN}Progress: ${PERCENT}% | Speed: ${SPEED} MB | ETA: ${ETA}s${RESET}\r"
        done
        echo -e "\n${GREEN}✔ Finished $part_name${RESET}"
    }

    if [ "$DISC_TYPE" == "iso9660" ] || [ "$DISC_SIZE" -le $((25*1024*1024*1024)) ]; then
        RETRIES=0; SUCCESS=false
        while [ $RETRIES -le $MAX_RETRIES ]; do
            rip_part "$DVD_DEVICE" "$OUTPUT_FILE" "$LOG_FILE" "$FILENAME" "$RETRIES"
            SHA256_SUM=$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')
            [ -n "$SHA256_SUM" ] && SUCCESS=true && break
            ((RETRIES++))
        done
        [ "$SUCCESS" = false ] && echo -e "${RED}❌ Failed after $MAX_RETRIES attempts${RESET}"; sudo eject "$DVD_DEVICE"; sleep 3; continue
        NUM_PARTS=1
    else
        # Large Blu-ray
        rip_part "$DVD_DEVICE" "$OUTPUT_FILE" "$LOG_FILE" "$FILENAME" 0
        split -b $SPLIT_SIZE "$OUTPUT_FILE" "${OUTPUT_FILE%.iso}_part"
        rm -f "$OUTPUT_FILE"

        PARTS=(${OUTPUT_FILE%.iso}_part*)
        NUM_PARTS=${#PARTS[@]}
        SHA256_LIST=""

        for PART in "${PARTS[@]}"; do
            RETRIES=0
            while [ $RETRIES -le $MAX_RETRIES ]; do
                echo -e "${YELLOW}📊 Verifying $PART | Retry: $RETRIES${RESET}"
                pv "$PART" >/dev/null
                PART_SHA=$(sha256sum "$PART" | awk '{print $1}')
                if [ -n "$PART_SHA" ]; then
                    SHA256_LIST+="${PART}:$PART_SHA;"
                    break
                fi
                ((RETRIES++))
            done
        done
        SHA256_SUM="$SHA256_LIST"
    fi

    ((SESSION_DISCS++))
    SESSION_LIST+="$FILENAME ($NUM_PARTS parts)\n"

    sudo eject "$DVD_DEVICE"
    echo -e "${CYAN}📀 Disc ejected. Waiting for next...${RESET}"
    sleep 3

    echo "$(date +%Y-%m-%d_%H:%M:%S),$FILENAME,$DISC_SIZE,\"$SHA256_SUM\",$NUM_PARTS" >> "$MASTER_LOG"
    notify "Disc ripped: $FILENAME"
done

