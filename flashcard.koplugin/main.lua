local SpinWidget = require("ui/widget/spinwidget")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local ConfirmBox = require("ui/widget/confirmbox")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local Flashcard = WidgetContainer:new{
    name = "flashcard",
    flashcard_amount = 5,
}

function Flashcard:displayFlashcard()
    UIManager:show(ConfirmBox:new{text=_("test")})
end

function Flashcard:startFlashcardDisplay()
    for __=0,self.flashcard_amount-1 do
        self:displayFlashcard()
    end
end

function Flashcard:init()
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
