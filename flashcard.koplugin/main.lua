local DocSettings = require("docsettings")
local ReadHistory = require("readhistory")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local SpinWidget = require("ui/widget/spinwidget")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local TextViewer = require("ui/widget/textviewer")
local Screen = require("device").screen
local _ = require("gettext")
local T = require("ffi/util").template
local logger = require("logger")

local CardChoice = {
    NO = 0,
    YES = 1,
    VAGUELY = 2,
}

local Flashcard = WidgetContainer:new{
    name = "flashcard",
    seconds_in_a_day = 86400,
    flashcard_amount = 5,
    flashcard_count = 0,
}

local displayFlashcardCallbackYesChoice = function(flashcard_data)
    if flashcard_data.n == 0 then
        flashcard_data.interval = 1
    elseif flashcard_data.n == 1 then
        flashcard_data.interval = 6
    else
        flashcard_data.interval = flashcard_data.interval * flashcard_data.efactor
    end
    flashcard_data.n = flashcard_data.n + 1
    flashcard_data.efactor = flashcard_data.efactor + 0.15

    return flashcard_data
end

local displayFlashcardCallbackVaguelyChoice = function(flashcard_data)
    if flashcard_data.n == 0 then
        flashcard_data.interval = 1
    elseif flashcard_data.n == 1 then
        flashcard_data.interval = 3
    else
        flashcard_data.interval = 6
    end
    flashcard_data.n = 0
    flashcard_data.efactor = flashcard_data.efactor - 0.25

    return flashcard_data
end

local displayFlashcardCallbackNoChoice = function(flashcard_data)
    flashcard_data.n = 0
    flashcard_data.interval = 1
    flashcard_data.efactor = flashcard_data.efactor - 0.5

    return flashcard_data
end

local displayFlashcardCallback = function(filename, highlight, choice)
    local flashcard_data = highlight.flashcard_data
    flashcard_data.last_shown = os.time()

    if choice == CardChoice.YES then
        flashcard_data = displayFlashcardCallbackYesChoice(flashcard_data)
    elseif choice == CardChoice.VAGUELY then
        flashcard_data = displayFlashcardCallbackVaguelyChoice(flashcard_data)
    else
        flashcard_data = displayFlashcardCallbackNoChoice(flashcard_data)
    end
    if flashcard_data.efactor < 1.3 then flashcard_data.efactor = 1.3 end

    local docinfo = DocSettings:open(filename)
    docinfo.data.highlight[highlight.page][highlight.highlight_index].flashcard_data = flashcard_data
    docinfo:flush()
end

function Flashcard:DocHasHighlights(docinfo)
    if docinfo and docinfo.data and docinfo.data.highlight and #docinfo.data.highlight then return true end
    return false
end

function Flashcard:getHighlights()
    local res_highlights = {}
    local highlight_count = 0
    local docinfo, flashcard_data, days_passed, flush_doc, filename

    for _ignore, doc in pairs(ReadHistory.hist) do
        filename = doc.file
        flush_doc = false
        docinfo = DocSettings:open(filename)
        if self:DocHasHighlights(docinfo) then
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
                        flush_doc = true
                    end
                    days_passed = (os.time() - flashcard_data.last_shown) / self.seconds_in_a_day
                    if days_passed >= flashcard_data.interval then
                        highlight = {
                            page = page,
                            highlight_index = highlight_index,
                            flashcard_data = flashcard_data,
                            text = highlight.text,
                        }
                        if not res_highlights[filename] then
                            res_highlights[filename] = {
                                title = docinfo.data.stats.title,
                                author = docinfo.data.stats.authors,
                                highlights = {},
                            }
                        end
                        table.insert(res_highlights[filename].highlights, highlight)
                        highlight_count = highlight_count + 1
                    end
                    if highlight_count >= self.flashcard_amount then
                        if flush_doc then docinfo:flush() end
                        return res_highlights
                    end
                end
            end
        end
        if flush_doc then docinfo:flush() end
    end

    if #res_highlights < self.flashcard_amount then self.flashcard_amount = #res_highlights end

    logger.dbg("res_highlights: ", res_highlights)
    return res_highlights
end

function Flashcard:displayFlashcards()
    for filename, metadata in pairs(self:getHighlights()) do
        for _ignore, highlight in pairs(metadata.highlights) do
            local textviewer
            textviewer = TextViewer:new{
                title = _("Do you remember this highlight/note?"),
                text = T(_("Title: %1\r\nAuthor: %2\r\n\r\n%3"), metadata.title, metadata.author, highlight.text),
                width = Screen:getWidth(),
                height = Screen:getHeight(),
                buttons_table = {{{
                    text = _("No"),
                    callback = function()
                        UIManager:close(textviewer)
                        displayFlashcardCallback(filename, highlight, CardChoice.NO)
                    end,
                }, {
                    text = _("Vaguely"),
                    callback = function()
                        UIManager:close(textviewer)
                        displayFlashcardCallback(filename, highlight, CardChoice.VAGUELY)
                    end,
                }, {
                    text = _("Yes"),
                    callback = function()
                        UIManager:close(textviewer)
                        displayFlashcardCallback(filename, highlight, CardChoice.YES)
                    end,
                }}},
            }
            UIManager:show(textviewer)
        end
    end
end

function Flashcard:init()
    self.ui.menu:registerToMainMenu(self)
end

function Flashcard:addToMainMenu(menu_items)
    menu_items.flashcard = {
        text = _("Flashcard trainer"),
        sorting_hint = "tools",
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
                    self:displayFlashcards()
                end,
            }
            UIManager:show(spinwidget)
        end,
    }
end

return Flashcard
