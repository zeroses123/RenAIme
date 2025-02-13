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
        IMAGE="$TEMP_DIR/${FILE##*/}.png"
        /usr/local/bin/pdftoppm "$FILE" "$TEMP_DIR/${FILE##*/}" -png -f 1 -singlefile >/dev/null 2>&1
        [ -f "$IMAGE" ] && OCR_TEXT=$(/usr/local/bin/tesseract "$IMAGE" - -l deu 2>/dev/null) && rm "$IMAGE"
    else
        /usr/local/bin/tesseract "$FILE" "$TEMP_DIR/${FILE##*/}_ocr" -l deu pdf 2>/dev/null
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

if [ -z "$RESPONSE" ]; then
    log "Fehler: Keine Antwort von der KI erhalten!"
    continue
fi

CONTENT=$(echo "$RESPONSE" | sed -e 's/^json//' -e 's/^//' -e 's/`$//')


CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
FILE_NAME_FROM_AI=$(echo "$CONTENT" | jq -r '.FileName' 2>/dev/null)
DATE_FROM_AI=$(echo "$CONTENT" | jq -r '.Date' 2>/dev/null)
MESSAGE_FROM_AI=$(echo "$CONTENT" | jq -c '.Message' 2>/dev/null)
FOLDER_FROM_AI=$(echo "$CONTENT" | jq -r '.Folder' 2>/dev/null)

if [ -z "$FILE_NAME_FROM_AI" ] || [ "$FILE_NAME_FROM_AI" == "null" ]; then
    log "Fehler: 'FileName' aus JSON ist leer/null. KI-Antwort:\n$CONTENT"
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

    NEW_FILENAME="$DIR/$FOLDER_FROM_AI/${CLEAN_FILENAME}_${DATE_FROM_AI}.pdf"

    mkdir -p "$DIR/$FOLDER_FROM_AI"
    log "$FILE"
    if [[ "$FILE" == *.pdf ]]; then
        pdftk "$TEMP_DIR/${FILE##*/}_ocr.pdf" cat output "$NEW_FILENAME"
        mv "$TEMP_DIR/${FILE##*/}_ocr.pdf" "$NEW_FILENAME"
        log "File $NEW_FILENAME created successfully"
    else
        if [ -f "$TEMP_DIR/${FILE##*/}_ocr.pdf" ]; then
            mv "$TEMP_DIR/${FILE##*/}_ocr.pdf" "$NEW_FILENAME"
            log "File renamed and moved:\n   Original: $FILE\n   Neu: $NEW_FILENAME"
            log "Additional Info from AI: $MESSAGE_FROM_AI"
        else
            log "Error: File $TEMP_DIR/${FILE##*/}_ocr.pdf already exists!"
            continue
        fi
    fi

    mv "$FILE" "$BACKUP_DIR/"
    log "Backup created."
    log "--------------------------------------"
done

rm -rf "$TEMP_DIR"
log "Cleanup completed!"
