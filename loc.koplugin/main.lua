--[[
    Library of Congress Digital Collections Plugin for KOReader
    
    This plugin allows searching and downloading EPUBs from the Library of Congress
    Digital Collections directly from your e-reader.
]]

local BD = require("ui/bidi")
local ButtonDialog = require("ui/widget/buttondialog")
local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local LuaSettings = require("luasettings")
local Menu = require("ui/widget/menu")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")
local T = require("ffi/util").template

-- Import API helper
local LocApi = require("locapi")

local LOC = WidgetContainer:extend{
    name = "loc",
    is_doc_only = false,
}

-- Plugin settings file
LOC.settings_file = DataStorage:getSettingsDir() .. "/loc.lua"

function LOC:init()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
    self.settings = LuaSettings:open(self.settings_file)
    self.download_dir = self.settings:readSetting("download_dir") or DataStorage:getFullDataDir() .. "/downloads"
    self.api = LocApi  -- Use the API helper
    self.max_search_pages = self.settings:readSetting("max_search_pages") or 5
end

function LOC:onDispatcherRegisterActions()
    Dispatcher:registerAction("loc_search", {
        category = "none",
        event = "LocSearch",
        title = _("Library of Congress Search"),
        general = true,
    })
end

function LOC:addToMainMenu(menu_items)
    menu_items.loc_search = {
        text = _("Library of Congress"),
        sub_item_table = {
            {
                text = _("Browse EPUBs"),
                help_text = _("Browse available EPUBs from Library of Congress"),
                keep_menu_open = true,
                callback = function()
                    self:browseDefaultEpubs()
                end,
            },
            {
                text = _("Custom Search"),
                help_text = _("Search with your own terms"),
                keep_menu_open = true,
                callback = function()
                    self:showSearchDialog()
                end,
            },
            {
                text = _("Settings"),
                keep_menu_open = true,
                callback = function()
                    self:showSettingsDialog()
                end,
            },
        },
    }
end

function LOC:showSearchDialog()
    self.search_dialog = InputDialog:new{
        title = _("Search Library of Congress"),
        input_hint = _("Enter search terms"),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(self.search_dialog)
                    end,
                },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        local search_terms = self.search_dialog:getInputText()
                        UIManager:close(self.search_dialog)
                        if search_terms and search_terms ~= "" then
                            self:performSearch(search_terms)
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(self.search_dialog)
    self.search_dialog:onShowKeyboard()
end

function LOC:showSettingsDialog()
    self.settings_dialog = MultiInputDialog:new{
        title = _("Library of Congress Settings"),
        fields = {
            {
                text = self.download_dir,
                hint = _("Download directory"),
                input_type = "string",
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(self.settings_dialog)
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        local fields = self.settings_dialog:getFields()
                        self.download_dir = fields[1]
                        self.settings:saveSetting("download_dir", self.download_dir)
                        self.settings:flush()
                        UIManager:close(self.settings_dialog)
                        UIManager:show(InfoMessage:new{
                            text = _("Settings saved"),
                            timeout = 2,
                        })
                    end,
                },
            },
        },
    }
    UIManager:show(self.settings_dialog)
end

function LOC:browseDefaultEpubs()
    if not NetworkMgr:isOnline() then
        NetworkMgr:promptWifiOn()
        return
    end

    -- Filter for EPUBs specifically
    local default_url = "https://www.loc.gov/search/?fa=online-format:epub"
    self:loadSearchPage(default_url, 1)
end

function LOC:loadSearchPage(search_url, page_num)
    UIManager:show(InfoMessage:new{
        text = T(_("Loading page %1..."), page_num),
        timeout = 1,
    })

    -- Load one page at a time
    local results = self.api:retrieveSingleSearchPage(search_url, page_num)
    
    if results and #results > 0 then
        self:showSearchResults(results, search_url, page_num)
    else
        UIManager:show(InfoMessage:new{
            text = _("No EPUB results found"),
            timeout = 3,
        })
    end
end

-- Perform search
function LOC:performSearch(search_terms)
    if not NetworkMgr:isOnline() then
        NetworkMgr:promptWifiOn()
        return
    end

    -- Use the API helper to search (just first page)
    local base_url = "https://www.loc.gov/search/"
    local search_url = base_url .. "?q=" .. self.api:urlEncode(search_terms)
    self:loadSearchPage(search_url, 1)
end

