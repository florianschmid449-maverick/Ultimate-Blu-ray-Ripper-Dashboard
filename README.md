# Ultimate Blu-ray Ripper Dashboard

A high-visibility, automated Bash tool for archiving optical media. This script distinguishes itself with a color-coded terminal interface that provides real-time feedback on rip speed, estimated time of arrival (ETA), and retry attempts, while maintaining robust error recovery and automatic file splitting.

## 🚀 Features

* **Visual Dashboard:** Features a color-coded interface (Cyan, Yellow, Green, Red) to clearly indicate status, warnings, and success.
* **Real-Time Statistics:** Calculates and displays current progress percentage, rip speed (MB/s), and ETA (seconds) directly in the terminal.
* **Smart Space Management:** Automatically checks available disk space on the Desktop before starting to prevent incomplete rips.
* **Large File Handling:**
* **Auto-Split:** Automatically splits Blu-ray rips larger than 25GB into 4GB chunks for compatibility with FAT32 drives or cloud storage limits.
* **Post-Split Verification:** Verifies individual split parts after processing.


* **Resumable & Robust:** Uses `ddrescue` with a retry loop (default 3 retries) to handle scratched or damaged discs.
* **Master Logging:** Appends all session data (timestamps, filenames, SHA256 checksums) to `disc_rip_master_log.csv`.

## 📋 Prerequisites

The script automatically checks for dependencies. If they are missing, it attempts to install them via `apt` (requires `sudo`).

* **gddrescue:** For data recovery and copying.
* **pv:** Used to pipe data and calculate progress metrics.

Manual installation (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install gddrescue pv

```

## 📥 Installation

1. Download the script to your machine.
2. Grant execution permissions:

```bash
chmod +x "Ultimate Blu-ray Ripper Dashboard.sh"

```

## 🖥️ Usage

1. **Insert Disc:** Place your DVD or Blu-ray into the drive.
2. **Run Script:**
```bash
./"Ultimate Blu-ray Ripper Dashboard.sh"

```


3. **Monitor:** The dashboard will display the detected drive and begin the rip.
* **Cyan:** General status and progress.
* **Yellow:** Retries and active processing.
* **Green:** Successful completion.
* **Red:** Critical errors (e.g., "Not enough space").


4. **Completion:** The disc will automatically eject upon completion, and the script waits for the next disc.
5. **Stop:** Press `Ctrl+C` to safely exit. The script traps the signal and displays a session summary.

## 📂 Output

Files are saved to `$HOME/Desktop`:

* **Standard Discs:** `disc_rip_YYYYMMDD_HHMMSS.iso`
* **Large Blu-rays:** Split into `_partaa`, `_partab`, etc.
* **Logs:** `disc_rip_master_log.csv` (CSV History) and individual `.log` mapfiles for `ddrescue`.

## 👤 Author

**Florian Schmid**

## ⚖️ License

**No License**

This project is released with no specific license attached. All rights are reserved by the author unless otherwise noted.
