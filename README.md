# PDF & Image OCR: Automatic Scanning, Renaming, and Organizing with AI

## Overview
This tool automatically detects new scanned PDFs (or images) in a specified folder, extracts text using **OCR (Optical Character Recognition)**, and intelligently renames each file based on its content. A **local LLM (Large Language Model)** then analyzes the extracted text to create meaningful filenames (including dates) and moves the files into appropriate destination folders.

Because the AI runs locally on your machine, no data is sent to external servers—helping ensure that sensitive information remains private.

---

## Key Features
✅ **Automatic File Detection** – Monitors a specified folder for new scanned PDFs or images.

✅ **OCR Processing** – Extracts text using Tesseract.

✅ **Local AI-Powered Renaming** – Uses an on-device LLM (Vicuna) for smart naming and classification.

✅ **Structured Organization** – Moves processed files to organized directories.

✅ **Privacy by Design** – All processing is done locally, preserving data confidentiality.

---
## How the script works
1. Your Scanner or you place PDF documents or images with random names in a specific folder.
2. Your Mac automatically detects the new document and runs an OCR on the document (OCR makes the document readable and searchable)
3. The OCR Text of the document is beeing sent to a local Large Language Model (LLM Vicuna 13B) via the LM Studio Local Server running on your localhost.
4. The prompt in the Script tells the LLM what folders it should use and what kind of documents should go into that folder. The prompt also tells the LLM to define a filename for the document including the date according to the content of the document.
5. The LLM returns a JSON to the Script including the filename and the folder.
6. The Script then moves the old document into a Backup Folder and copies the new Readable PDF-File into the folder the LLM chose
7. The Script also creates a TEMP-Folder for the temporary image-files it creates
8. It also creates a log-file in the same folder

---

## Installation Guide (macOS)

1. **Install Homebrew (if not already installed)**  
   Visit [brew.sh](https://brew.sh) and follow the instructions.

2. **Install Poppler via Terminal**  
   Poppler is a library for processing PDFs. Install it via:
   ```bash
   brew install poppler
   ```

3. **Install Tesseract via Terminal**  
   Tesseract is an OCR engine that extracts text from images and PDFs:
   ```bash
   brew install tesseract
   ```

4. **Install Additional Language Packs (Optional)**  
   For better recognition in languages like German or Spanish, install the relevant packs:
   ```bash
   brew install tesseract-lang
   ```
   See [this link](https://github.com/tesseract-ocr/tesseract/blob/main/doc/tesseract.1.asc#languages) for more details.

5. **Install LM Studio**  
   Download and install [LM Studio](https://lmstudio.ai), which is needed to run the local AI model.

6. **Download the Vicuna LLM Model**  
   Download the Vicuna LLM 13B Modell here: [Vicuna 13B v1.5 16K model](https://huggingface.co/TheBloke/vicuna-13B-v1.5-16K-GGUF/blob/main/vicuna-13b-v1.5-16k.Q4_K_M.gguf).

7. **Place the Model in the Correct Directory**  
   Copy the model file to:  
   ```
   /Users/<your_username>/.lmstudio/models
   ```  
   *(Replace `<your_username>` with your actual username.)*

8. **Load the Vicuna Model in LM Studio**  
   - Open LM Studio.  
   - Click **Developer** on the left side.  
   - Load your Vicuna model.  
   - Start the **Local Server** from within LM Studio.

9. **Test the Script**  
   Open Terminal and run:  
   ```bash
   ./ai_scan.sh ./
   ```

10. **Check Poppler and Tesseract Locations**  
   In Terminal, run:  
   ```bash
   which pdftoppm
   which tesseract
   ```  
   Update these paths in the **ai_scan.sh** script if necessary.

11. **Edit the AppleScript for Folder Actions**  
   - Open **Folder_Rename_AI.scpt** from the repository.  
   - Replace the path to your `ai_scan.sh` file.  
   - Copy **Folder_Rename_AI.scpt** to:  
     ```
     /Library/Scripts/Folder Action Scripts/
     ```

12. **Assign the Script to a Folder**  
   - Right-click the target folder.  
   - Go to **Services** → **Folder Actions Setup...**  
   - In the **Folder Actions** window, click the “+” button to add the **Folder_Rename_AI** script to that folder.

That’s it! 🎉 Your local AI-powered OCR pipeline is now ready, ensuring that everything—scanning, text extraction, and renaming—stays secure on your own machine. Enjoy your automated workflow!

## What to edit in the ai_scan.sh file

- Edit the prompt to fit your need
- It might be that your installation of tesseract and poppler is in a different directory. Adjust the 3 lines to your Directory where brew installed it.

## Issues
- Error on big PDF-Files
- 
