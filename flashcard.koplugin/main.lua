local DocSettings = require("docsettings")
local ReadHistory = require("readhistory")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local SpinWidget = require("ui/widget/spinwidget")
local HighlightFlashcard = require("highlight_flashcard")
local _ = require("gettext")

local SECONDS_IN_A_DAY = 86400

local Flashcards = WidgetContainer:new{
    name = "flashcard",
    highlights = {},
}

function Flashcards:DocHasHighlights(docinfo)
    if docinfo and docinfo.data and docinfo.data.highlight and #docinfo.data.highlight then return true end
    return false
end

function Flashcards:initHighlightLists()
    local docinfo, flashcard_data, filename, days_passed

    for _ignore, doc in pairs(ReadHistory.hist) do
        filename = doc.file
        docinfo = DocSettings:open(filename)
        if docinfo.data.highlight then
            for page, highlights in pairs(docinfo.data.highlight) do
                for highlight_index, highlight in pairs(highlights) do
                    flashcard_data = highlight.flashcard_data
                    if not flashcard_data then
                        flashcard_data = {
                            last_shown = 0,
                            efactor = 2.5,
                            interval = 0,
                            n = 0,
                        }
                        docinfo.data.highlight[page][highlight_index].flashcard_data = flashcard_data
                        docinfo:flush()
                    end

                    days_passed = (os.time() - flashcard_data.last_shown) / SECONDS_IN_A_DAY
                    if days_passed >= flashcard_data.interval then
                        table.insert(self.highlights, HighlightFlashcard:new{
                            show_next_callback = function() Flashcards:displayFlashcard() end,
                            document = filename,
                            highlight_page = page,
                            highlight_index = highlight_index,
                        })
                    end

                end
            end
        end
    end
    docinfo:close()
end

function Flashcards:displayFlashcard()
    if #self.highlights == 0 then return end
    local highlight = table.remove(self.highlights, math.random(#self.highlights))
    highlight:show()
end

function Flashcards:init() self.ui.menu:registerToMainMenu(self) end

function Flashcards:addToMainMenu(menu_items)
    menu_items.flashcard = {
        text = _("Flashcard trainer"),
        sorting_hint = "tools",
        callback = function()
            self:initHighlightLists()
            self:displayFlashcard()
        end,
    }
end

return Flashcards
