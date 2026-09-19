local event = event or require('event')

local userId = ""
local userName = ""
local userGender = ""
local userAge = ""

local function draw()
    canvas:clear()
    local w, h = canvas:attrSize()
    w = w or 1280
    h = h or 100
    canvas:attrColor(15, 20, 30, 220)
    canvas:drawRoundRect('fill', 0, 0, w, h, 12, 12)
    canvas:attrColor(80, 120, 200, 255)
    canvas:drawRoundRect('frame', 0, 0, w, h, 12, 12)
    canvas:attrColor(255, 255, 255, 255)
    canvas:attrFont('default', 22, 'normal', 'bold')
    local text = string.format('currentUser: "id": %s    "name": %s    "gender": %s    "age": %s',
        tostring(userId), tostring(userName), tostring(userGender), tostring(userAge))
    canvas:drawTextRect(text, 20, 0, w - 40, h, 'center', 'center')
    canvas:flush()
end

draw()

event.register(function(evt)
    if evt.class == 'ncl' and evt.type == 'attribution' then
        local prop = evt.name
        local val = evt.value
        if prop == 'userId' or prop == 'id' then
            userId = val
        elseif prop == 'userName' or prop == 'name' then
            userName = val
        elseif prop == 'userGender' or prop == 'gender' then
            userGender = val
        elseif prop == 'userAge' or prop == 'age' then
            userAge = val
        end
        draw()
    end
end)
