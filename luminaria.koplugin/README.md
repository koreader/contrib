# Luminaria Sync — KOReader Plugin

Sync your KOReader highlights to [Luminaria](https://luminaria.uk) — a private, beautiful web app for browsing your reading highlights by book, with full-text search, favourites, and share-as-image.

---

## What it does

- **Manual sync** — tap *Sync highlights now* in the menu and your highlights upload to Luminaria in seconds
- **Auto-sync on WiFi** *(paid feature)* — when your Kobo connects to WiFi, the plugin automatically exports all your highlights and syncs them to Luminaria. No tapping required

---

## Installation

1. Download this repository as a ZIP
2. On your Kobo, navigate to:
   ```
   mnt/onboard/.adds/koreader/plugins/
   ```
3. Create a folder called `luminaria.koplugin`
4. Copy `main.lua` and `_meta.lua` into the folder
5. Restart KOReader fully

The plugin will appear under **Menu → Tools → Luminaria Sync**.

---

## Setup

1. Get a sync token at [luminaria.uk/signup.html](https://luminaria.uk/signup.html)
2. In KOReader go to **Menu → Tools → Luminaria Sync → Settings**
3. Paste your token into the Upload Token field
4. Tap **Save**

---

## Syncing your highlights

### Manual sync (included)

Tap **Menu → Tools → Luminaria Sync → Sync highlights now**

The plugin will export all highlights from your reading history and upload them to your Luminaria account. You'll see status messages throughout:

- *Exporting highlights…*
- *Syncing N highlights from N books…*
- *✓ Synced!*

### Auto-sync on WiFi (paid — £2.99/month)

With an active subscription, every time your Kobo connects to WiFi the plugin automatically exports and syncs your highlights in the background.

To enable: subscribe at [luminaria.uk/upgrade.html](https://luminaria.uk/upgrade.html), then toggle **Auto-sync on WiFi** in the plugin menu.

To cancel or manage your subscription: visit [luminaria.uk/upgrade.html](https://luminaria.uk/upgrade.html) and use the *Manage subscription* section.

---

## Viewing your highlights

1. Open [luminaria.uk](https://luminaria.uk) in any browser
2. Enter your token when prompted
3. Tap **↻ Sync from KOReader**

Your highlights appear organised by book, with full-text search, favourites, and the ability to share any passage as a beautifully designed image card.

If you have auto-sync enabled, Luminaria detects new syncs automatically and updates without you needing to do anything.

---

## Menu options

| Option | Description |
|--------|-------------|
| Sync highlights now | Manually export and sync all highlights |
| Auto-sync on WiFi | Toggle automatic sync on WiFi connect (paid) |
| Settings | Configure your token and export folder |
| About | Plugin info and links |

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Upload Token | *(empty)* | Your personal token from luminaria.uk |
| Highlights export folder | `/mnt/onboard/.adds/koreader/clipboard/` | Where exported .md files are saved |
| Auto-sync on WiFi | true | Whether to auto-sync when WiFi connects |

---

## Supported devices

Tested on Kobo Libra with KOReader. Should work on any Kobo device running KOReader. May also work on Kindle and other devices running KOReader but has not been tested.

---

## Links

- [Luminaria](https://luminaria.uk)
- [Get a sync token](https://luminaria.uk/signup.html)
- [Upgrade for auto-sync](https://luminaria.uk/upgrade.html)
- [KOReader](https://koreader.rocks)
