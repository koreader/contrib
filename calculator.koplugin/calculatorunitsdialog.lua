--[[--
This widget displays the calculator units menu
]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local RadioButtonTable = require("ui/widget/radiobuttontable")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = require("device").screen

local CalculatorUnitsDialog = InputContainer:new{
    is_always_active = true,
    title = _("Units to convert"),
    modal = true,
    stop_events_propagation = true,
    width = math.floor(Screen:getWidth() * 0.8),
    face = Font:getFace("cfont", 22),
    title_face = Font:getFace("x_smalltfont"),
    title_padding = Size.padding.default,
    title_margin = Size.margin.title,
    text_face = Font:getFace("smallinfofont"),
    button_padding = Size.padding.default,
    border_size = Size.border.window,
    units = {{"cm", .01}, {"inch", 254}},
}

function CalculatorUnitsDialog:init()
    -- Title & description
    self.title_widget = FrameContainer:new{
        padding = self.title_padding,
        margin = self.title_margin,
        bordersize = 0,
        TextWidget:new{
            text = self.title,
            face = self.title_face,
            max_width = self.width,
        }
    }
    self.title_bar = LineWidget:new{
        dimen = Geom:new{
            w = self.width,
            h = Size.line.thick,
        }
    }

    local radio_buttons_units = {}
    for _, v in pairs(self.units) do
        table.insert(radio_buttons_units, {
            {
            text = v[1],
            checked = v[3] ~= nil,
            provider = v[2],
            },
        })
    end

    local buttons = {{
        {
            text = "✕", --close
            callback = function()
                UIManager:close(self.parent.units_dialog)
            end,
        },
        {
            text ="✓", --ok
            is_enter_default = true,
            callback = function()
                UIManager:close(self.parent.units_dialog)
--                local value = self.
                local from = self.radio_button_table_units_from.checked_button.provider
                local too = self.radio_button_table_units_too.checked_button.provider
                local comment = "  // " .. self.radio_button_table_units_from.checked_button.text
                    .. " -> " .. self.radio_button_table_units_too.checked_button.text
                local calc = self.parent.parent

                -- if no input, in the actual line -> insert `ans`
                calc.input_dialog._input_widget:goToEndOfLine()
                local start_location = calc.input_dialog._input_widget.charpos
                calc.input_dialog._input_widget:goToStartOfLine()
                local end_location = calc.input_dialog._input_widget.charpos
                if start_location == end_location then
                    calc.input_dialog._input_widget:addChars("ans")
                    calc.input_dialog._input_widget:goToStartOfLine()
                end

                if type(from) == "number" and type(too) == "number" then
                    -- braces around input
                    calc.input_dialog._input_widget:addChars("(")
                    calc.input_dialog._input_widget:goToEndOfLine()
                    calc.input_dialog._input_widget:addChars(")")
                    -- do the conversion
                    calc.input_dialog._input_widget:addChars("*(" .. tostring(from) .. "/" .. tostring(too) ..")" .. comment)
                else
                    calc.input_dialog._input_widget:addChars(from .. "(")

                    calc.input_dialog._input_widget:goToStartOfLine()
                    calc.input_dialog._input_widget:addChars(too:reverse() .. "(")

                    calc.input_dialog._input_widget:goToEndOfLine()
                    calc.input_dialog._input_widget:addChars("))" .. comment)
                end

                calc:calculate(calc.input_dialog:getInputText())
                calc.input_dialog:setInputText(calc.history)
                calc:gotoEnd()
            end,
        },
    }}

    self.radio_button_table_units_from = RadioButtonTable:new{
        radio_buttons = radio_buttons_units,
        width = math.floor(self.width * 0.4),
        focused = true,
        scroll = false,
        parent = self,
        face = self.face,
    }
    self.radio_button_table_units_too = RadioButtonTable:new{
        radio_buttons = radio_buttons_units,
        width = math.floor(self.width * 0.4),
        focused = true,
        scroll = false,
        parent = self,
        face = self.face,
    }

    -- Buttons Table
    self.button_table = ButtonTable:new{
        width = self.width - 2*self.button_padding,
        button_font_face = "cfont",
        button_font_size = 20,
        buttons = buttons,
        zero_sep = true,
        show_parent = self,
    }

    self.dialog_frame = FrameContainer:new{
        radius = Size.radius.window,
        bordersize = Size.border.window,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "center",
            self.title_widget,
            self.title_bar,
            HorizontalGroup:new{
                    dimen = Geom:new{
                        w = self.title_bar:getSize().w,
                        h = self.radio_button_table_units_from:getSize().h,
                },
                HorizontalSpan:new{width=self.title_bar:getSize().w * 0.1},
                VerticalGroup:new{
                    align = "left",
                    TextWidget:new{
                        text = _(" from:"),
                        face =  self.text_face,
                    },
                    CenterContainer:new{
                        dimen = Geom:new{
                            w = self.title_bar:getSize().w * 0.4,
                            h = self.radio_button_table_units_from:getSize().h,
                        },
                        self.radio_button_table_units_from,
                    },
                },
                VerticalGroup:new{
                    align = "left",
                    TextWidget:new{
                        text = _(" to:"),
                        face =  self.text_face,
                    },

                    CenterContainer:new{
                        dimen = Geom:new{
                            w = self.title_bar:getSize().w * 0.4,
                            h = self.radio_button_table_units_too:getSize().h,
                        },
                        self.radio_button_table_units_too,
                    },
                },
            },

            VerticalSpan:new{width = Size.span.vertical_large*2},
            -- buttons
            CenterContainer:new{
                dimen = Geom:new{
                    w = self.title_bar:getSize().w,
                    h = self.button_table:getSize().h,
                },
                self.button_table,
            }
        }
    }

    self.movable = MovableContainer:new{
        self.dialog_frame,
    }
    self[1] = CenterContainer:new{
        dimen = Screen:getSize(),
        self.movable,
    }
end

function CalculatorUnitsDialog:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.dialog_frame.dimen
    end)
end

function CalculatorUnitsDialog:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self[1][1].dimen
    end)
end

return CalculatorUnitsDialog
