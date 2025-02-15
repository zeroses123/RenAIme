#!/bin/bash
# https://github.com/zeroses123/ocr_ai_file_renamer
# Usage: ./ai_scan.sh <directory>
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

BACKUP_DIR="$DIR/Backup"
TEMP_DIR="$DIR/Temp"
LOG_FILE="$DIR/scan.log"
mkdir -p "$BACKUP_DIR" "$TEMP_DIR"


log() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
log "Processing directory: $DIR"


find "$DIR" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.jpg' -o -iname '*.png' \) | while read -r FILE; do
    log "Processing file: $FILE"
    
    OCR_TEXT=""
    log "Starting OCR..."
    
    if [[ "$FILE" == *.pdf ]]; then
        # Verbesserte PDF-Verarbeitung
        IMAGE="$TEMP_DIR/${FILE##*/}.png"
        if ! pdftoppm "$FILE" "$TEMP_DIR/${FILE##*/}" -png -f 1 -singlefile >/dev/null 2>&1; then
            log "Error: PDF to PNG conversion failed"
            continue
        fi
        if [ ! -f "$IMAGE" ]; then
            log "Error: PDF conversion did not produce image file"
            continue
        fi
        OCR_TEXT=$(/opt/homebrew/bin/tesseract "$IMAGE" - -l deu 2>/dev/null)
        # Erstelle OCR-PDF direkt vom Bild
        if ! /opt/homebrew/bin/tesseract "$IMAGE" "$TEMP_DIR/${FILE##*/}_ocr" -l deu pdf 2>/dev/null; then
            log "Error: OCR PDF creation failed"
            rm -f "$IMAGE"
            continue
        fi
        rm -f "$IMAGE"
    else
        # Direkte Bildverarbeitung
        if ! /opt/homebrew/bin/tesseract "$FILE" "$TEMP_DIR/${FILE##*/}_ocr" -l deu pdf 2>/dev/null; then
            log "Error: OCR PDF creation failed"
            continue
        fi
        OCR_TEXT=$(/opt/homebrew/bin/tesseract "$FILE" - -l deu 2>/dev/null)
    fi
    
    [ -z "$OCR_TEXT" ] && log "OCR failed! Skipping." && continue
    log "OCR completed successfully."
    
    MOD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$FILE")
    log "Extracting filename from OCR text..."
    
    # Fallback wenn kein KI-Server verfügbar ist
    if ! curl -s -m 1 http://localhost:1234 > /dev/null 2>&1; then
        log "KI-Server nicht erreichbar, verwende Standardbenennung"
        FILE_NAME_FROM_AI=$(echo "$FILE" | sed 's/.*\///' | sed 's/\.[^.]*$//')
        DATE_FROM_AI="$MOD_DATE"
        FOLDER_FROM_AI="Inbox"
    else
        # KI-Request wie bisher
        RESPONSE=$(curl -s -X POST http://localhost:1234/v1/chat/completions \
            -H "Content-Type: application/json" --data @- <<EOF
{
  "messages": [
    {
  "role": "system",
  "content": "### Human:\nDu bist ein KI-System, welches den OCR-Text eines Dokuments erhält und daraus einen sinnvollen Dateinamen generieren soll. Dieser Dateiname soll das Dokument in maximal 5 Wörtern zusammenfassen.\nBeachte bitte folgende Punkte:\n\n1. Erstelle im Feld FileName eine kurze Beschreibung des Dokuments und den Absender des Dokuments (Firma) mit maximal 5 Wörtern.\n  Erstelle im Feld Folder einen passenden Ordner. Es gibt folgende Ordner zur Auswahl: Arzt (Laborberichte, Medical, Arztberichte), Deutsche Post (z.B. Lohnabrechnungen der Deutschen Bahn), Haus oder Wohnung (Handwerkerrechnungen, Schornsteinfeger, Heizung, Wasser, BSR, Strom), GEZ (Rundfunkgebühren), Versicherung (Versicherungen wie Barmenia, HUK24, Allianz, BARMER, HUK, Ergo,ADAC), Kita/Schule, Steuer (Steuererklärungen) Wenn nichts in diese Kategorie passt, erstelle einen eigenen Ordner. Falls der Ordner noch nicht existiert, dann erstelle ihn. - Verwende nur Buchstaben (A-Z, a-z) oder Ziffern und ersetze Leerzeichen durch Unterstriche (_).\n   - Keine Sonderzeichen oder Umlaute.\n\n2. Versuche, ein relevantes Datum im Text zu finden (z. B. Rechnungsdatum). Falls du kein passendes Datum findest, verwende das mitgelieferte Änderungsdatum.\n   - Format: YYYY-MM-DD\n   - Ignoriere Daten, die offensichtlich nicht zum Dokumentzweck passen (z. B. Geburtsdaten).\n\nGib mir die Dateiinformationen nur als JSON zurück. Keine Markdown-Blöcke, keine zusätzlichen Zeichen, kein Fließtext. Beispiel: {\"FileName\": \"Dokument\", \"Date\": \"2025-01-01\", \"Message\": \"Alles gut\", \"Folder\": \"Arzt\"}\n### Assistant:"
},
{
  "role": "user",
  "content": "### Human:\nHier ist der Inhalt der Datei:\n$(sanitize_text "$OCR_TEXT")\n\nDas Änderungsdatum der Datei ist: $MOD_DATE\nBitte erstelle das JSON laut Anweisungen. Gib nur das JSON aus ohne den Denkvorgang auszugeben.\n### Assistant:"
}
 ],
  "temperature": 0,
  "max_tokens": 10000,
  "stream": false
}
EOF
        )
        # ...existing code for parsing AI response...
    fi

    if [ -z "$RESPONSE" ]; then
        log "Fehler: Keine Antwort von der KI erhalten!"
        continue
    fi

    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
    if [ $? -ne 0 ]; then
        log "Error: Failed to parse AI response"
        continue
    fi

    FILE_NAME_FROM_AI=$(echo "$CONTENT" | jq -r '.FileName' 2>/dev/null)
    DATE_FROM_AI=$(echo "$CONTENT" | jq -r '.Date' 2>/dev/null)
    MESSAGE_FROM_AI=$(echo "$CONTENT" | jq -c '.Message' 2>/dev/null)
    FOLDER_FROM_AI=$(echo "$CONTENT" | jq -r '.Folder' 2>/dev/null)

    if [ -z "$FILE_NAME_FROM_AI" ] || [ "$FILE_NAME_FROM_AI" == "null" ]; then
        log "Fehler: 'FileName' aus JSON ist leer/null. KI-Antwort:\n$CONTENT"
        continue
    fi

    if [ -z "$FOLDER_FROM_AI" ] || [ "$FOLDER_FROM_AI" == "null" ]; then
        log "Error: Invalid folder name from AI"
        continue
    fi

    if [ -z "$DATE_FROM_AI" ] || [ "$DATE_FROM_AI" == "null" ]; then
        DATE_FROM_AI="$MOD_DATE"
    fi

    CLEAN_FILENAME=$(echo "$FILE_NAME_FROM_AI" | sed 's/[^a-zA-Z0-9_]/_/g' | tr '[:space:]' '_' | tr -s '_')
    CLEAN_FILENAME=$(echo "$CLEAN_FILENAME" | sed 's/^_//;s/_$//') 

    LEN_CHECK=${#CLEAN_FILENAME}
    if [ "$LEN_CHECK" -gt 120 ]; then
        log "Fehler: KI-FileName hat mehr als 120 Zeichen. Überspringe Datei."
        continue
    fi

    NEW_FILENAME="$DIR/$FOLDER_FROM_AI/${DATE_FROM_AI}_${CLEAN_FILENAME}.pdf"
    
    mkdir -p "$DIR/$FOLDER_FROM_AI"
    
    # Prüfe ob die OCR-PDF existiert
    OCR_PDF="$TEMP_DIR/${FILE##*/}_ocr.pdf"
    if [ ! -f "$OCR_PDF" ]; then
        log "Error: OCR PDF file not found at $OCR_PDF"
        continue
    fi
    
    # Verschiebe die Datei
    if ! mv "$OCR_PDF" "$NEW_FILENAME"; then
        log "Error: Failed to move OCR PDF file to $NEW_FILENAME"
        continue
    fi
    
    log "Datei wurde umbenannt und verschoben:\n   Original: $FILE\n   Neu: $NEW_FILENAME"
    log "Zusatzinfo der KI (Message): $MESSAGE_FROM_AI"
    
    # Backup erstellen
    if ! mv "$FILE" "$BACKUP_DIR/"; then
        log "Error: Failed to create backup"
        continue
    fi
    log "Backup created successfully."
    log "--------------------------------------"
done

# Aufräumen
rm -rf "$TEMP_DIR"
log "Cleanup completed!"
