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
local json = require("json")
local logger = require("logger")

debug = true

CardChoice = {
    NO = 0,
    YES = 1,
    VAGUELY = 2,
}

local Flashcard = WidgetContainer:new{
    name = "flashcard",
    flashcard_amount = 2,
    flashcard_count = 0,
    parsing = false,
    db_path = util.joinPath(DataStorage.getFullDataDir(), "flashcards.json")
}

function Flashcard:displayFlashcardCallback (highlight, choice)
    self.flashcard_count = self.flashcard_count + 1
    UIManager:show(InfoMessage:new{text=T(_("Timestamp: %1 Choice: %2"), highlight.time, choice), timeout=1})
    if self.flashcard_count >= self.flashcard_amount then
        self.flashcard_count = 0
        self.data = self:parseDB()
    end
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
            self:displayFlashcardCallback(highlight, CardChoice.NO)
        end,
        vaguley_callback = function ()
            self:displayFlashcardCallback(highlight, CardChoice.VAGUELY)
        end,
        yes_callback = function ()
            self:displayFlashcardCallback(highlight, CardChoice.YES)
        end
    })
end

function Flashcard:getHighlights()
    local highlights = {}
    local i = 0

    for _ignore0, clippings in pairs(self.data) do
        for _ignore1, clipping in pairs(clippings) do
            highlights[i] = clipping
            i = i + 1
            if i >= self.flashcard_amount then
                break
            end
        end
    end

    logger.dbg("highlights: ", highlights)
    return highlights
end

function Flashcard:startFlashcardDisplay()
    for _ignore, highlight in pairs(self:getHighlights()) do
        self:displayFlashcard(highlight)
    end
    self.data = self:parseDB()
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

    logger.dbg("clippings: ", clippings)
    return clippings
end

function Flashcard:parseDB()
    self.parsing = true

    local clippings = self:getClippings()
    local data = {}

    local file = io.open(self.db_path, "r")
    if debug then
        file = nil
    end
    if file then
        local raw_data = file.read()
        if raw_data then
            local parsed_data = json.decode(raw_data)
            if parsed_data then
                data = parsed_data
            end
        end
    end
    for group=0,5 do
        if not data[group] then
            data[group] = {}
        end
    end
    local found, time
    for _ignore0, booknotes in pairs(clippings) do
        for _ignore1, chapter in ipairs(booknotes) do
            for _ignore2, clipping in ipairs(chapter) do
                clipping.title = booknotes.title
                clipping.author = booknotes.author
                if clipping.sort == "highlight" then
                    found = false
                    time = clipping.time
                    for group=0,5,-1 do
                        if data[group][time] then
                            found = true
                            break
                        end
                    end
                    if not found then
                        data[0][time] = clipping
                    end
                end
            end
        end
    end

    self.parsing = false

    logger.dbg("data: ", data)
    return data
end

function Flashcard:init()
    self.data = self:parseDB()

    self.ui.menu:registerToMainMenu(self)
end

function Flashcard:addToMainMenu(menu_items)
    menu_items.flashcard = {
        enabled_func = function ()
            return not self.parsing
        end,
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
