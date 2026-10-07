--[[--
Calibre Collections plugin for KOReader.

Scans for Calibre metadata files (metadata.calibre) on the device,
reads each book's tags, and creates matching KOReader collections,
adding each book to its corresponding collection(s).

@module koplugin.calibrecollections
--]]--

local ConfirmBox      = require("ui/widget/confirmbox")
local DataStorage     = require("datastorage")
local Dispatcher      = require("dispatcher")
local InfoMessage     = require("ui/widget/infomessage")
local LuaSettings     = require("luasettings")
local ReadCollection  = require("readcollection")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs             = require("libs/libkoreader-lfs")
local logger          = require("logger")
local rapidjson       = require("rapidjson")
local _               = require("gettext")

-- Path where we store the list of collections we have previously created,
-- so that "full rebuild" knows which ones to remove.
local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/calibre_collections.lua"

-- Device roots to search when the Calibre library lives outside home_dir.
-- We search ALL of these plus the configured home_dir.
local SEARCH_ROOTS = {
    "/mnt/us",          -- Kindle internal
    "/mnt/us/documents",
    "/sdcard",          -- Android / generic
    "/sdcard/Books",
    "/mnt/sdcard",
    "/mnt/extSdCard",
    "/mnt/onboard",     -- Kobo internal
    "/mnt/sd",          -- Kobo SD card
    "/storage/emulated/0",
    "/storage/sdcard0",
    "/storage/sdcard1",
}

local CalibreCollections = WidgetContainer:extend{
    name        = "calibrecollections",
    is_doc_only = false,
}

-- ── Dispatcher ───────────────────────────────────────────────────────────────

function CalibreCollections:onDispatcherRegisterActions()
    Dispatcher:registerAction("calibre_collections_sync", {
        category = "none",
        event    = "CalibreCollectionsSync",
        title    = _("Sync Calibre tags to collections"),
        general  = true,
    })
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function CalibreCollections:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

-- ── Main-menu entry ──────────────────────────────────────────────────────────

function CalibreCollections:addToMainMenu(menu_items)
    menu_items.calibre_collections = {
        text         = _("Calibre Collections"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text      = _("Sync now"),
                help_text = _("Add new books/tags from Calibre without removing existing collections."),
                callback  = function() self:syncNow(false) end,
            },
            {
                text      = _("Full rebuild"),
                help_text = _("Remove all previously synced collections, then recreate them fresh."),
                callback  = function()
                    UIManager:show(ConfirmBox:new{
                        text = _("Remove all previously synced collections and rebuild from Calibre metadata?\n\nCollections you created manually will not be touched."),
                        ok_text     = _("Rebuild"),
                        ok_callback = function() self:syncNow(true) end,
                    })
                end,
            },
        },
    }
end

function CalibreCollections:onCalibreCollectionsSync()
    self:syncNow(false)
end

-- ── Settings helpers ─────────────────────────────────────────────────────────

function CalibreCollections:loadSyncedNames()
    local s    = LuaSettings:open(SETTINGS_FILE)
    local list = s:readSetting("synced_collections") or {}
    local set  = {}
    for _, name in ipairs(list) do set[name] = true end
    return set
end

function CalibreCollections:saveSyncedNames(set)
    local s    = LuaSettings:open(SETTINGS_FILE)
    local list = {}
    for name in pairs(set) do table.insert(list, name) end
    s:saveSetting("synced_collections", list)
    s:flush()
end

-- ── Filesystem helpers ───────────────────────────────────────────────────────

-- Safe lfs.attributes wrapper – returns nil instead of erroring.
local function fileAttr(path, field)
    local ok, result = pcall(lfs.attributes, path, field)
    if ok then return result end
end

-- Returns true if `path` is an existing regular file.
local function fileExists(path)
    return fileAttr(path, "mode") == "file"
end

-- Returns true if `path` is an existing directory.
local function dirExists(path)
    return fileAttr(path, "mode") == "directory"
end

-- ── Calibre metadata discovery ───────────────────────────────────────────────

--[[
Recursively walk `dir` looking for "metadata.calibre" / ".metadata.calibre".
Each match represents one Calibre library root.
Returns a list of { meta_path, library_root }.
--]]
function CalibreCollections:findCalibreLibraries(dir, results, depth, visited)
    results = results or {}
    depth   = depth   or 0
    visited = visited or {}

    if depth > 6 then return results end
    if not dirExists(dir) then return results end

    -- Resolve symlinks to avoid infinite loops.
    local real = fileAttr(dir, "dev") .. ":" .. fileAttr(dir, "ino")
    if real and visited[real] then return results end
    if real then visited[real] = true end

    local ok, iter, state = pcall(lfs.dir, dir)
    if not ok or not iter then return results end

    for entry in iter, state do
        if entry ~= "." and entry ~= ".." then
            local full = dir .. "/" .. entry
            local mode = fileAttr(full, "mode")
            if mode == "file"
               and (entry == "metadata.calibre" or entry == ".metadata.calibre") then
                logger.info("CalibreCollections: found library at", dir)
                table.insert(results, { meta_path = full, library_root = dir })
            elseif mode == "directory" then
                -- Skip hidden dirs and known system dirs to stay fast.
                local skip = entry:sub(1,1) == "." or entry == "System" or entry == "lost+found"
                if not skip then
                    self:findCalibreLibraries(full, results, depth + 1, visited)
                end
            end
        end
    end
    return results