-- Show search results
function LOC:showSearchResults(results, search_url, current_page)
    local items = {}
    
    for _, result in ipairs(results) do
        local title = result.title or "Untitled"
        if type(title) == "table" then
            title = title[1] or "Untitled"
        end
        
        table.insert(items, {
            text = title,
            callback = function()
                self:showItemDetails(result)
            end,
        })
    end
    
    -- Add "Load More" button at the end if we have a search_url
    if search_url and current_page then
        table.insert(items, {
            text = T(_("📄 Load More (Page %1)"), current_page + 1),
            callback = function()
                self:loadNextPage(search_url, current_page + 1, items)
            end,
        })
    end
    
    local results_menu = Menu:new{
        title = T(_("LOC Results - Page %1"), current_page or 1),
        item_table = items,
        parent = self.ui,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        show_captions = true,
        multilines_show_more_text = true,
        onMenuSelect = function(item_menu, item)
            if item.callback then
                item.callback()
            end
        end,
    }
    
    -- Store reference so we can update it
    self.current_menu = results_menu
    UIManager:show(results_menu)
    -- Force refresh
    UIManager:nextTick(function()
        UIManager:setDirty(results_menu, "ui")
    end)
end

-- Load next page and append to existing results
function LOC:loadNextPage(search_url, page_num, existing_items)
    UIManager:show(InfoMessage:new{
        text = T(_("Loading page %1..."), page_num),
        timeout = 1,
    })

    local results = self.api:retrieveSingleSearchPage(search_url, page_num)
    
    if not results or #results == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No more results"),
            timeout = 2,
        })
        return
    end
    
    -- Close current menu
    UIManager:close(self.current_menu)
    
    -- Append new results to existing items (but remove the old "Load More" button first)
    table.remove(existing_items)  -- Remove last item (Load More button)
    
    for _, result in ipairs(results) do
        local title = result.title or "Untitled"
        if type(title) == "table" then
            title = title[1] or "Untitled"
        end
        
        table.insert(existing_items, {
            text = title,
            callback = function()
                self:showItemDetails(result)
            end,
        })
    end
    
    -- Add new "Load More" button
    table.insert(existing_items, {
        text = T(_("📄 Load More (Page %1)"), page_num + 1),
        callback = function()
            self:loadNextPage(search_url, page_num + 1, existing_items)
        end,
    })
    
    -- Show updated menu
    local results_menu = Menu:new{
        title = T(_("LOC Results - Page %1"), page_num),
        item_table = existing_items,
        parent = self.ui,
        is_borderless = true,
        is_popout = false,
        title_bar_fm_style = true,
        show_captions = true,
        multilines_show_more_text = true,
        onMenuSelect = function(item_menu, item)
            if item.callback then
                item.callback()
            end
        end,
    }
    
    self.current_menu = results_menu
    UIManager:show(results_menu)
    -- Force refresh
    UIManager:nextTick(function()
        UIManager:setDirty(results_menu, "ui")
    end)
end

