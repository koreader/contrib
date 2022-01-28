local SpinWidget = require("ui/widget/spinwidget")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local FlashcardWidget = require("flashcardwidget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template
local logger = require("logger")
local FlashcardDB = require('FlashcardDB')

CardChoice = {
    NO = 0,
    YES = 1,
    VAGUELY = 2
}

local Flashcard = WidgetContainer:new{
    name = "flashcard",
    seconds_in_a_day = 86400,
    flashcard_amount = 5,
    flashcard_count = 0,
    db = FlashcardDB:new()
}

function Flashcard:displayFlashcardCallback(highlight, choice)
    logger.dbg("Showed highlight: ", highlight.time)

    self.flashcard_count = self.flashcard_count + 1
    highlight.last_shown = os.time()

    if choice == CardChoice.YES then
        if highlight.n == 0 then
            highlight.interval = 1
        elseif highlight.n == 1 then
            highlight.interval = 6
        else
            highlight.interval = highlight.interval * highlight.efactor
        end
        highlight.n = highlight.n + 1
        highlight.efactor = highlight.efactor + 0.15
    elseif choice == CardChoice.VAGUELY then
        if highlight.n == 0 then
            highlight.interval = 1
        elseif highlight.n == 1 then
            highlight.interval = 3
        else
            highlight.interval = 6
        end
        highlight.n = 0
        highlight.efactor = highlight.efactor - 0.25
    else
        highlight.n = 0
        highlight.interval = 1
        highlight.efactor = highlight.efactor - 0.5
    end
    if highlight.efactor < 1.3 then
        highlight.efactor = 1.3
    end
    self.data[highlight.time] = highlight

    if self.flashcard_count >= self.flashcard_amount then
        self.flashcard_count = 0
        self.db:updateDB(self.data)
    end
end

function Flashcard:displayFlashcard(highlight)
    UIManager:show(FlashcardWidget:new{
        title_text = _("Do you rerember this highlight/note?"),
        text = T(_("Title: %1\r\n Author: %2\r\n\r\n%3"), highlight.title, highlight.author, highlight.text),
        no_callback = function()
            self:displayFlashcardCallback(highlight, CardChoice.NO)
        end,
        vaguley_callback = function()
            self:displayFlashcardCallback(highlight, CardChoice.VAGUELY)
        end,
        yes_callback = function()
            self:displayFlashcardCallback(highlight, CardChoice.YES)
        end
    })
end

function Flashcard:getHighlights()
    local highlights = {}
    local i = 0

    for _ignore0, highlight in pairs(self.data) do
        local days_passed = (os.time() - highlight.last_shown) / self.seconds_in_a_day
        if days_passed >= highlight.interval then
            highlights[i] = highlight
            i = i + 1
            if i >= self.flashcard_amount then
                break
            end
        end
    end

    if #highlights < self.flashcard_amount then
        self.flashcard_amount = #highlights
    end

    logger.dbg("highlights: ", highlights)
    return highlights
end

function Flashcard:startFlashcardDisplay()
    self.flashcard_count = 0
    for _ignore, highlight in pairs(self:getHighlights()) do
        self:displayFlashcard(highlight)
    end
end

function Flashcard:init()
    self.data = self.db:parseDB()

    self.ui.menu:registerToMainMenu(self)
end

function Flashcard:addToMainMenu(menu_items)
    menu_items.flashcard = {
        enabled_func = function()
            return not self.db.parsing
        end,
        text = _("Flashcard trainer"),
        sub_item_table = {{
            text = _("Start"),
            callback = function()
                local spinwidget = SpinWidget:new{
                    title_text = _("Flashcard Trainer"),
                    info_text = _("Pick the amount of flashcards and press start"),
                    ok_text = _("Start"),
                    value = self.flashcard_amount,
                    value_min = 1,
                    value_max = 1000,
                    ok_always_enabled = true,
                    wrap = true,
                    callback = function(spin)
                        self.flashcard_amount = spin.value
                        self:startFlashcardDisplay()
                    end
                }
                UIManager:show(spinwidget)
            end
        }, {
            text = _("Refresh"),
            keep_menu_open = ture,
            callback = function()
                self.data = self.db:parseDB()
            end
        }, {
            text = _("Clear DB"),
            callback = function()
                UIManager:show(ConfirmBox:new{
                    text = _("Are you sure you want to reset progress?"),
                    ok_text = _("Reset"),
                    ok_callback = function()
                        self.db:clearDB()
                    end
                })
            end
        }}
    }
end

return Flashcard
