#!/bin/bash
# https://github.com/zeroses123/ocr_ai_file_renamer
# Usage: ./ai_scan.sh <directory>
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Argumentenprüfung
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <directory>${NC}"
    exit 1
fi

DIR="${1%/}"  # Entfernt evtl. letzten Slash
if [ ! -d "$DIR" ]; then
    echo -e "${RED}Directory '$DIR' does not exist.${NC}"
    exit 1
fi

BACKUP_DIR="$DIR/Backup"
TEMP_DIR="$DIR/Temp"
LOG_FILE="$DIR/scan.log"
mkdir -p "$BACKUP_DIR" "$TEMP_DIR"

# Logging-Funktion
log() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
log "Processing directory: $DIR"

# Datei-Scan & Verarbeitung
find "$DIR" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.jpg' -o -iname '*.png' \) | while read -r FILE; do
    log "Processing file: $FILE"
    
    OCR_TEXT=""
    log "Starting OCR..."
    
    if [[ "$FILE" == *.pdf ]]; then
        IMAGE="$TEMP_DIR/${FILE##*/}.png"
        /usr/local/bin/pdftoppm "$FILE" "$TEMP_DIR/${FILE##*/}" -png -f 1 -singlefile >/dev/null 2>&1
        [ -f "$IMAGE" ] && OCR_TEXT=$(/usr/local/bin/tesseract "$IMAGE" - -l deu 2>/dev/null) && rm "$IMAGE"
    else
        OCR_TEXT=$(/usr/local/bin/tesseract "$FILE" - -l deu 2>/dev/null)
    fi
    
    [ -z "$OCR_TEXT" ] && log "OCR failed! Skipping." && continue
    log "OCR completed."
    
    MOD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$FILE")
    log "Sending to AI for renaming..."
    
    # KI-Request an ChatGPT-Server
    RESPONSE=$(curl -s -X POST http://localhost:1234/v1/chat/completions \
        -H "Content-Type: application/json" --data @- <<EOF
{
  "messages": [{"role": "system", "content": "Generate a filename & folder based on OCR text."},
  {"role": "user", "content": "$OCR_TEXT\nDate: $MOD_DATE"}]
}
EOF
)

    [ -z "$RESPONSE" ] && log "AI request failed! Skipping." && continue

    # JSON Parsing
    FILE_NAME=$(echo "$RESPONSE" | jq -r '.FileName // empty')
    DATE_FROM_AI=$(echo "$RESPONSE" | jq -r '.Date // "$MOD_DATE"')
    FOLDER=$(echo "$RESPONSE" | jq -r '.Folder // "Unknown"')
    
    [ -z "$FILE_NAME" ] && log "AI returned no filename! Skipping." && continue

    CLEAN_FILENAME=$(echo "$FILE_NAME" | sed 's/[^a-zA-Z0-9_]/_/g' | tr -s '_')
    FINAL_FILENAME="$DIR/$FOLDER/${CLEAN_FILENAME}_${DATE_FROM_AI}.pdf"
    mkdir -p "$DIR/$FOLDER"
    
    mv "$FILE" "$FINAL_FILENAME"
    log "File renamed to: $FINAL_FILENAME"

    mv "$FILE" "$BACKUP_DIR/"
    log "Backup created."
    
    # Schicke coole Warteanimation
    for i in {1..3}; do echo -ne "${YELLOW}."; sleep 0.5; done; echo -e "${NC}"
    log "--------------------------------------"
done

rm -rf "$TEMP_DIR"
log "Cleanup completed!"
