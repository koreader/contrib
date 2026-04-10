--[[
  Luminaria Sync Plugin for KOReader
  ─────────────────────────────────────────────
  Exports all highlights and syncs to
  luminaria.uk. Auto-syncs when WiFi connects.

  INSTALLATION:
  1. Navigate to: mnt/onboard/.adds/koreader/plugins/
  2. Create folder: luminaria.koplugin
  3. Place this file as: main.lua
  4. Place _meta.lua as: _meta.lua
  5. Restart KOReader fully
--]]

-- Only require modules that are guaranteed to exist in KOReader core
local WidgetContainer  = require("ui/widget/container/widgetcontainer")
local InfoMessage      = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager        = require("ui/uimanager")
local DataStorage      = require("datastorage")
local LuaSettings      = require("luasettings")
local logger           = require("logger")

-- All other modules loaded lazily inside functions
local NetworkMgr
local DocSettings
local ReadHistory
local http
local ltn12
local https

-- ── Hardcoded Worker URL
local WORKER_URL = "https://luminaria-sync.jamesisonfire21.workers.dev"

-- ── Settings
local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/luminaria.lua"
local settings

local function loadSettings()
  if not settings then
    settings = LuaSettings:open(SETTINGS_FILE)
  end
  return settings
end

local function getSetting(key, default)
  local v = loadSettings():readSetting(key)
  if v == nil then return default end
  return v
end

local function setSetting(key, value)
  loadSettings():saveSetting(key, value)
  loadSettings():flush()
end

-- ── Show a status message
local function showStatus(text)
  local msg = InfoMessage:new{ text = text }
  UIManager:show(msg)
  UIManager:forceRePaint()
  return msg
end