end

-- Build a deduplicated list of directories to scan.
function CalibreCollections:buildSearchRoots()
    local seen  = {}
    local roots = {}

    local function add(dir)
        if dir and dir ~= "" and not seen[dir] then
            seen[dir] = true
            table.insert(roots, dir)
        end
    end

    -- Always include the configured home dir.
    local home = G_reader_settings:readSetting("home_dir")
    add(home)

    -- Also try the *parent* of home_dir — Calibre often puts metadata.calibre
    -- one level above where the books folder lives.
    if home then
        local parent = home:match("^(.*)/[^/]+$")
        add(parent)
    end

    -- Add all known device mount points.
    for _, root in ipairs(SEARCH_ROOTS) do add(root) end

    return roots
end

-- ── JSON loading ─────────────────────────────────────────────────────────────

function CalibreCollections:loadMetadata(path)
    -- Prefer KOReader's Calibre-aware JSON loader.
    if type(rapidjson.load_calibre) == "function" then
        local ok, result = pcall(rapidjson.load_calibre, path)
        if ok and result then return result end
    end
    -- Fall back to standard JSON loader.
    local ok, result = pcall(rapidjson.load, path)
    if ok and result then return result end
    logger.warn("CalibreCollections: failed to parse", path)
    return nil
end

-- ── Core sync ────────────────────────────────────────────────────────────────

function CalibreCollections:syncNow(rebuild)
    -- 1. Search all candidate roots for Calibre libraries.
    local roots     = self:buildSearchRoots()
    local libraries = {}
    local visited   = {}

    for _, root in ipairs(roots) do
        self:findCalibreLibraries(root, libraries, 0, visited)
    end

    if #libraries == 0 then
        local roots_str = table.concat(roots, "\n  ")
        UIManager:show(InfoMessage:new{
            text = _("No Calibre metadata found.\n\nSearched:\n  ") .. roots_str
                .. _("\n\nMake sure you have synced your device with Calibre (USB or Wi-Fi) at least once."),
        })
        return
    end

    -- 2. Optionally remove previously synced collections (full rebuild).
    local previously_synced = self:loadSyncedNames()
    if rebuild and next(previously_synced) then
        local dirty = {}
        for name in pairs(previously_synced) do
            if ReadCollection.coll and ReadCollection.coll[name] then
                ReadCollection:removeCollection(name)
                dirty[name] = true
            end
        end
        if next(dirty) then ReadCollection:write(dirty) end
        previously_synced = {}
    end

    -- 3. Process every library.
    local books_added      = 0
    local new_collections  = {}
    local dirty_collections = {}

    for _, lib in ipairs(libraries) do
        local books = self:loadMetadata(lib.meta_path)
        if type(books) == "table" then
            for _, book in ipairs(books) do
                -- Guard: must have a valid relative path and a tags list.
                if type(book.lpath) == "string" and book.lpath ~= ""
                   and type(book.tags) == "table" then

                    local file_path = lib.library_root .. "/" .. book.lpath

                    -- Only touch files that are actually present on the device.
                    if fileExists(file_path) then
                        for _, tag in ipairs(book.tags) do
                            if type(tag) == "string" and tag ~= "" then

                                -- Create collection if needed.
                                local coll_exists = ReadCollection.coll
                                                    and ReadCollection.coll[tag]
                                if not coll_exists then
                                    local ok, err = pcall(ReadCollection.addCollection,
                                                          ReadCollection, tag)
                                    if ok then
                                        new_collections[tag]    = true
                                        dirty_collections[tag]  = true
                                    else
                                        logger.warn("CalibreCollections: addCollection failed for",
                                                    tag, err)
                                    end
                                end

                                -- Add book to collection if not already there.
                                local already = false
                                if ReadCollection.coll and ReadCollection.coll[tag] then
                                    local ok2, result = pcall(
                                        ReadCollection.isFileInCollection,
                                        ReadCollection, file_path, tag)
                                    already = ok2 and result
                                end

                                if not already then
                                    local ok3, err3 = pcall(ReadCollection.addItem,
                                                            ReadCollection, file_path, tag)
                                    if ok3 then
                                        dirty_collections[tag] = true
                                        books_added = books_added + 1
                                    else
                                        logger.warn("CalibreCollections: addItem failed",
                                                    file_path, tag, err3)
                                    end
                                end

                            end
                        end
                    end
                end
            end
        end
    end

    -- 4. Flush to disk.
    if next(dirty_collections) then
        local ok, err = pcall(ReadCollection.write, ReadCollection, dirty_collections)
        if not ok then
            logger.err("CalibreCollections: write failed", err)
        end
    end

    -- 5. Persist names of synced collections.
    for name in pairs(new_collections) do previously_synced[name] = true end
    self:saveSyncedNames(previously_synced)

    -- 6. Summary message.
    local num_new = 0
    for _ in pairs(new_collections) do num_new = num_new + 1 end

    UIManager:show(InfoMessage:new{
        text = string.format(
            _("Sync complete!\n\n• %d book entries added\n• %d new collection(s) created\n• Found %d Calibre librar%s"),
            books_added, num_new, #libraries, #libraries == 1 and "y" or "ies"
        ),
        timeout = 8,
    })
end

return CalibreCollections
