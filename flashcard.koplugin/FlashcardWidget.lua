local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local logger = require("logger")
local TitleBar = require("ui/widget/titlebar")
local _ = require("gettext")
local Screen = require("device").screen

local FlashcardWidget = InputContainer:new{
    modal = true,
    text = _("no text"),
    title_text = _("no title"),
    face = Font:getFace("infofont"),
    no_callback = function() end,
    vaguley_callback = function() end,
    yes_callback = function() end,
    margin = Size.margin.default,
    padding = Size.padding.default,
}

function FlashcardWidget:init()
    if self.dismissable then
        if Device:isTouchDevice() then
            self.ges_events.TapClose = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                }
            }
        end
        if Device:hasKeys() then
            self.key_events = {
                Close = { {Device.input.group.Back}, doc = "cancel" }
            }
        end
    end
    local width = Screen:getWidth() * 0.95
    local title = TitleBar:new{
        align = "center",
        with_bottom_line = true,
        title = self.title_text,
        title_shrink_font_to_fit = true,
        show_parent = self,
        width = width,
    }
    local content = ScrollTextWidget:new{
            text = self.text,
            face = self.face,
            width = width,
            height = Screen:getHeight() * 0.80
    }

    local button_table = ButtonTable:new{
        width = content:getSize().w,
        button_font_face = "cfont",
        button_font_size = 20,
        buttons = {
            {
                {
                    text = _("No"),
                    callback = function()
                        self.no_callback()
                        UIManager:close(self)
                    end,
                },
                {
                    text = _("Vaguely"),
                    callback = function()
                        self.vaguley_callback()
                        UIManager:close(self)
                    end,
                },
                {
                    text = _("Yes"),
                    callback = function()
                        self.yes_callback()
                        UIManager:close(self)
                    end,
                },
            },
        },
        zero_sep = true,
        show_parent = self,
    }

    self[1] = CenterContainer:new{
        dimen = Screen:getSize(),
        FrameContainer:new{
            background = Blitbuffer.COLOR_WHITE,
            margin = self.margin,
            radius = Size.radius.window,
            padding = self.padding,
            padding_bottom = 0, -- no padding below buttontable
            VerticalGroup:new{
                align = "left",
                title,
                content,
                -- Add same vertical space after than before content
                VerticalSpan:new{ width = self.margin + self.padding },
                button_table,
            }
        }
    }
end

function FlashcardWidget:onShow()
    UIManager:setDirty(self, function()
        return "ui", self[1][1].dimen
    end)
end

function FlashcardWidget:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self[1][1].dimen
    end)
end

function FlashcardWidget:onClose()
    UIManager:close(self)
    return true
end

function FlashcardWidget:onTapClose(arg, ges)
    if ges.pos:notIntersectWith(self[1][1].dimen) then
        self:onClose()
        return true
    end
    return false
end

function FlashcardWidget:onSelect()
    logger.dbg("selected:", self.selected.x)
    if self.selected.x == 0 then
        self:no_callback()
    elseif self.selected.x == 1 then
        self:vaguley_callback()
    elseif self.selected.x == 2 then
        self:yes_callback()
    end
    UIManager:close(self)
    return true
end

return FlashcardWidget
