# PDF & Image OCR: Automatic Scanning, Renaming, and Organizing with AI on MacOS

## Overview
This tool automatically detects new scanned PDFs (or images) in a specified folder, extracts text using **OCR (Optical Character Recognition)**, and intelligently renames each file based on its content. A **local LLM (Large Language Model)** then analyzes the extracted text to create meaningful filenames (including dates) and moves the files into appropriate destination folders.

Because the AI runs locally on your machine, no data is sent to external servers—helping ensure that sensitive information remains private.

---

## Hardware Requirements
✅ **16 GB RAM** (LLM Model is about 8 GB large and loaded into the RAM)
✅ **Apple Macbook, iMac ...**

## Key Features
✅ **Automatic File Detection** – Monitors a specified folder for new scanned PDFs or images.

✅ **OCR Processing** – Extracts text using Tesseract.

✅ **Local AI-Powered Renaming** – Uses an on-device LLM (Mistral-Nemo) for smart naming and classification.

✅ **Structured Organization** – Moves processed OCR - files to organized directories.

✅ **Privacy by Design** – All processing is done locally, preserving data confidentiality.

---
## How the script works
1. Your Scanner or you place PDF documents or images with random names in a specific folder.
2. Your Mac automatically detects the new document and runs an OCR on the document (OCR makes the document readable and searchable)
3. The OCR Text of the document is beeing sent to a local Large Language Model via the LM Studio Local Server running on your localhost.
4. The prompt in the Script tells the LLM what folders it should use and what kind of documents should go into that folder. The prompt also tells the LLM to define a filename for the document including the date according to the content of the document.
5. The LLM returns a JSON to the Script including the filename and the folder.
6. The Script then moves the old document into a Backup Folder and copies the new Readable PDF-File into the folder the LLM chose
7. The Script also creates a TEMP-Folder for the temporary image-files it creates
8. It also creates a log-file in the same folder

---

## Installation Guide (macOS)
1. **Install Homebrew (if not already installed)**  
   Visit [brew.sh](https://brew.sh) and follow the instructions.

2. **Install Poppler, Tesseract, jq and curl via Terminal**  
   Poppler is a library for processing PDFs. Tesseract is an OCR engine that extracts text from images and PDFs. Tesseract Lang is for better recognition in languages like German or Spanish. Jq and curl should already be installed. 
   ```bash
   brew install poppler tesseract tesseract-lang jq curl 
   ```

3. **Install LM Studio**  
   Download and install [LM Studio](https://lmstudio.ai), which is needed to run the local AI model.

4. **Download the Mistral-Nemo-Instruct-2407**  
   In LM Studio click "Explore" and Search for the "Mistral-Nemo-Instruct-2407" Model and download it. 

5. **Load the installed Model in LM Studio**  
   - Open LM Studio.  
   - Click **Developer** on the left side.  
   - On Top of the Window, Load your Mistral Nemo model.  
   - Start the **Local Server** from within LM Studio. (Click on "Status Stopped running" and make sure it is green and running)
   - LM Studio now waits for incoming Requests from your Script

7. **Check Poppler and Tesseract Locations**  
   In Terminal, run:  
   ```bash
   which pdftoppm
   which tesseract
   ```  
   Update these lines of code in the **ai_scan.sh** script if necessary:
    ```bash
      PDFTOPPM="/opt/homebrew/bin/pdftoppm"     
      TESSERACT="/opt/homebrew/bin/tesseract"
    ```  

9. **Copy Files from the Repository & Edit the AppleScript for Folder Actions**  
   - Open **Folder_Rename_AI.scpt** from the repository on your computer with a text editor.  
   - Download the **ai_scan.sh** File into your Documents Folder.
   - Make the File Executable by opening your Terminal and Running ``` chmod +x ~/Documents/ai_scan.sh ```
   - If you want to place it somewhere else you need to delete this line in the **Folder_Rename_AI.scpt**:
     ```bash
        set scriptPath to quoted form of (homeFolder & "Documents/scan.sh")
     ```
     and uncomment the line
     ```bash
        set scriptPath to quoted form of "YOUR/FiLEPATH/Goes_here/ai_scan.sh" -- Unquote this line if you want to set an absolute path to your Script
     ```
     and of course run the ``` chmod +x YOUR/NEW_FILEPATH/ai_scan.sh ```
   - to Copy a Filepath of a File in Finder, right click on the ai_scan.sh file and Hold the ⌥ option Key. Click on Copy Filepath.
   - Open the /Library/Scripts/Folder Action Scripts/ Folder by opening Finder and pressing **⌘ Cmd** + **⇧ Shift** + **G** and enter the Folder path /Library/Scripts/Folder Action Scripts/
   - Copy the **Folder_Rename_AI.scpt** to that Folder:  
     ```
     /Library/Scripts/Folder Action Scripts/
     ```

10. **Let's build the Automation, whenever a new file has been edited or copied --> Run the Script**  
   - Right-click the target folder in Finder.  
   - Go to **Services** → **Folder Actions Setup...**  
   - In the **Folder Actions** window, click the “+” button to add the **Folder_Rename_AI** script to that folder.

That’s it! 🎉 Your local AI-powered OCR pipeline is now ready, ensuring that everything—scanning, text extraction, and renaming—stays secure on your own machine. Enjoy your automated workflow!

## What to edit in the ai_scan.sh file

- Edit the prompt to fit your need. 
- It might be that your installation of tesseract and poppler is in a different directory. Adjust the 3 lines to your Directory where brew installed it.

## Issues
- Error on huge PDF-Files
- After a Computer Restart the LM-Model needs to be loaded again in LM-Studio
