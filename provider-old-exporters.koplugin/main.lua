local Provider = require("provider")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local FlomoImpl = require("flomo")
local JoplinImpl = require("joplin")
local MemosImpl = require("memos")

local OldExporters = WidgetContainer:extend{
    name = "unsupported-exporters",
    is_doc_only = false,
}

function OldExporters:init()
    Provider:register("exporter", "flomo", FlomoImpl)
    Provider:register("exporter", "joplin", JoplinImpl)
    Provider:register("exporter", "memos", MemosImpl)
end

return OldExporters
