--[[
  Luminaria Sync Plugin for KOReader
  ─────────────────────────────────────────────
  Adds "Luminaria Sync" as an option in the
  KOReader export/share menu for highlights.

  INSTALLATION:
  1. On your Kobo, navigate to:
       mnt/onboard/.adds/koreader/plugins/
  2. Create a folder named:
       luminaria.koplugin
  3. Place this file inside as:
       main.lua
  4. Place _meta.lua inside as:
       _meta.lua
  5. Restart KOReader fully
  6. Go to any book → Highlights → Export
     and "Luminaria Sync" will appear as an option
--]]

local InfoMessage  = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager    = require("ui/uimanager")
local DataStorage  = require("datastorage")
local LuaSettings  = require("luasettings")
local http         = require("socket.http")
local ltn12        = require("ltn12")
local https        -- loaded lazily on first use
local logger       = require("logger")

-- ── Hardcoded Worker URL — users never need to enter this
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
  return loadSettings():readSetting(key) or default
end

local function setSetting(key, value)
  loadSettings():saveSetting(key, value)
  loadSettings():flush()
end

-- ── HTTP upload
local function uploadToWorker(content, token)
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
      https = https or require("ssl.https")
      ok, code = https.request{
        url     = upload_url,
        method  = "POST",
        headers = request_headers,
        source  = ltn12.source.string(content),
        sink    = ltn12.sink.table(response_body),
      }
    else
      ok, code = http.request{
        url     = upload_url,
        method  = "POST",
        headers = request_headers,
        source  = ltn12.source.string(content),
        sink    = ltn12.sink.table(response_body),
      }
    end
  end)

  if not success then
    return false, "Network error: " .. tostring(err)
  end
  if code == 200 then
    return true, "OK"
  elseif code == 401 then
    return false, "Invalid token — check your settings"
  else
    return false, "Server error: " .. tostring(code)
  end
end

-- ── Find the most recently modified .md export file
local function findLatestExport()
  local clipboard_dir = getSetting("export_path", "/mnt/onboard/.adds/koreader/clipboard/")

  local handle = io.popen('ls -t "' .. clipboard_dir .. '"*.md 2>/dev/null | head -1')
  if handle then
    local line = handle:read("*l")
    handle:close()
    if line then
      local f = line:match("^%s*(.-)%s*$")
      if f and f ~= "" then
        logger.dbg("Luminaria: found export at " .. f)
        return f
      end
    end
  end

  return nil
end

-- ── Show configure dialog
local function showConfigDialog(callback)
  local current_token = getSetting("upload_token", "")
  local current_path  = getSetting("export_path", "/mnt/onboard/.adds/koreader/clipboard/")

  local dialog
  dialog = MultiInputDialog:new{
    title = "Luminaria Sync — Settings",
    fields = {
      {
        description = "Upload Token",
        hint        = "Your token from the registration email",
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
          callback = function()
            UIManager:close(dialog)
          end,
        },
        {
          text = "Save",
          is_enter_default = true,
          callback = function()
            local fields = dialog:getFields()
            local token = (fields[1] or ""):match("^%s*(.-)%s*$")
            local path  = (fields[2] or ""):match("^%s*(.-)%s*$")

            if token == "" then
              UIManager:close(dialog)
              UIManager:show(InfoMessage:new{
                text = "Please enter your token.\n\nGet a free token at:\nluminaria.pages.dev/signup.html",
              })
              return
            end

            setSetting("upload_token", token)
            setSetting("export_path",  path ~= "" and path or current_path)

            UIManager:close(dialog)
            UIManager:show(InfoMessage:new{
              text    = "Settings saved.",
              timeout = 2,
            })
            if callback then callback(token) end
          end,
        },
      },
    },
  }
  UIManager:show(dialog)
end

-- ── Main sync action
local function doSync()
  local token = getSetting("upload_token", "")

  -- If not configured, show settings first then sync
  if token == "" then
    showConfigDialog(function(tok)
      UIManager:scheduleIn(0.5, function()
        doSync()
      end)
    end)
    return
  end

  -- Find the export file
  local progress = InfoMessage:new{ text = "Looking for highlights file…" }
  UIManager:show(progress)
  UIManager:forceRePaint()

  local export_file = findLatestExport()
  UIManager:close(progress)

  if not export_file then
    UIManager:show(InfoMessage:new{
      text = "No highlights export file found.\n\nFirst export your highlights:\nTop menu → Search → Export all highlights\n\nIf it still fails, set the correct folder path in:\nMenu → Luminaria Sync → Settings",
    })
    return
  end

  -- Read file
  local file = io.open(export_file, "r")
  if not file then
    UIManager:show(InfoMessage:new{
      text = "Could not read file:\n" .. export_file,
    })
    return
  end
  local content = file:read("*all")
  file:close()

  if not content or #content < 50 then
    UIManager:show(InfoMessage:new{
      text = "Highlights file appears empty.\nTry exporting again first.",
    })
    return
  end

  -- Upload
  local uploading = InfoMessage:new{
    text = "Syncing to Luminaria…\n(" .. math.floor(#content / 1024) .. " KB)",
  }
  UIManager:show(uploading)
  UIManager:forceRePaint()

  local ok, result = uploadToWorker(content, token)
  UIManager:close(uploading)

  if ok then
    UIManager:show(InfoMessage:new{
      text    = "✓ Synced to Luminaria!\n\nOpen Luminaria in your browser\nand tap ↻ Sync from Kobo.",
      timeout = 4,
    })
  else
    UIManager:show(InfoMessage:new{
      text = "Sync failed:\n" .. tostring(result) .. "\n\nCheck your token in:\nMenu → Luminaria Sync → Settings",
    })
  end
end

-- ── Plugin registration
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local LuminariaSyncPlugin = WidgetContainer:extend{
  name        = "luminaria",
  fullname    = "Luminaria Sync",
  is_doc_only = false,
}

function LuminariaSyncPlugin:init()
  -- Register to the main menu
  self.ui.menu:registerToMainMenu(self)

  -- Also try to hook into the export system if available
  local ok, ExportHelper = pcall(require, "apps/filemanager/filemanagerexport")
  if ok and ExportHelper and ExportHelper.registerExporter then
    ExportHelper.registerExporter({
      name      = "luminaria",
      label     = "Luminaria Sync",
      export    = function() doSync() end,
      configure = function() showConfigDialog() end,
    })
  end
end

function LuminariaSyncPlugin:addToMainMenu(menu_items)
  menu_items.luminaria_sync = {
    text = "Luminaria Sync",
    sub_item_table = {
      {
        text     = "Sync highlights now",
        callback = function() doSync() end,
      },
      {
        text     = "Settings",
        callback = function() showConfigDialog() end,
      },
      {
        text     = "About",
        callback = function()
          UIManager:show(InfoMessage:new{
            text = "Luminaria Sync\n\nExports your KOReader highlights to your Luminaria website.\n\nGet a free token at:\nyoursite.pages.dev/signup.html",
          })
        end,
      },
    },
  }
end

return LuminariaSyncPlugin
