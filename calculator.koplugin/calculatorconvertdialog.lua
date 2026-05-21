--[[--
This widget displays the calculator convert menu
]]

local ButtonDialog = require("ui/widget/buttondialog")
local CalculatorUnitsDialog = require("calculatorunitsdialog")
local Font = require("ui/font")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local Screen = require("device").screen
local ffiUtil = require("ffi/util")

local length_table = {
    {"Å",10e-10},
    {"nm",1e-9},
    {"µm",1e-6},
    {"mm",1e-3},
    {"cm",1e-2},
    {"dm",1e-1},
    {"m",1, true},
    {"km",1e3},
    {"Mm",1e6},
    {"inch",0.0254},
    {"foot",0.3048},
    {"yard",0.9144},
    {"mile",1609.344},
    {"AE",149597870700},
    {"LightYear",9460730472580800},
    {"parsec",3.0857e16},
}

local mass_table = {
    {"µg",1e-9},
    {"mg",1e-6},
    {"g",1e-3},
    {"dag",1e-2},
    {"kg",1, true},
    {"t",1e3},
    {"oz",28.349523125e-3},
    {"lb",453.59237e-3},
    {"st",6.35029318},
}

local time_table = {
    {"ns",1e-9},
    {"µs",1e-6},
    {"ms",1e-3},
    {"s",1, true},
    {"min",60},
    {"h",3600},
    {"day",3600*24},
    {"week",3600*24*7},
    {"month",3600*24*30},
    {"year",3600*24*365.2425},
}

local energy_table = {
    {"J",1, true},
    {"kJ",1e3},
    {"MJ",1e6},
    {"kWh",1e3*3600},
    {"cal",4.1858},
    {"kCal",4186.6},
    {"BTU",1055.05585262},
}

local power_table = {
    {"W",1, true},
    {"kW",1e3},
    {"MW",1e6},
    {"cal/s",4.1858},
    {"PS",735.5},
    {"BTU/h",293.07107017},
}

local speed_table = {
    {"m/s",1, true},
    {"km/h",1/3.6},
    {"ft/s",1/2.23604},
    {"mph",1/2.2364},
    {"knots",1/1.94338},
}

local area_table = {
    {"mm²",1e-6},
    {"cm²",1e-4},
    {"dm²",1e-2},
    {"m²",1, true},
    {"a",1e2},
    {"ha",1e4},
    {"km²",1e6},
}

local volume_table = {
    {"mm³",1e-9},
    {"cm³",1e-6},
    {"dm³",1e-3},
    {"l",1e-3},
    {"m³",1, true},
    {"km³",1e9},
}

local pressure_table = {
    {"mPa",1e-3},
    {"Pa",1, true},
    {"hPa",1e2},
    {"kPa",1e3},
    {"MPa",1e6},
    {"mbar",1e2},
    {"bar",1e5},
    {"atm",101325},
    {"kg/cm²",1e9},
    {"mmHg",133.322},
    {"Torr",133.32},
    {"psi",6894.76},
}


local temperature_table = {
    {"°C", "c2k"},
    {"K", "", true },
    {"°F", "f2k"},
}


local CalculatorConvertDialog = InputContainer:new{
    is_always_active = true,
    title = title or _("Convert"),
    modal = true,
    width = math.floor(Screen:getWidth() * 0.8),
    face = Font:getFace("cfont", 22),
    title_face = Font:getFace("x_smalltfont"),
    title_padding = Size.padding.default,
    title_margin = Size.margin.title,
    text_face = Font:getFace("smallinfofont"),
    button_padding = Size.padding.default,
    border_size = Size.border.window,
}

function CalculatorConvertDialog:init()
    local convert_buttons = {
        ["01_length"] = {
            text = "Length",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = length_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["02_area"] = {
            text = "Area",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = area_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["03_volume"] = {
            text = "Volume",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = volume_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["04_speed"] = {
            text = "Speed",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = speed_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["05_time"] = {
            text = "Time",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = time_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["06_energy"] = {
            text = "Energy",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = energy_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["07_power"] = {
            text = _("Power"),
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = power_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["08_mass"] = {
            text = "Mass",
            is_enter_default = true,
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = mass_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["09_pressure"] = {
            text = "Pressure",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = pressure_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
        ["10_temperature"] = {
            text = "Temperature",
            callback = function()
                UIManager:close(self)
                self.units_dialog = CalculatorUnitsDialog:new{
                    parent = self,
                    units = temperature_table,
                    }
                UIManager:show(self.units_dialog)
            end,
        },
--[[
        ["98_dummy"] = {
            text = "",
        },
]]
        ["99_close"] = {
            text = "✕", --close
            callback = function()
                UIManager:close(self)
            end,
        },
    }

    local highlight_buttons = {{}}
    local columns = 2
    for _, button in ffiUtil.orderedPairs(convert_buttons) do
        if #highlight_buttons[#highlight_buttons] >= columns then
            table.insert(highlight_buttons, {})
        end
        table.insert(highlight_buttons[#highlight_buttons], button)
    end

    self[1] = ButtonDialog:new{
        title = self.title or _("♺ Convert"),
        title_align = "center",
        buttons = highlight_buttons,
    }
end

function CalculatorConvertDialog:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function CalculatorConvertDialog:onClose()
    UIManager:setDirty(nil, function()
        return "ui", self[1][1].dimen
    end)
end

return CalculatorConvertDialog
