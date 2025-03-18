on adding folder items to this_folder after receiving added_items
    -- Setze PATH Umgebungsvariable explizit
    set folderPath to POSIX path of this_folder
	set homeFolder to POSIX path of (path to home folder)
	set scriptPath to quoted form of (homeFolder & "Documents/ai_scan.sh")
    -- set scriptPath to quoted form of "YOUR/FiLEPATH/Goes_here/ai_scan.sh" -- Unquote this line if you want to set an absolute path to your Script
    
    -- Erstelle einen temporären Shell-Script für die Umgebungseinrichtung
    set tempScript to (POSIX path of (path to temporary items as text)) & "run_scan.sh"
    do shell script "echo '#!/bin/bash' > " & quoted form of tempScript
    do shell script "echo 'export PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> " & quoted form of tempScript
    do shell script "echo " & scriptPath & " " & quoted form of folderPath & " >> " & quoted form of tempScript
    do shell script "chmod +x " & quoted form of tempScript
    
    -- Führe das temporäre Script aus
    try
        do shell script quoted form of tempScript
        -- Debug-Log schreiben
        do shell script "echo '[$(date)] AppleScript erfolgreich ausgeführt für Ordner: " & folderPath & "' >> ~/scan_debug.log"
    on error errMsg
        -- Fehler loggen
        do shell script "echo '[$(date)] Fehler beim Ausführen des Scripts: " & errMsg & "' >> ~/scan_debug.log"
    end try
    
    -- Aufräumen
    do shell script "rm -f " & quoted form of tempScript
    
    -- Benachrichtigung anzeigen
    display notification "Das Shell-Skript wurde ausgeführt für Ordner: " & folderPath with title "Ordneraktion"
end adding folder items to
