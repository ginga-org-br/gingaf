local event = event or require('event')

local logo = canvas.new('../assets/ginga-logo.png')

local x = 150
local y = 150
local w = 300
local h = 200
local step = 20

local function draw()
    canvas:clear()
    local screen_w, screen_h = canvas:attrSize()
    screen_w = screen_w or 1280
    screen_h = screen_h or 720
    canvas:attrColor('black')
    canvas:drawRect('fill', 0, 0, screen_w, screen_h)
    canvas:attrColor('white')
    canvas:attrFont('default', 20, 'normal', 'bold')
    canvas:drawTextRect('Guide: move the canvas items with cursor UP, DOWN, LEFT, RIGHT', 0, 20, screen_w, 40, 'center', 'center')
    canvas:attrColor(0, 156, 59, 255)
    canvas:drawRect('fill', x, y, w, h)
    canvas:attrColor(255, 223, 0, 255)
    canvas:drawPolygon({
        x + w / 2, y + 20,
        x + w - 25, y + h / 2,
        x + w / 2, y + h - 20,
        x + 25, y + h / 2
    })
    local d = 110
    canvas:attrColor(0, 39, 118, 255)
    canvas:drawEllipse('fill', x + (w - d) / 2, y + (h - d) / 2, d, d)
    canvas:attrColor(255, 255, 255, 255)
    canvas:attrFont('default', 14, 'normal', 'bold')
    canvas:drawTextRect('draw from nclua', x, y, w, h, 'center', 'center')
    canvas:compose(x + w + 40, y, logo)
    canvas:flush()
end

draw()

event.register(function(evt)
    if evt.class == 'key' and evt.type == 'press' then
        local key = evt.key
        if key == 'CURSOR_UP' then
            y = y - step
            draw()
        elseif key == 'CURSOR_DOWN' then
            y = y + step
            draw()
        elseif key == 'CURSOR_LEFT' then
            x = x - step
            draw()
        elseif key == 'CURSOR_RIGHT' then
            x = x + step
            draw()
        end
    end
end)
