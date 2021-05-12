--Generated from clockwidget.moon
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local ImageWidget = require("ui/widget/imagewidget")
local RenderImage = require("ui/renderimage")
local UIManager = require("ui/uimanager")
local Screen = Device.screen
local Size = require("ui/size")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local logger = require("logger")
local date
date = os.date
local PLUGIN_ROOT = package.path:match('([^;]*clock%.koplugin/)')
local rotate_point
rotate_point = function(point_x, point_y, center_x, center_y, angle_rad)
  local sin, cos, floor
  do
    local _obj_0 = math
    sin, cos, floor = _obj_0.sin, _obj_0.cos, _obj_0.floor
  end
  local s, c = sin(angle_rad), cos(angle_rad)
  local x, y = (point_x - center_x), (point_y - center_y)
  local new_x, new_y = (x * c - y * s), (x * s + y * c)
  return floor(center_x + new_x + 0.5), floor(center_y + new_y + 0.5)
end
local rotate_bb
rotate_bb = function(bb, center_x, center_y, angle_rad)
  local w, h = bb:getWidth(), bb:getHeight()
  local rot_bb = Blitbuffer.new(w, h, bb:getType())
  w, h = w - 1, h - 1
  for x = 0, w do
    for y = 0, h do
      local old_x, old_y = rotate_point(x, y, center_x, center_y, angle_rad)
      if old_x >= 0 and old_x <= w and old_y >= 0 and old_y <= h then
        rot_bb:setPixel(x, y, bb:getPixel(old_x, old_y))
      end
    end
  end
  return rot_bb
end
local ClockWidget = WidgetContainer:new({
  width = Screen:scaleBySize(200),
  height = Screen:scaleBySize(200),
  padding = Size.padding.large,
  scale_factor = 0,
  _hands = { }
})
ClockWidget.init = function(self)
  local padding = self.padding
  local width, height = self.width - 2 * padding, self.height - 2 * padding
  self._orig_screen_mode = Screen:getScreenMode()
  self.face = CenterContainer:new({
    dimen = self:getSize(),
    ImageWidget:new({
      file = tostring(PLUGIN_ROOT) .. "face.png",
      width = width,
      height = height,
      scale_factor = self.scale_factor,
      alpha = true
    })
  })
  self._hours_hand_bb = RenderImage:renderImageFile(tostring(PLUGIN_ROOT) .. "hours.png")
  self._minutes_hand_bb = RenderImage:renderImageFile(tostring(PLUGIN_ROOT) .. "minutes.png")
  self.autoRefreshTime = function()
    UIManager:setDirty("all", function()
      return "ui", self.dimen, true
    end)
    return UIManager:scheduleIn(60 - tonumber(date("%S")), self.autoRefreshTime)
  end
end
ClockWidget.paintTo = function(self, bb, x, y)
  local h, m = tonumber(date("%H")), tonumber(date("%M"))
  local hands = self._hands[60 * h + m] or self:_updateHands(h, m)
  bb:fill(Blitbuffer.COLOR_WHITE)
  local size = self:getSize()
  x, y = x + self.width / 2, y + self.height / 2
  if Screen:getScreenMode() ~= self._orig_screen_mode then
    x, y = y, x
  end
  self.face:paintTo(bb, x, y)
  hands.hours:paintTo(bb, x, y)
  hands.minutes:paintTo(bb, x, y)
  if Screen.night_mode then
    return bb:invertRect(x, y, size.w, size.h)
  end
end
ClockWidget._prepareHands = function(self, hours, minutes)
  local idx = hours * 60 + minutes
  if self._hands[idx] then
    return self._hands[idx]
  end
  self._hands[idx] = { }
  local hour_rad, minute_rad = -math.pi / 6, -math.pi / 30
  local padding = self.padding
  local width, height = self.width - 2 * padding, self.height - 2 * padding
  local hours_hand_bb = rotate_bb(self._hours_hand_bb, self._hours_hand_bb:getWidth() / 2, self._hours_hand_bb:getHeight() / 2, (hours + minutes / 60) * hour_rad)
  local minutes_hand_bb = rotate_bb(self._minutes_hand_bb, self._minutes_hand_bb:getWidth() / 2, self._minutes_hand_bb:getHeight() / 2, minutes * minute_rad)
  local hours_hand_widget = ImageWidget:new({
    image = hours_hand_bb,
    width = width,
    height = height,
    scale_factor = self.scale_factor,
    alpha = true
  })
  local minutes_hand_widget = ImageWidget:new({
    image = minutes_hand_bb,
    width = width,
    height = height,
    scale_factor = self.scale_factor,
    alpha = true
  })
  self._hands[idx].hours = CenterContainer:new({
    dimen = self:getSize(),
    hours_hand_widget
  })
  self._hands[idx].minutes = CenterContainer:new({
    dimen = self:getSize(),
    minutes_hand_widget
  })
  local n_hands = 0
  for __ in pairs(self._hands) do
    n_hands = n_hands + 1
  end
  logger.dbg("ClockWidget: hands ready for", hours, minutes, ":", n_hands, "position(s) in memory.")
  return self._hands[idx]
end
ClockWidget._updateHands = function(self)
  local hours, minutes = tonumber(date("%H")), tonumber(date("%M"))
  local floor, fmod
  do
    local _obj_0 = math
    floor, fmod = _obj_0.floor, _obj_0.fmod
  end
  UIManager:scheduleIn(50, function()
    local idx = hours * 60 + minutes
    for k in pairs(self._hands) do
      if (idx < 24 * 60 - 2) and (k - idx < 0) or (k - idx > 2) then
        self._hands[k] = nil
      end
    end
    local fut_minutes = minutes + 1
    local fut_hours = fmod(hours + floor(fut_minutes / 60), 24)
    fut_minutes = fmod(fut_minutes, 60)
    return self:_prepareHands(fut_hours, fut_minutes)
  end)
  return self:_prepareHands(hours, minutes)
end
ClockWidget.onShow = function(self)
  return self:autoRefreshTime()
end
ClockWidget.onCloseWidget = function(self)
  return UIManager:unschedule(self.autoRefreshTime)
end
ClockWidget.onSuspend = function(self)
  return UIManager:unschedule(self.autoRefreshTime)
end
ClockWidget.onResume = function(self)
  return self:autoRefreshTime()
end
return ClockWidget
