# calibre-collections.koplugin

## Installation

1. Connect your e-reader via USB (or use Wi-Fi file transfer)
2. Navigate to the KOReader plugins folder:
   - Kindle: `/mnt/us/koreader/plugins/`
   - Kobo: `.kobo/koreader/plugins/`
   - Android: `/sdcard/koreader/plugins/`
   - PocketBook: `applications/koreader/plugins/`
3. Copy the entire `calibre-collections.koplugin` folder there
4. Restart KOReader

## Usage

After restart, navigate to: `☰ Menu → More Tools → Calibre Collections`

### Options

- **Sync now** — adds new books/tags, never removes anything
- **Full rebuild** — wipes previously synced collections, then rebuilds fresh

## How it works

1. Reads your home directory (set in KOReader's File Manager)
2. Recursively searches for `metadata.calibre` files (created when syncing with Calibre via USB or Wi-Fi)
3. Reads Calibre tags for each book
4. Creates a KOReader collection for each tag
5. Adds each book to its matching collection(s)
