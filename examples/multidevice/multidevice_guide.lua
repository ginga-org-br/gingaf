local event = event or require('event')

local vrDevNumber = "0"
local accDevNumber = "0"

local function draw()
    canvas:clear()
    local w, h = canvas:attrSize()
    w = w or 1280
    h = h or 120
    canvas:attrColor(18, 22, 30, 215)
    canvas:drawRoundRect('fill', 0, 0, w, h, 12, 12)
    canvas:attrColor(60, 130, 220, 255)
    canvas:drawRoundRect('frame', 0, 0, w, h, 12, 12)
    canvas:attrColor(255, 255, 255, 255)
    canvas:attrFont('default', 20, 'normal', 'bold')
    canvas:drawTextRect(
        'TV 3.0 Multi-Device Guide: see VR 360 on ncl-360-vr device and streamed Libras glosses on accessibility device',
        20, 10, w - 40, 44, 'center', 'center'
    )
    canvas:attrColor(190, 220, 255, 255)
    canvas:attrFont('default', 18, 'normal', 'bold')
    canvas:drawTextRect(
        string.format('ncl-360-vr.devNumber = %s   |   accessibility.devNumber = %s', tostring(vrDevNumber), tostring(accDevNumber)),
        20, 58, w - 40, 44, 'center', 'center'
    )
    canvas:flush()
end

draw()

event.register(function(evt)
    if evt.class == 'ncl' and evt.type == 'attribution' then
        if evt.name == 'vrDevNumber' then
            vrDevNumber = tostring(evt.value or '0')
        elseif evt.name == 'accDevNumber' then
            accDevNumber = tostring(evt.value or '0')
        end
        draw()
    end
end)
