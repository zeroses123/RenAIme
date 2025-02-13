on adding folder items to this_folder after receiving added_items
	set folderPath to POSIX path of this_folder
	-- Ersetze den Pfad mit dem Pfad wo dein Script liegt.
	set scriptPath to quoted form of "/Users/your_username/Downloads/ai_scan.sh"
	do shell script "echo Testzugriff >> ~/scan_debug.log"
	-- Debug-Log schreiben, um zu überprüfen, ob das Skript gestartet wird
	do shell script "echo '[" & (do shell script "date") & "] AppleScript gestartet mit Ordner: " & folderPath & "' >> ~/scan_debug.log"
	
	-- Skript mit Ordnerpfad als Argument starten
	do shell script scriptPath & " " & quoted form of folderPath & " >> ~/scan_debug.log 2>&1"
	
	-- macOS-Benachrichtigung auslösen
	display notification "Das Shell-Skript wurde gestartet mit Folder: " & folderPath with title "Ordneraktion"
end adding folder items to
