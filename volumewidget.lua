local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")

-- Configuration
local refresh_rate = 1 -- seconds between volume updates
local volume_step = 5 -- volume change percentage per scroll step
local volume_icons = {
    low = "󰕿",
    medium = "󰖀",
    high = "󰕾",
    muted = "󰝟"
}

-- Create the widget
local volume_widget = wibox.widget {
    {
        id = "icon",
        widget = wibox.widget.textbox,
    },
    {
        id = "text",
        widget = wibox.widget.textbox
    },
    layout = wibox.layout.fixed.horizontal,
    set_volume = function(self, level, muted)
        local icon
        if muted or (level and level == 0) then
            icon = volume_icons.muted
        elseif level then
            if level < 33 then
                icon = volume_icons.low
            elseif level < 66 then
                icon = volume_icons.medium
            else
                icon = volume_icons.high
            end
        else
            icon = "?"
        end

        self:get_children_by_id("icon")[1]:set_text(icon)
        self:get_children_by_id("text")[1]:set_text(level and (" " .. level .. "%") or " N/A")
    end
}
-- Set font after creation
volume_widget:get_children_by_id("icon")[1].font = beautiful.icon_font or "Monospace 12"

-- Track hover state
local is_hovered = false

-- Function to get current volume
local function get_volume()
    awful.spawn.easy_async("wpctl get-volume @DEFAULT_AUDIO_SINK@", function(stdout)
        local volume = stdout:match("Volume:%s*([%d%.]+)")
        local muted = stdout:find("%[MUTED%]") ~= nil
        if volume then
            local vol_level = math.floor(tonumber(volume) * 100)
            volume_widget:set_volume(vol_level, muted)
        else
            volume_widget:set_volume(nil, false)
        end
    end)
end

-- Function to set volume
local function set_volume(level)
    awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. (level/100), false)
    -- Force unmute when changing volume
    awful.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0", false)
    gears.timer.start_new(0.1, function() get_volume(); return false end)
end

local function set_volume_step(step)
    awful.spawn.easy_async("wpctl get-volume @DEFAULT_AUDIO_SINK@", function(stdout)
        local current_vol = stdout:match("Volume:%s*([%d%.]+)")
        if current_vol then
            current_vol = tonumber(current_vol) * 100
            local new_vol = math.max(0, math.min(100, current_vol + step))
            set_volume(new_vol)
        end
    end)
end

-- Function to toggle mute
local function toggle_mute()
    awful.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", false)
    gears.timer.start_new(0.1, function() get_volume(); return false end)
end

-- Mouse enter/leave events
volume_widget:connect_signal("mouse::enter", function()
    is_hovered = true
    get_volume()
end)
volume_widget:connect_signal("mouse::leave", function()
    is_hovered = false
end)

-- Click and scroll events
volume_widget:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then -- Left click toggles mute
        toggle_mute()
    elseif is_hovered and (button == 4 or button == 5) then -- Scroll
        awful.spawn.easy_async("wpctl get-volume @DEFAULT_AUDIO_SINK@", function(stdout)
            local current_vol = stdout:match("Volume:%s*([%d%.]+)")
            if current_vol then
                current_vol = tonumber(current_vol) * 100
                local new_vol
                if button == 4 then -- Scroll up
                    new_vol = math.min(100, current_vol + volume_step)
                else -- Scroll down
                    new_vol = math.max(0, current_vol - volume_step)
                end
                set_volume(new_vol)
            end
        end)
    end
end)

-- Initialize timer to update volume
local volume_timer = gears.timer {
    timeout = refresh_rate,
    call_now = true,
    autostart = true,
    callback = get_volume
}

-- Wrap your widget with margin and prevent mouse events from propagating
local volume_widget_with_margin = wibox.widget {
    {
        volume_widget,
        left = 10,  -- space before
        right = 10, -- space after
        widget = wibox.container.margin
    },
    widget = wibox.container.background,
    buttons = {} -- disables mouse events on the margin area
}

return {
    widget = volume_widget_with_margin,
    set_volume = set_volume,
    set_volume_step = set_volume_step,
    toggle_mute = toggle_mute,
    get_volume = get_volume
}
