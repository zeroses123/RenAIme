#!/bin/bash
# https://github.com/zeroses123/ocr_ai_file_renamer
# Usage: ./ai_scan_rename_only.sh <directory>
# Modified version: Processes book PDFs, extracting only first 5 pages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PDFTOPPM="/usr/local/bin/pdftoppm"      # Type in Terminal: which pdftoppm and replace the path here
TESSERACT="/opt/homebrew/bin/tesseract" # Type in Terminal: which tesseract and replace the path here

sanitize_text() {
    echo "$1" | tr -cd '[:print:]\n' | sed 's/"/\\"/g' | tr -s ' '
}

if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <directory>${NC}"
    exit 1
fi

DIR="${1%/}"  # Entfernt evtl. letzten Slash
if [ ! -d "$DIR" ]; then
    echo -e "${RED}Directory '$DIR' does not exist.${NC}"
    exit 1
fi

RENAME_DIR="$DIR/Renamed"
mkdir -p "$RENAME_DIR"

TEMP_DIR="$DIR/Temp"
LOG_FILE="$DIR/scan.log"
mkdir -p "$TEMP_DIR" 

log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[${timestamp}]${NC} - ${GREEN}$1${NC}"
    echo -e "${timestamp} - $1" >> "$LOG_FILE"
}

debug_log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[${timestamp}]${NC} - ${YELLOW}[DEBUG] $1${NC}"
    echo -e "${timestamp} - [DEBUG] $1" >> "$LOG_FILE"
}

log "Processing directory: $DIR"