-- ── HTTP upload — loads socket lazily
local function uploadToWorker(content, token)
  if not http then
    local ok, m = pcall(require, "socket.http")
    if not ok then return false, "socket.http not available" end
    http = m
  end
  if not ltn12 then
    local ok, m = pcall(require, "ltn12")
    if not ok then return false, "ltn12 not available" end
    ltn12 = m
  end

  local response_body = {}
  local upload_url = WORKER_URL .. "/upload"
  local request_headers = {
    ["Content-Type"]   = "text/plain; charset=utf-8",
    ["Authorization"]  = "Bearer " .. token,
    ["Content-Length"] = tostring(#content),
  }
  local ok, code
  local success, err = pcall(function()
    if upload_url:match("^https") then
      if not https then
        local ok2, m = pcall(require, "ssl.https")
        if not ok2 then error("ssl.https not available") end
        https = m
      end
      ok, code = https.request{
        url     = upload_url,
        method  = "POST",
        headers = request_headers,
        source  = ltn12.source.string(content),
        sink    = ltn12.sink.table(response_body),
        timeout = 15,
      }
    else
      ok, code = http.request{
        url     = upload_url,
        method  = "POST",
        headers = request_headers,
        source  = ltn12.source.string(content),
        sink    = ltn12.sink.table(response_body),
        timeout = 15,
      }
    end
  end)
  if not success then return false, "Network error: " .. tostring(err) end
  if code == 200   then return true,  "OK" end
  if code == 401   then return false, "Invalid token — check settings" end
  return false, "Server error: " .. tostring(code)
end

-- ── Format datetime
local function formatDatetime(dt)
  if not dt then return "" end
  if type(dt) == "number" then
    return os.date("%d %B %Y %I:%M:%S %p", dt)
  end
  return tostring(dt)
end

-- ── Extract clean page number
local function cleanPageNum(page, fallback)
  if not page then return tostring(fallback or 0) end
  if type(page) == "number" and page >= 0 then return tostring(math.floor(page)) end
  if type(page) == "string" then
    local n = page:match("(%d+)")
    if n then return n end
  end
  return tostring(fallback or 0)
end

-- ── Read highlights from a single book via DocSettings
local function getHighlightsFromBook(file_path)
  if not file_path then return nil end
  if not DocSettings then return nil end

  local ok, doc_settings = pcall(function() return DocSettings:open(file_path) end)
  if not ok or not doc_settings then return nil end

  local props   = doc_settings:readSetting("doc_props") or {}
  local title   = props.title   or ""
  local authors = props.authors or ""

  if title == "" then
    title = file_path:match("([^/]+)%.[^.]+$") or file_path
  end

  local highlights = {}

  -- New format: annotations key (KOReader 2022+)
  local annotations = doc_settings:readSetting("annotations")
  local has_annotations_key = annotations ~= nil
  if annotations and #annotations > 0 then
    for _, ann in ipairs(annotations) do
      if ann.text and ann.text ~= "" then
        table.insert(highlights, {
          text     = ann.text,
          note     = ann.note or "",
          chapter  = ann.chapter or "",
          page     = ann.pageno or ann.page or 0,
          datetime = ann.datetime or "",
        })
      end
    end
  end

  -- Old format: bookmarks with highlighted = true
  -- Only fall back if the annotations key was entirely absent (not just empty-text entries)
  if #highlights == 0 and not has_annotations_key then
    local bookmarks = doc_settings:readSetting("bookmarks") or {}
    for _, bm in ipairs(bookmarks) do
      if bm.highlighted then
        local text = bm.notes or bm.text or ""
        if text ~= "" then
          table.insert(highlights, {
            text     = text,
            note     = "",
            chapter  = bm.chapter or "",
            page     = bm.page or bm.pageno or 0,
            datetime = bm.datetime or "",
          })
        end
      end
    end
  end

  if #highlights == 0 then return nil end

  return {
    title      = title,
    authors    = authors ~= "" and authors or "Unknown Author",
    highlights = highlights,
  }
end

-- ── Build markdown from reading history
local function buildMarkdown()
  -- Lazy load DocSettings
  if not DocSettings then
    local ok, m = pcall(require, "docsettings")
    if not ok then
      logger.warn("Luminaria: docsettings unavailable: " .. tostring(m))
      return nil, 0, 0
    end
    DocSettings = m
  end

  -- Lazy load ReadHistory
  if not ReadHistory then
    local ok, m = pcall(require, "readhistory")
    if not ok then
      logger.warn("Luminaria: readhistory unavailable: " .. tostring(m))
      return nil, 0, 0
    end
    ReadHistory = m
  end

  ReadHistory:reload()

  local lines = {}
  local book_count = 0
  local highlight_count = 0

  for _, item in ipairs(ReadHistory.hist) do
    if not item.dim and item.file then
      local book = getHighlightsFromBook(item.file)
      if book then
        if book_count > 0 then
          table.insert(lines, "")
        end
        table.insert(lines, "# " .. book.title)
        table.insert(lines, "##### " .. book.authors)
        table.insert(lines, "")

        local last_chapter = nil
        local h_index = 0
        for _, h in ipairs(book.highlights) do
          h_index = h_index + 1
          local chapter = h.chapter ~= "" and h.chapter or "Highlights"
          if chapter ~= last_chapter then
            table.insert(lines, "")
            table.insert(lines, "## " .. chapter)
            last_chapter = chapter
          end
          local pagenum = cleanPageNum(h.page, h_index)
          table.insert(lines, "### Page " .. pagenum .. " @ " .. formatDatetime(h.datetime))
          table.insert(lines, "*" .. h.text .. "*")
          if h.note ~= "" then
            table.insert(lines, "")
            table.insert(lines, "> " .. h.note)
          end
          table.insert(lines, "")
          highlight_count = highlight_count + 1
        end

        book_count = book_count + 1
      end
    end
  end

  if #lines == 0 then return nil, 0, 0 end

  table.insert(lines, "")
  table.insert(lines, "_Exported by Luminaria Sync · " .. os.date("%Y-%m-%d %H:%M") .. "_")

  return table.concat(lines, "\n"), book_count, highlight_count
end

-- ── Write export to clipboard folder
local function writeExportFile(content)
  local export_dir = getSetting("export_path", "/mnt/onboard/.adds/koreader/clipboard/")
  if not export_dir:match("/$") then export_dir = export_dir .. "/" end
  os.execute('mkdir -p "' .. export_dir .. '"')
  local filename = export_dir .. os.date("%Y-%m-%d-%H-%M-%S") .. "-all-books.md"
  local f = io.open(filename, "w")
  if not f then return nil end
  f:write(content)
  f:close()
  return filename
end

-- ── Settings dialog
local function showConfigDialog(callback)
  local current_token = getSetting("upload_token", "")
  local current_path  = getSetting("export_path", "/mnt/onboard/.adds/koreader/clipboard/")

  local dialog
  dialog = MultiInputDialog:new{
    title = "Luminaria Sync — Settings",
    fields = {
      {
        description = "Upload Token",
        hint        = "Your token from luminaria.uk/signup",
        text        = current_token,
        text_type   = "password",
      },
      {
        description = "Highlights export folder",
        hint        = "/mnt/onboard/.adds/koreader/clipboard/",
        text        = current_path,
      },
    },
    buttons = {
      {
        {
          text = "Cancel",
          callback = function() UIManager:close(dialog) end,
        },
        {
          text = "Save",
          is_enter_default = true,
          callback = function()
            local fields = dialog:getFields()
            local token  = (fields[1] or ""):match("^%s*(.-)%s*$")
            local path   = (fields[2] or ""):match("^%s*(.-)%s*$")

            if token == "" then
              UIManager:close(dialog)
              UIManager:show(InfoMessage:new{
                text = "Please enter your token.\n\nGet one at:\nluminaria.uk/signup",
              })
              return
            end

            setSetting("upload_token", token)
            setSetting("export_path",  path ~= "" and path or current_path)
            UIManager:close(dialog)
            UIManager:show(InfoMessage:new{ text = "Settings saved.", timeout = 2 })
            if callback then callback(token) end
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
end

-- ── Full export + upload
local function exportAndSync()
  local token = getSetting("upload_token", "")
  if token == "" then
    showConfigDialog(function()
      UIManager:scheduleIn(0.5, exportAndSync)
    end)
    return
  end

  local msg1 = showStatus("Luminaria: Exporting highlights…")
  local content, book_count, highlight_count = buildMarkdown()
  UIManager:close(msg1)

  if not content or highlight_count == 0 then
    UIManager:show(InfoMessage:new{
      text    = "Luminaria: No highlights found.\n\nOpen a book, make some highlights,\nthen try again.",
      timeout = 4,
    })
    return
  end

  writeExportFile(content)

  local msg2 = showStatus(
    "Luminaria: Syncing " .. highlight_count .. " highlight" ..
    (highlight_count ~= 1 and "s" or "") .. " from " ..
    book_count .. " book" .. (book_count ~= 1 and "s" or "") .. "…"
  )
  local ok, result = uploadToWorker(content, token)
  UIManager:close(msg2)

  if ok then
    UIManager:show(InfoMessage:new{
      text    = "✓ Luminaria: Synced!\n\n" ..
                highlight_count .. " highlight" .. (highlight_count ~= 1 and "s" or "") ..
                " from " .. book_count .. " book" .. (book_count ~= 1 and "s" or "") ..
                "\nare now live on luminaria.uk.",
      timeout = 5,
    })
    logger.info("Luminaria: synced " .. highlight_count .. " highlights from " .. book_count .. " books")
  else
    UIManager:show(InfoMessage:new{
      text    = "✗ Luminaria: Sync failed\n\n" .. tostring(result) ..
                "\n\nCheck your token in Settings.",
      timeout = 5,
    })
    logger.warn("Luminaria: sync failed — " .. tostring(result))
  end
end

-- ── Check if token is paid tier
local function checkTier(token)
  if not http then
    local ok, m = pcall(require, "socket.http")
    if not ok then return "free" end
    http = m
  end
  if not ltn12 then
    local ok, m = pcall(require, "ltn12")
    if not ok then return "free" end
    ltn12 = m
  end

  local response_body = {}
  local response_code
  local ok = pcall(function()
    if not https then
      local ok2, m = pcall(require, "ssl.https")
      if ok2 then https = m end
    end
    local requester = https or http
    local _, code = requester.request{
      url     = WORKER_URL .. "/tier",
      method  = "GET",
      headers = { ["Authorization"] = "Bearer " .. token },
      sink    = ltn12.sink.table(response_body),
      timeout = 15,
    }
    response_code = code
  end)

  if not ok then
    logger.warn("Luminaria: checkTier network error")
    return "free"
  end
  if response_code ~= 200 then
    logger.warn("Luminaria: checkTier HTTP " .. tostring(response_code))
    return "free"
  end
  local body = table.concat(response_body)
  if body:find('"paid"') then return "paid" end
  return "free"
end

-- ── WiFi connect handler (debounced — multiple hooks may fire per connection)
local lastWifiSyncTime = 0
local WIFI_SYNC_DEBOUNCE = 10  -- seconds

local function onWifiConnected()
  if not getSetting("auto_sync", true) then return end
  local token = getSetting("upload_token", "")
  if token == "" then return end

  local now = os.time()
  if now - lastWifiSyncTime < WIFI_SYNC_DEBOUNCE then
    logger.info("Luminaria: WiFi sync debounced — already triggered recently")
    return
  end
  lastWifiSyncTime = now

  logger.info("Luminaria: WiFi connected — checking tier")

  UIManager:scheduleIn(4, function()
    local tier = checkTier(token)
    if tier ~= "paid" then
      logger.info("Luminaria: free tier — auto-sync skipped")
      UIManager:show(InfoMessage:new{
        text    = "Luminaria: Auto-sync is a premium feature.\n\nVisit luminaria.uk/upgrade\nto subscribe for £2.99/month.",
        timeout = 6,
      })
      return
    end
    exportAndSync()
  end)
end

-- ── Wake from sleep handler
local wakeInProgress = false  -- guard against multiple firings per wake

local function onWake()
  if not getSetting("auto_sync", true) then return end
  local token = getSetting("upload_token", "")
  if token == "" then return end

  -- Prevent multiple simultaneous wake syncs
  if wakeInProgress then
    logger.info("Luminaria: wake already in progress — skipping")
    return
  end
  wakeInProgress = true

  -- Poll for WiFi after wake — Kobo puts WiFi to sleep so it needs time to reconnect.
  -- Calls the shared debounced onWifiConnected, so if afterWifiConnected already fired
  -- first the poll's call is blocked, and if the poll fires first afterWifiConnected's
  -- call will be blocked. Either way only one sync happens.
  local attempts = 0
  local max_attempts = 12  -- 12 x 5s = 60 seconds max wait

  local function checkConnection()
    attempts = attempts + 1
    logger.info("Luminaria: wake poll attempt " .. attempts)

    local nmok, nm = pcall(require, "ui/network/manager")
    if not nmok or not nm then wakeInProgress = false; return end

    local connected = false
    pcall(function() connected = nm:isConnected() end)

    if connected then
      logger.info("Luminaria: WiFi up after wake (attempt " .. attempts .. ")")
      wakeInProgress = false
      onWifiConnected()
    elseif attempts < max_attempts then
      UIManager:scheduleIn(5, checkConnection)
    else
      logger.info("Luminaria: gave up waiting for WiFi after wake")
      wakeInProgress = false
    end
  end

  UIManager:scheduleIn(5, checkConnection)
end

-- ── Plugin class
local LuminariaSyncPlugin = WidgetContainer:extend{
  name        = "luminaria",
  fullname    = "Luminaria Sync",
  is_doc_only = false,
}

function LuminariaSyncPlugin:onResume()
  onWake()
  return false
end

function LuminariaSyncPlugin:init()
  -- Register to main menu
  if self.ui and self.ui.menu then
    self.ui.menu:registerToMainMenu(self)
  elseif self.ui then
    logger.warn("Luminaria: self.ui.menu not available — menu registration skipped")
  end

  -- Hook UIManager's broadcastEvent to catch Resume in all contexts
  -- Wrapped in pcall so a missing method doesn't crash plugin init
  pcall(function()
    if UIManager.broadcastEvent then
      local orig_broadcast = UIManager.broadcastEvent
      UIManager.broadcastEvent = function(uimgr, event, ...)
        local event_name = type(event) == "table" and event.name or tostring(event)
        if event_name == "Resume" then
          logger.info("Luminaria: Resume event caught via broadcastEvent")
          onWake()
        end
        return orig_broadcast(uimgr, event, ...)
      end
    else
      logger.info("Luminaria: broadcastEvent not available — wake sync via onResume only")
    end
  end)

  -- Hook into export menu
  local ok, ExportHelper = pcall(require, "apps/filemanager/filemanagerexport")
  if ok and ExportHelper and ExportHelper.registerExporter then
    ExportHelper.registerExporter({
      name      = "luminaria",
      label     = "Luminaria Sync",
      export    = exportAndSync,
      configure = function() showConfigDialog() end,
    })
  end

  -- Hook WiFi events — lazy load NetworkMgr
  local nmok, nm = pcall(require, "ui/network/manager")
  if nmok and nm then
    NetworkMgr = nm

    -- Hook all three WiFi paths — different KOReader versions and firmware fire
    -- different callbacks. The debounce in onWifiConnected prevents double syncing.
    local orig_after = NetworkMgr.afterWifiConnected
    NetworkMgr.afterWifiConnected = function(mgr, ...)
      if orig_after then orig_after(mgr, ...) end
      onWifiConnected()
    end

    local orig_connect = NetworkMgr.connectWifi
    if orig_connect then
      NetworkMgr.connectWifi = function(mgr, callback, ...)
        local wrapped = function(...)
          if callback then callback(...) end
          onWifiConnected()
        end
        orig_connect(mgr, wrapped, ...)
      end
    end

    local orig_enable = NetworkMgr.enableWifi
    if orig_enable then
      NetworkMgr.enableWifi = function(mgr, callback, ...)
        local wrapped = function(...)
          if callback then callback(...) end
          UIManager:scheduleIn(5, function()
            if NetworkMgr:isConnected() then
              onWifiConnected()
            end
          end)
        end
        orig_enable(mgr, wrapped, ...)
      end
    end
  end
end

function LuminariaSyncPlugin:addToMainMenu(menu_items)
  menu_items.luminaria_sync = {
    text         = "Luminaria Sync",
    sorting_hint = "tools",
    sub_item_table = {
      {
        text     = "Sync highlights now",
        callback = exportAndSync,
      },
      {
        text     = "Link device (6-digit code)",
        callback = function()
          -- Lazy load http/https/ltn12 for the redeem request
          if not http then
            local ok, m = pcall(require, "socket.http") if ok then http = m end
          end
          if not https then
            local ok, m = pcall(require, "ssl.https") if ok then https = m end
          end
          if not ltn12 then
            local ok, m = pcall(require, "ltn12") if ok then ltn12 = m end
          end

          local dialog
          dialog = require("ui/widget/inputdialog"):new{
            title       = "Link device",
            input_hint  = "Enter 6-digit code from luminaria.uk/link",
            description = "Go to luminaria.uk/link on your computer, enter your token and get a 6-digit code. Type it here.",
            buttons = {
              {
                {
                  text = "Cancel",
                  callback = function() UIManager:close(dialog) end,
                },
                {
                  text = "Link",
                  is_enter_default = true,
                  callback = function()
                    local raw = dialog:getInputText() or ""
                    local code = raw:match("^%s*(.-)%s*$"):gsub("%s+", "")
                    UIManager:close(dialog)

                    if #code ~= 6 or not code:match("^%d+$") then
                      UIManager:show(InfoMessage:new{
                        text = "Please enter the 6-digit code\nfrom luminaria.uk/link",
                        timeout = 3,
                      })
                      return
                    end

                    local msg = showStatus("Luminaria: Linking device…")

                    -- Redeem the code
                    local response_body = {}
                    local redeem_url = WORKER_URL .. "/link/redeem?code=" .. code
                    local ok_req, err_req = pcall(function()
                      if https then
                        https.request{
                          url     = redeem_url,
                          method  = "GET",
                          sink    = ltn12.sink.table(response_body),
                          timeout = 15,
                        }
                      elseif http then
                        http.request{
                          url     = redeem_url,
                          method  = "GET",
                          sink    = ltn12.sink.table(response_body),
                          timeout = 15,
                        }
                      else
                        error("No HTTP module available")
                      end
                    end)

                    UIManager:close(msg)

                    if not ok_req then
                      UIManager:show(InfoMessage:new{
                        text    = "✗ Link failed: Network error\n\n" .. tostring(err_req) ..
                                  "\n\nCheck your connection and try again.",
                        timeout = 5,
                      })
                      return
                    end

                    local body = table.concat(response_body)
                    local token = body:match('"token":"([^"]+)"')

                    if token then
                      setSetting("upload_token", token)
                      UIManager:show(InfoMessage:new{
                        text    = "✓ Device linked!\n\nYour token has been saved.\nYou can now sync your highlights.",
                        timeout = 5,
                      })
                    else
                      local errMsg = body:match('"error":"([^"]+)"') or "Unknown error"
                      UIManager:show(InfoMessage:new{
                        text    = "✗ Link failed: " .. errMsg .. "\n\nCodes expire after 10 minutes.\nGenerate a new one at luminaria.uk/link",
                        timeout = 5,
                      })
                    end
                  end,
                },
              },
            },
          }
          UIManager:show(dialog)
        end,
      },
      {
        text = "Auto-sync on WiFi",
        checked_func = function()
          return getSetting("auto_sync", true) == true
        end,
        callback = function()
          local current = getSetting("auto_sync", true)
          if not current then
            -- Enabling — verify paid tier first
            local token = getSetting("upload_token", "")
            if token == "" then
              UIManager:show(InfoMessage:new{
                text    = "Please set your sync token in Settings first.",
                timeout = 3,
              })
              return
            end
            local msg = showStatus("Luminaria: Checking subscription…")
            local tier = checkTier(token)
            UIManager:close(msg)
            if tier ~= "paid" then
              UIManager:show(InfoMessage:new{
                text    = "Auto-sync requires a subscription.\n\nVisit luminaria.uk/upgrade\nto subscribe for £2.99/month.",
                timeout = 5,
              })
              return
            end
          end
          setSetting("auto_sync", not current)
          UIManager:show(InfoMessage:new{
            text    = "Auto-sync " .. (not current and "enabled ✓" or "disabled"),
            timeout = 2,
          })
        end,
      },
      {
        text     = "Settings",
        callback = function() showConfigDialog() end,
      },
      {
        text     = "About",
        callback = function()
          UIManager:show(InfoMessage:new{
            text = "Luminaria Sync\n\nExports your KOReader highlights\nand syncs to luminaria.uk automatically\nwhen WiFi connects.\n\nluminaria.uk/signup",
          })
        end,
      },
    },
  }
end

return LuminariaSyncPlugin
