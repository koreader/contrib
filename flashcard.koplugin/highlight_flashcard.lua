local UIManager = require("ui/uimanager")
local TextViewer = require("ui/widget/textviewer")
local DocSettings = require("docsettings")
local Screen = require("device").screen
local _ = require("gettext")
local T = require("ffi/util").template
local BaseFlashcard = require("base_flashcard")

local CardChoice = {
    NO = 0,
    YES = 1,
    VAGUELY = 2,
}

local HighlightFlashcard = BaseFlashcard:new{}

function HighlightFlashcard:new(o)
    o = o or BaseFlashcard:new{}
    setmetatable(o, self)
    self.__index = self
    assert(o.show_next_callback, "Init show_next_callback")
    assert(o.document, "Init document")
    assert(o.highlight_page, "Init highlight_page")
    assert(o.highlight_index, "Init highlight_index")
    if o.init then o:init() end
    return o
end

function HighlightFlashcard:show()
    local docinfo = DocSettings:open(self.document)
    local authors = docinfo.data.stats.authors
    local title = docinfo.data.stats.title
    local highlight_text = docinfo.data.highlight[self.highlight_page][self.highlight_index].text
    docinfo:close()

    local textviewer
    textviewer = TextViewer:new{
        title = _("Do you remember this highlight?"),
        text = T(_("Title: %1\r\nAuthor: %2\r\n\r\n%3"), title, authors, highlight_text),
        width = Screen:getWidth(),
        height = Screen:getHeight(),
        buttons_table = {{{
            text = _("No"),
            callback = function()
                UIManager:close(textviewer)
                self:showCallback(CardChoice.NO)
            end,
        }, {
            text = _("Vaguely"),
            callback = function()
                UIManager:close(textviewer)
                self:showCallback(CardChoice.VAGUELY)
            end,
        }, {
            text = _("Yes"),
            callback = function()
                UIManager:close(textviewer)
                self:showCallback(CardChoice.YES)
            end,
        }}},
    }
    UIManager:show(textviewer)
end

function HighlightFlashcard:showCallback(choice)
    local docinfo = DocSettings:open(self.document)
    local flashcard_data = docinfo.data.highlight[self.highlight_page][self.highlight_index].flashcard_data
    docinfo:close()

    flashcard_data.last_shown = os.time()

    if choice == CardChoice.YES then
        flashcard_data = self:showCallbackYesChoice(flashcard_data)
    elseif choice == CardChoice.VAGUELY then
        flashcard_data = self:showCallbackVaguelyChoice(flashcard_data)
    elseif choice == CardChoice.NO then
        flashcard_data = self:showCallbackNoChoice(flashcard_data)
    end
    if flashcard_data.efactor < 1.3 then flashcard_data.efactor = 1.3 end

    local docinfo = DocSettings:open(self.document)
    docinfo.data.highlight[self.highlight_page][self.highlight_index].flashcard_data = flashcard_data
    docinfo:flush()
    docinfo:close()
    self.show_next_callback()
end

function HighlightFlashcard:showCallbackYesChoice(flashcard_data)
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

function HighlightFlashcard:showCallbackVaguelyChoice(flashcard_data)
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

function HighlightFlashcard:showCallbackNoChoice(flashcard_data)
    flashcard_data.n = 0
    flashcard_data.interval = 1
    flashcard_data.efactor = flashcard_data.efactor - 0.5

    return flashcard_data
end

return HighlightFlashcard