-- Show details for a specific item
function LOC:showItemDetails(item)
    logger.info("LOC: ========== SHOW ITEM DETAILS START ==========")
    logger.info("LOC: Item:", item.title or "No title")
    logger.info("LOC: Item ID:", item.id or "No ID")
    
    local title = item.title
    if type(title) == "table" then
        title = title[1] or "Untitled"
    end
    
    local item_id = item.id
    if not item_id then
        logger.err("LOC: Item ID not found")
        UIManager:show(InfoMessage:new{
            text = _("Item ID not found"),
            timeout = 2,
        })
        return
    end
    
    UIManager:show(InfoMessage:new{
        text = _("Loading item details..."),
        timeout = 1,
    })
    
    logger.info("LOC: Fetching item details for ID:", item_id)
    
    -- Fetch item details
    local item_data = self.api:getItemDetails(item_id)
    
    if not item_data then
        logger.err("LOC: Failed to load item details")
        UIManager:show(InfoMessage:new{
            text = _("Failed to load item details"),
            timeout = 3,
        })
        return
    end
    
    logger.info("LOC: Item data received successfully")
    
    -- Extract files
    local files = self.api:extractFileData(item_data)
    
    logger.info("LOC: Total files extracted:", #files)
    logger.info("LOC: ========== ALL EXTRACTED FILES ==========")
    for i, file in ipairs(files) do
        logger.info(string.format("LOC:   File %d: mimetype='%s'", i, tostring(file.mimetype)))
    end
    logger.info("LOC: ============================================")
    
    if #files == 0 then
        logger.warn("LOC: No files extracted from item data")
        UIManager:show(InfoMessage:new{
            text = _("No downloadable files found"),
            timeout = 3,
        })
        return
    end
    
    -- Filter for EPUBs and PDFs
    local supported_mimetypes = {
        "application/epub",
        "application/epub+zip",
        "application/pdf",
    }
    
    logger.info("LOC: Filtering for:", table.concat(supported_mimetypes, ", "))
    local filtered_files = self.api:filterFilesByMimetype(files, supported_mimetypes)
    
    logger.info("LOC: Files after filtering:", #filtered_files)
    logger.info("LOC: ========== FILTERED FILES ==========")
    for i, file in ipairs(filtered_files) do
        logger.info(string.format("LOC:   File %d: mimetype='%s'", i, tostring(file.mimetype)))
    end
    logger.info("LOC: ========================================")
    
    if #filtered_files == 0 then
        logger.warn("LOC: No EPUB or PDF files found after filtering")
        UIManager:show(InfoMessage:new{
            text = _("No EPUB or PDF files found"),
            timeout = 3,
        })
        return
    end
    
    -- Show file options
    logger.info("LOC: Showing file options dialog")
    self:showFileOptions(filtered_files, title)
    logger.info("LOC: ========== SHOW ITEM DETAILS END ==========")
end

-- Show downloadable files for an item
function LOC:showFileOptions(files, title)
    local buttons = {}
    
    for _, file in ipairs(files) do
        local format = file.mimetype:match("/(.+)$") or file.mimetype
        format = format:gsub("epub%+zip", "epub")
        
        local size_text = ""
        if file.size then
            local mb = file.size / 1024 / 1024
            size_text = string.format(" (%.1f MB)", mb)
        end
        
        table.insert(buttons, {
            {
                text = format:upper() .. size_text,
                callback = function()
                    self:downloadFile(file.url, title, format)
                    UIManager:close(self.file_dialog)
                end,
            }
        })
    end
    
    table.insert(buttons, {
        {
            text = _("Cancel"),
            callback = function()
                UIManager:close(self.file_dialog)
            end,
        }
    })
    
    self.file_dialog = ButtonDialog:new{
        title = T(_("Download: %1"), title),
        buttons = buttons,
    }
    
    UIManager:show(self.file_dialog)
    -- Force refresh
    UIManager:nextTick(function()
        UIManager:setDirty(self.file_dialog, "ui")
    end)
end

-- Download the file
function LOC:downloadFile(url, title, format)
    logger.info("LOC: ========== DOWNLOAD START ==========")
    logger.info("LOC: URL:", url)
    logger.info("LOC: Title:", title)
    logger.info("LOC: Format:", format)
    logger.info("LOC: Download dir:", self.download_dir)
    
    -- Make sure download directory exists
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(self.download_dir)
    
    -- Sanitize filename
    local filename = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_")
    filename = filename .. "." .. (format or "epub")
    local filepath = self.download_dir .. "/" .. filename
    
    logger.info("LOC: Final filepath:", filepath)

    -- Show downloading message
    local download_msg = InfoMessage:new{
        text = T(_("Downloading: %1"), filename),
    }
    UIManager:show(download_msg)
    
    -- Open file for writing
    local file, err_open = io.open(filepath, "wb")
    if not file then
        UIManager:close(download_msg)
        logger.err("LOC: Failed to open file for writing:", err_open)
        UIManager:show(InfoMessage:new{
            text = T(_("Download failed: %1"), err_open or _("Could not open file")),
            timeout = 5,
        })
        return
    end
    
    logger.info("LOC: File opened successfully for writing")
    
    -- Use socketutil.file_sink like Z-library does
    local socketutil = require("socketutil")
    local http = require("socket.http")
    
    local sink = socketutil.file_sink(file)
    logger.info("LOC: Created file sink")
    
    -- Set timeout for download
    socketutil:set_timeout(15, -1)  -- 15s block timeout, infinite total
    logger.info("LOC: Set timeout to 15s block, infinite total")
    
    -- Make HTTP request
    local request_params = {
        url = url,
        method = "GET",
        headers = {
            ["User-Agent"] = "KOReader/LOC-Plugin",
        },
        sink = sink,
        redirect = true,
    }
    
    logger.info("LOC: Calling http.request...")
    local success, status_code, headers_or_status = http.request(request_params)
    
    logger.info("LOC: http.request returned")
    logger.info("LOC: Success:", tostring(success), "Type:", type(success))
    logger.info("LOC: Status code:", tostring(status_code), "Type:", type(status_code))
    logger.info("LOC: Third param type:", type(headers_or_status))
    
    -- Reset timeout
    socketutil:reset_timeout()
    logger.info("LOC: Reset timeout")
    
    -- Close the download message
    UIManager:close(download_msg)
    
    -- LuaSocket http.request returns: (success, status_code, headers) or (nil, error_msg)
    -- success = 1 on success, nil on failure
    -- status_code = HTTP code (200, 404, etc) or error message
    -- headers = response headers table
    
    if not success then
        logger.err("LOC: HTTP request failed:", tostring(status_code))
        pcall(os.remove, filepath)
        UIManager:show(InfoMessage:new{
            text = T(_("Download failed: %1"), tostring(status_code)),
            timeout = 5,
        })
        return
    end
    
    if status_code == 200 then
        logger.info("LOC: Download completed successfully")
        UIManager:show(InfoMessage:new{
            text = T(_("Download complete: %1"), filename),
            timeout = 3,
        })
    else
        logger.err("LOC: Download failed, HTTP code:", status_code)
        -- Delete incomplete file
        pcall(os.remove, filepath)
        UIManager:show(InfoMessage:new{
            text = T(_("Download failed: HTTP %1"), tostring(status_code)),
            timeout = 5,
        })
    end
    
    logger.info("LOC: ========== DOWNLOAD END ==========")
end

function LOC:onLocSearch()
    self:showSearchDialog()
end

return LOC