find "$DIR" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.jpg' -o -iname '*.png' \) | while read -r FILE; do
    # Dateigröße prüfen und loggen
    FILE_SIZE=$(stat -f%z "$FILE")
    debug_log "File size of $FILE: $FILE_SIZE bytes"
    
    log "Processing file: $FILE"
    OCR_TEXT=""
    log "Starting OCR..."
    
    # Aus dem Dateinamen Basename ohne Extension generieren
    BASENAME="${FILE##*/}"         # z.B. input.pdf
    BASENAME="${BASENAME%.*}"      # z.B. input
    log $BASENAME
    log $FILE
    # Temp-Verzeichnis erstellen
    mkdir -p "$TEMP_DIR"

    if [[ "$FILE" == *.pdf ]]; then
        # Log PDF-Seitenanzahl
        PAGE_COUNT=$(mdls -name kMDItemNumberOfPages -raw "$FILE")
        debug_log "PDF page count: $PAGE_COUNT"
        
        # PDF zu PNG Konvertierung mit zusätzlichen Logs - ONLY FIRST 5 PAGES
        debug_log "Converting first 5 pages of PDF to PNG..."
        if ! "$PDFTOPPM" -f 1 -l 5 "$FILE" "$TEMP_DIR/${BASENAME}_page" -png 2> >(debug_log "pdftoppm error: $(cat)"); then
            log "Error: PDF to PNG conversion failed"
            continue
        fi
        
        # Prüfen, ob PNG-Dateien erzeugt wurden
        PNG_FILES=("$TEMP_DIR/${BASENAME}_page-"*.png)
        if [ ! -f "${PNG_FILES[0]}" ]; then
            log "Error: PDF conversion did not produce any PNG file"
            continue
        fi
        
        # OCR-Text aus allen 5 (oder weniger) extrahierten Seiten zusammenführen
        OCR_TEXT=""
        for PNG_FILE in "${PNG_FILES[@]}"; do
            PNG_SIZE=$(stat -f%z "$PNG_FILE")
            debug_log "Processing PNG file: $PNG_FILE (size: $PNG_SIZE bytes)"
            
            # OCR text extrahieren und anhängen
            PAGE_TEXT=$("$TESSERACT" "$PNG_FILE" - -l deu 2>/dev/null)
            OCR_TEXT="${OCR_TEXT}${PAGE_TEXT}\n\n--- Page Break ---\n\n"
        done
        
        debug_log "Extracted OCR text from first 5 pages, total length: ${#OCR_TEXT} characters"
        
        # Temporäre PNG-Dateien löschen
        rm -f "${PNG_FILES[@]}"


    else
        # Direkte Bildverarbeitung (jpg/png)
        OCR_PDF="$TEMP_DIR/${BASENAME}_ocr.pdf"
        if ! "$TESSERACT" "$FILE" "$TEMP_DIR/${BASENAME}_ocr" -l deu pdf 2>/dev/null; then
            log "Error: OCR PDF creation failed"
            continue
        fi
        COMBINED_OCR_PDF="$OCR_PDF"
        OCR_TEXT=$("$TESSERACT" "$FILE" - -l deu 2>/dev/null)
    fi

    # KI-Verarbeitung mit zusätzlichen Logs
    if [ -z "$OCR_TEXT" ]; then
        debug_log "OCR text is empty!"
        log "OCR failed! Skipping."
        continue
    fi
    
    debug_log "Sending OCR text to AI service (text length: ${#OCR_TEXT})"
    
    log "OCR completed successfully."

    # Änderungsdatum
    MOD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$FILE")
    log "Extracting filename from OCR text..."

    # Fallback wenn kein KI-Server verfügbar ist
    if ! curl -s -m 1 http://localhost:1234 > /dev/null 2>&1; then
        log "KI-Server nicht erreichbar, verwende Standardbenennung"
        FILE_NAME_FROM_AI=$(echo "$FILE" | sed 's/.*\///' | sed 's/\.[^.]*$//')
        DATE_FROM_AI="$MOD_DATE"
        AUTHOR_FROM_AI="Unknown"
        TITLE_FROM_AI=$(echo "$FILE" | sed 's/.*\///' | sed 's/\.pdf$//')
        YEAR_FROM_AI=""
    else
        # KI-Request mit neuem Prompt spezifisch für Bücher
        RESPONSE=$(curl -s -X POST http://localhost:1234/v1/chat/completions \
            -H "Content-Type: application/json" --data @- <<EOF
{
  "messages": [
    {
      "role": "system",
      "content": "### Human:\nYou are an AI book metadata extractor. Your task is to identify and extract the following information from book PDFs by analyzing their first few pages (title page, copyright page, etc.):\n\n1. The full author name(s)\n2. The complete book title (including subtitle if present)\n3. The publication year\n\nThis information is typically found on the first pages of a book, often on the title page, copyright page, or in the front matter.\n\nReturn the information in JSON format with the following fields:\n- Author: The full name of the author(s). If multiple authors, separate with 'and' or commas. If no author can be identified, use 'Unknown'.\n- Title: The complete book title. Include any subtitle after a colon if present.\n- Year: The publication year in YYYY format. If not found, leave empty.\n\nExample response: {\"Author\": \"Jane Smith\", \"Title\": \"The Great Novel: A Story of Adventure\", \"Year\": \"2020\"}\n\nOnly return the JSON object, no additional text or explanation.\n### Assistant:"
    },
    {
      "role": "user",
      "content": "### Human:\nHere is the OCR text from the first 5 pages of the book:\n$(sanitize_text "$OCR_TEXT")\n\nThe file modification date is: $MOD_DATE\nPlease extract the author name, book title, and publication year according to the instructions.\n### Assistant:"
    }
  ],
  "temperature": 0,
  "max_tokens": 10000,
  "stream": false
}
EOF
        )
        
        if [ -z "$RESPONSE" ]; then
            log "Fehler: Keine Antwort von der KI erhalten!"
            continue
        fi

        CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
        if [ $? -ne 0 ]; then
            log "Error: Failed to parse AI response"
            continue
        fi

        AUTHOR_FROM_AI=$(echo "$CONTENT" | jq -r '.Author' 2>/dev/null)
        TITLE_FROM_AI=$(echo "$CONTENT" | jq -r '.Title' 2>/dev/null)
        YEAR_FROM_AI=$(echo "$CONTENT" | jq -r '.Year' 2>/dev/null)

        log "Extracted metadata - Author: $AUTHOR_FROM_AI, Title: $TITLE_FROM_AI, Year: $YEAR_FROM_AI"

        if [ -z "$AUTHOR_FROM_AI" ] || [ "$AUTHOR_FROM_AI" == "null" ]; then
            log "Warning: Author information not found or invalid"
            AUTHOR_FROM_AI="Unknown"
        fi

        if [ -z "$TITLE_FROM_AI" ] || [ "$TITLE_FROM_AI" == "null" ]; then
            log "Warning: Title information not found or invalid"
            TITLE_FROM_AI="Untitled"
        fi

        if [ -z "$YEAR_FROM_AI" ] || [ "$YEAR_FROM_AI" == "null" ]; then
            log "Year information not available, skipping in filename"
            FILENAME_WITH_YEAR="${AUTHOR_FROM_AI} - ${TITLE_FROM_AI}"
        else
            FILENAME_WITH_YEAR="${AUTHOR_FROM_AI} - ${TITLE_FROM_AI} (${YEAR_FROM_AI})"
        fi
    fi

    # Bereinigen des Dateinamens: Entferne unerwünschte Zeichen, ersetze Leerzeichen mit Unterstrichen
    CLEAN_FILENAME=$(echo "$FILENAME_WITH_YEAR" | sed 's/[^a-zA-Z0-9_ ()-]/_/g' | tr -s ' ')

    # Prüfe die Länge des Dateinamens
    LEN_CHECK=${#CLEAN_FILENAME}
    if [ "$LEN_CHECK" -gt 120 ]; then
        log "Warnung: Dateiname hat mehr als 120 Zeichen. Kürze Namen..."
        CLEAN_FILENAME="${CLEAN_FILENAME:0:120}"
    fi

    # Definiere neuen Dateinamen im gleichen Verzeichnis wie das Original
    NEW_FILENAME="$RENAME_DIR/$CLEAN_FILENAME.pdf"

    log "Bereite Umbenennung vor: $FILE -> $NEW_FILENAME"

    # Prüfen, ob die Datei bereits existiert
    if [ -f "$NEW_FILENAME" ] && [ "$FILE" != "$NEW_FILENAME" ]; then
        log "Warnung: Zieldatei existiert bereits. Füge Zeitstempel hinzu..."
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        NEW_FILENAME="$RENAME_DIR/$CLEAN_FILENAME-$TIMESTAMP.pdf"
    fi

    # Umbenennen der ursprünglichen Datei (keine Kopie erstellen)
    if [ "$FILE" != "$NEW_FILENAME" ]; then
        if ! mv "$FILE" "$NEW_FILENAME"; then
            log "Fehler: Konnte Datei nicht umbenennen: $FILE"
            continue
        fi
        log "Datei erfolgreich umbenannt: $NEW_FILENAME"
    else
        log "Datei hat bereits den korrekten Namen, keine Aktion erforderlich."
    fi

    log "--------------------------------------"
done

# Aufräumen
rm -rf "$TEMP_DIR"
log "Verarbeitung abgeschlossen!"
