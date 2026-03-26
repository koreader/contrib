# Luminaria Sync — KOReader Plugin

A KOReader plugin that syncs your highlights directly to [Luminaria](https://luminaria.uk) — a free, private web app for browsing your reading highlights beautifully.

> Export your highlights from KOReader with one tap. Open Luminaria in any browser and they're there.

## What is Luminaria?

[Luminaria](https://luminaria.uk) is a free web app where you can browse all your KOReader highlights organised by book. It features full-text search across every passage you've ever marked, a rotating quote from your library on the homepage, favourites, and copy to clipboard. Everything is stored privately in your own browser — no accounts, no tracking.

## Requirements

- A Kobo device running KOReader
- A free Luminaria sync token — get one at [luminaria.uk/signup.html](https://luminaria.uk/signup.html)

## Installation

1. **Download the plugin files**
   - `main.lua`
   - `_meta.lua`

2. **Connect your Kobo** to your computer via USB

3. **Create the plugin folder**
   Navigate to `koreader/plugins/` on your Kobo and create a new folder named:
   ```
   luminaria.koplugin
   ```

4. **Copy both files** into the `luminaria.koplugin` folder

5. **Safely eject** your Kobo and restart KOReader fully (hold power → restart)

6. **Enable the plugin** — go to:
   ```
   Menu → ⋮ More → Plugin Management → Luminaria Sync → Enable
   ```

## Setup

1. Get your free sync token at [luminaria.uk/signup.html](https://luminaria.uk/signup.html)
2. In KOReader go to **Menu → ⋮ More → Luminaria Sync → Settings**
3. Paste your token and tap **Save**

## Syncing your highlights

1. **Turn on WiFi** — go to:
   ```
   Menu → ⋮ More → Network → Enable WiFi
   ```
   Make sure your Kobo is connected before syncing.

2. **Export your highlights** in KOReader:
   **Top menu → Search → Export all highlights**
   *(This saves a .md file to the clipboard folder on your device)*

3. **Sync to Luminaria:**
   **Menu → ⋮ More → Luminaria Sync → Sync highlights now**

4. Open [luminaria.uk](https://luminaria.uk) in your browser, enter your token via **Enter token**, then tap **↻ Sync from KOReader**

Your highlights will appear instantly, organised by book.

## Troubleshooting

**Plugin not appearing in the menu**
Make sure the folder is named exactly `luminaria.koplugin` and contains both `main.lua` and `_meta.lua`. Do a full restart of KOReader.

**No highlights export file found**
Make sure you have run Export all highlights in KOReader before syncing. The plugin looks for the latest `.md` file in your clipboard folder.

**Sync failed — network error**
Make sure WiFi is enabled and your Kobo is connected to a network before syncing. Go to **Menu → ⋮ More → Network → Enable WiFi**.

**Sync failed — invalid token**
Double-check your token was copied correctly from the registration email with no extra spaces. You can re-enter it in **Menu → Luminaria Sync → Settings**.

**Token not received**
Check your spam folder. You can request it to be resent by entering your email again at [luminaria.uk/signup.html](https://luminaria.uk/signup.html).

## License

MIT License — see LICENSE file for details.

---

Made by [James](https://buymeacoffee.com/jamesisonfire) · [luminaria.uk](https://luminaria.uk)