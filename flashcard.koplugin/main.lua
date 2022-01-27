local SpinWidget = require("ui/widget/spinwidget")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local FlashcardWidget = require("flashcardwidget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Parser = require("Parser")
local _ = require("gettext")
local T = require("ffi/util").template
local util = require("ffi/util")
local DataStorage = require("datastorage")

CardChoice = {
    NO = 0,
    YES = 1,
    VAGUELY = 2,
}

local Flashcard = WidgetContainer:new{
    name = "flashcard",
    flashcard_amount = 2,
}

local updateDB = function (highlight, choice)
    UIManager:show(InfoMessage:new{text=T(_("Timestamp: %1 Choice: %2"), highlight.time, choice), timeout=1})
end

function Flashcard:displayFlashcard(highlight)
    UIManager:show(FlashcardWidget:new{
        title_text=_("Do you rerember this highlight/note?"),
        text = T(_("Title: %1\r\n Author: %2\r\n\r\n%3"),
            highlight.title,
            highlight.author,
            highlight.text
        ),
        no_callback = function ()
            updateDB(highlight, CardChoice.NO)
        end,
        vaguley_callback = function ()
            updateDB(highlight, CardChoice.VAGUELY)
        end,
        yes_callback = function ()
            updateDB(highlight, CardChoice.YES)
        end
    })
end

function Flashcard:startFlashcardDisplay()
    local highlight_data = {title=_("title"), author=_("author"), text=_("text")}
    local counter = 0;
    for _ignore0, booknotes in pairs(self.clippings) do
        highlight_data.title = booknotes.title
        highlight_data.author = booknotes.author
        for _ignore1, chapter in ipairs(booknotes) do
            for _ignore2, clipping in ipairs(chapter) do
                if clipping.sort ~= "highlight" or clipping.sort ~= "note" then
                    highlight_data.time = clipping.time
                    if clipping.text then
                        highlight_data.text = clipping.text
                    end
                    if clipping.note then
                        highlight_data.text = highlight_data.text .. clipping.note
                    end
                    self:displayFlashcard(highlight_data)

                    counter = counter + 1
                    if counter >= self.flashcard_amount then break end
                end
            end
            if counter >= self.flashcard_amount then break end
        end
        if counter >= self.flashcard_amount then break end
    end
end

function Flashcard:getClippings()
    local parser = Parser:new{history_dir = "./history"}
    local clippings = parser:parseHistory()
    -- Clean empty clippings
    for title, booknotes in pairs(clippings) do
        if #booknotes == 0 then
            clippings[title] = nil
        end
    end

    return clippings
end

function Flashcard:init()
    self.clippings = self:getClippings()

    self.ui.menu:registerToMainMenu(self)
end

function Flashcard:addToMainMenu(menu_items)
    menu_items.flashcard = {
        text = _("Flashcard Trainer"),
        callback = function()
                local spinwidget = SpinWidget:new{
                    title_text = _("Flashcard Trainer"),
                    info_text = _("Pick the amount of flashcards and press start"),
                    ok_text = _("Start"),
                    value = self.flashcard_amount,
                    value_min = 0,
                    value_max = 1000,
                    ok_always_enabled = true,
                    wrap = true,
                    callback = function (spin)
                        self.flashcard_amount = spin.value
                        self:startFlashcardDisplay()
                    end
                }
                UIManager:show(spinwidget)
            end
    }
end

return Flashcard
