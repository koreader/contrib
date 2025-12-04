# A KOReader plugin for Readwise and Readwise Reader
A simple plugin for KOReader integration with the highlight saving and read later services Readwise and Readwise Reader. A Readwise subscription is required. 

## Key features:
- Articles in Readwise Reader saved to “Inbox”, “Later” or “Shortlist” are downloaded to KOReader as HTML files.
- Images are downloaded where this is possible.
- Articles which have been read in KOReader and marked as “finished” will be moved to the Readwise Reader Archive at the next sync, and deleted from KOReader.
- At sync, articles which have been archived in Readwise Reader will be deleted from KOReader.
- Particular types of article, locations and document tags can be excluded from syncing in the settings menu.
- The number of articles downloaded per sync can be limited in the settings menu (default: unlimited).
- Highlights and notes that are saved in KOReader are exported to Readwise in the same sync process (disabled by default - enable in the settings menu). 
- Very image heavy files will download, but may cause KOReader to crash if the file is very large. Due to the way images are saved and the limitations of HTML files, this is more of an issue than with EPUBs. To mitigate this, there is a setting to allow the user to cap the size of a file, after which further images are not downloaded. This is set to 10MB by default, but may be changed according to the limits of the user’s setup. There is also a toggle to turn off image downloads completely if required.

## Limitations and Known Issues:
- Unfortunately two way highlight syncing is not possible as the Readwise Reader API does not provide the location data required by KOReader.
- I am not planning to add any options to style the documents. However there are lots of tweaks you can apply as a user - see [here](https://koreader.rocks/user_guide/#L1-customizingappearance). 

## Installation:
- Download the ZIP file of the plugin [here](https://github.com/tomtom800/readwisereader/archive/refs/heads/main.zip). Extract it.
- Attach your ereader to your computer. Copy the `readwisereader.koplugin` folder containing _meta.lua and main.lua from the extracted folder to the `koreader/plugins` folder. Restart KOReader.
- The plugin requires a Readwise access token, which subscribers can obtain  [here](https://readwise.io/access_token). 
- The token can be typed in manually in the Readwise Reader/Settings/Configure Readwise Reader menu, but this is difficult to do correctly. The letter O and the number 0, are easily confused as are the lowercase letter l, the uppercase letter I and the numeral 1. If the plugin is not working, check this first.
- You may prefer to copy and paste the access token directly from your computer into KOReader settings. To do this, first set the folder you want to download to in the Readwise Reader/Settings/Download folder menu. This will create the file koreader/settings/readwisereader.lua. Add the access token to this file in the following format:

```
-- ./settings/readwisereader.lua
return {
    ["readwisereader"] = {
        ["access_token"] = "{access token}",
        ["available_locations"] = {},
        ["available_tags"] = {},
        ["directory"] = "{download location}",
        ["document_categories"] = {},
        ["document_locations"] = {},
        ["document_tags"] = {},
        ["excluded_locations"] = {},
        ["excluded_tags"] = {},
        ["max_articles_to_download"] = 0,  -- 0 = unlimited
    },
}
```
- The extension is then activated by selecting “Sync” in the Readwise Reader menu.
- By default, the extension will be added to the file menu with the prefix NEW:. The plugin will work in this format, but to remove the NEW: prefix and to move it to a different menu, add a line for  `"readwisereader",` in the appropriate place in koreader/frontend/ui/elements/filemanager_menu_order.lua
