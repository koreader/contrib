--[[--
This widget displays the calculator settings menu
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
local InputDialog = require("ui/widget/inputdialog")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local PathChooser = require("ui/widget/pathchooser")
local RadioButtonTable = require("ui/widget/radiobuttontable")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = require("device").screen
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local Parser = require("formulaparser/formulaparser")

local CalculatorSettingsDialog = InputContainer:new{
    is_always_active = true,
    title = _("Calculator settings"),
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
}

function CalculatorSettingsDialog:init()
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

    local radio_buttons_angle = {}
    for _, v in pairs(self.parent.angle_modes) do
        table.insert(radio_buttons_angle, {
            {
            text = v[2],
            checked = self.parent.angle_mode == v[1],
            provider = v[1],
            },
        })
    end

    local radio_buttons_format = {}
    for _, v in pairs(self.parent.number_formats) do
        table.insert(radio_buttons_format, {
            {
            text = v[2],
            checked = self.parent.number_format == v[1],
            provider = v[1],
            },
        })
    end

    local radio_buttons_init = {}
    table.insert(radio_buttons_init, {
        {
        text = "yes",
        checked = self.parent.use_init_file == "yes",
        provider = "yes",
        },
    })
    table.insert(radio_buttons_init, {
        {
        text = "no",
        checked = self.parent.use_init_file == "no",
        provider = "no",
        },
    })

    local radio_buttons_significant = {}
    for i = 0,10 do
        table.insert(radio_buttons_significant, {
            {
            text = i,
            checked = self.parent.significant_places == i,
            provider = i,
            },
        })
    end
    for i = 12,16,2 do
        table.insert(radio_buttons_significant, {
            {
            text = i,
            checked = self.parent.significant_places == i,
            provider = i,
            },
        })
    end

    local buttons = {{
        {
            text = "✕", --close
            callback = function()
                UIManager:close(self)
            end,
        },
        {
            text ="✓", --ok
            is_enter_default = true,
            callback = function()
                UIManager:close(self)
                local new_angle_mode = self.radio_button_table_angle.checked_button.provider
                if new_angle_mode ~= self.parent.angle_mode then
                    self.parent.angle_mode = new_angle_mode
                    if self.parent.angle_mode == "gon" then
                        Parser:eval(Parser:parse("setgon()"))
                    elseif self.parent.angle_mode == "degree" then
                        Parser:eval(Parser:parse("setdeg()"))
                    else
                        Parser:eval(Parser:parse("setrad()"))
                    end
                    G_reader_settings:saveSetting("calculator_angle_mode", new_angle_mode)
                    self.parent.status_line = self.parent:getStatusLine()
                end

                local new_format = self.radio_button_table_format.checked_button.provider
                if new_format ~= self.parent.number_format then
                    self.parent.number_format = new_format
                    G_reader_settings:saveSetting("calculator_number_format", new_format)
                    self.parent.status_line = self.parent:getStatusLine()
                end

                local new_significant = self.radio_button_table_significant.checked_button.provider
                if new_significant ~= self.parent.significant_places then
                    self.parent.significant_places = new_significant
                    G_reader_settings:saveSetting("calculator_significant_places", new_significant)
                    self.parent.status_line = self.parent:getStatusLine()
                end

                local new_init_file = self.radio_button_table_init.checked_button.provider
                if new_init_file ~= self.parent.use_init_file then
                    self.parent.use_init_file = new_init_file
                    G_reader_settings:saveSetting("calculator_use_init_file", new_init_file)
                end

                UIManager:close(self.parent.input_dialog)
                self.parent:onCalculatorStart()
            end,
        },
    }}

    self.radio_button_table_angle = RadioButtonTable:new{
        radio_buttons = radio_buttons_angle,
        width = math.floor(self.width * 0.4),
        focused = true,
        scroll = false,
        parent = self,
        face = self.face,
    }

    self.radio_button_table_format = RadioButtonTable:new{
        radio_buttons = radio_buttons_format,
        width = math.floor(self.width * 0.4),
        focused = true,
        scroll = false,
        parent = self,
        face = self.face,
    }

    self.radio_button_table_init = RadioButtonTable:new{
        radio_buttons = radio_buttons_init,
        width = math.floor(self.width * 0.4),
        focused = true,
        scroll = false,
        parent = self,
        face = self.face,
    }

    self.radio_button_table_significant = RadioButtonTable:new{
        radio_buttons = radio_buttons_significant,
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
                        h = self.radio_button_table_significant:getSize().h,
                },
                VerticalGroup:new{ -- angle and format
                    align = "center",
                    TextWidget:new{
                        text = _("Angle ∡"),
                        face =  self.text_face,
                    },
                    VerticalSpan:new{width = Size.span.vertical_large*2},
                    CenterContainer:new{
                        dimen = Geom:new{
                            w = self.title_bar:getSize().w * 0.4,
                            h = self.radio_button_table_angle:getSize().h,
                        },
                        self.radio_button_table_angle,
                    },
                    VerticalSpan:new{width = Size.span.vertical_large*4},
                    TextWidget:new{
                        text = _("Number format"),
                        face =  self.text_face,
                    },
                    CenterContainer:new{
                        dimen = Geom:new{
                            w = self.title_bar:getSize().w * 0.4,
                            h = self.radio_button_table_format:getSize().h,
                        },
                        self.radio_button_table_format,
                    },
                    VerticalSpan:new{width = Size.span.vertical_large*4},
                    TextWidget:new{
                        text = _("Autoload\ninit.calc"),
                        face =  self.text_face,
                    },
                    CenterContainer:new{
                        dimen = Geom:new{
                            w = self.title_bar:getSize().w * 0.4,
                            h = self.radio_button_table_init:getSize().h,
                        },
                        self.radio_button_table_init,
                    },
                },
                HorizontalSpan:new{width=self.title_bar:getSize().w * 0.1},
                VerticalGroup:new{ -- significance
                    align = "center",
                    -- significant
                    TextWidget:new{
                        text = _("Significance ≈"),
                        face =  self.text_face,
                    },

                    CenterContainer:new{
                        dimen = Geom:new{
                            w = self.title_bar:getSize().w * 0.4,
                            h = self.radio_button_table_significant:getSize().h,
                        },
                        self.radio_button_table_significant,
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

function CalculatorSettingsDialog:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.dialog_frame.dimen
    end)
end

function CalculatorSettingsDialog:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "ui", self[1][1].dimen
    end)
end


--[[--
chooses a path or (an existing) file (borrowed from coverimage)

@touchmenu_instance for updating of the menu
@string key is the G_reader_setting key which is used and changed
@boolean folder_only just selects a path, no file handling
@boolean new_file allows to enter a new filename, or use just an existing file
@function migrate(a,b) callback to a function to mangle old folder/file with new folder/file.
    Can be used for migrating the contents of the old path to the new one
]]
function CalculatorSettingsDialog:choosePathFile(touchmenu_instance, key, folder_only, new_file, migrate)
    local old_path, _ = util.splitFilePathName(self[key])
    UIManager:show(PathChooser:new{
        select_directory = folder_only or new_file,
        select_file = not folder_only,
        height = Screen:getHeight(),
        path = old_path,
        onConfirm = function(dir_path)
            local mode = lfs.attributes(dir_path, "mode")
            if folder_only then -- just select a folder
                if not dir_path:find("/$") then
                    dir_path = dir_path .. "/"
                end
                if migrate then
                    migrate(self, self[key], dir_path)
                end
                self[key] = dir_path
                G_reader_settings:saveSetting(key, dir_path)
                if touchmenu_instance then
                    touchmenu_instance:updateItems()
                end
            elseif new_file and mode == "directory" then -- new filename should be entered or a file could be selected
                local file_input
                file_input = InputDialog:new{
                    title =  _("Append filename"),
                    input = dir_path .. "/",
                    buttons = {{
                        {
                            text = _("Cancel"),
                            callback = function()
                                UIManager:close(file_input)
                            end,
                        },
                        {
                            text = _("Save"),
                            callback = function()
                                local file = file_input:getInputText()
                                if migrate and self[key] and self[key] ~= "" then
                                    migrate(self, self[key], file)
                                end
                                self[key] = file
                                G_reader_settings:saveSetting(key, file)
                                if touchmenu_instance then
                                    touchmenu_instance:updateItems()
                                end
                                UIManager:close(file_input)
                            end,
                        },
                    }},
                }
                UIManager:show(file_input)
                file_input:onShowKeyboard()
            elseif mode == "file" then   -- just select an existing file
                if migrate then
                    migrate(self, self[key], dir_path)
                end
                self[key] = dir_path
                G_reader_settings:saveSetting(key, dir_path)
                if touchmenu_instance then
                    touchmenu_instance:updateItems()
                end
            end
        end,
    })
end

return CalculatorSettingsDialog
