local event = event or require('event')
local zip = require('zip')

local archive_url = 'https://raw.githubusercontent.com/Stuk/jszip/main/test/ref/all.zip'
local z, open_err = zip.open(archive_url, 'r')
local entries = {}
local selected = 1

if z then
    entries = z:list() or {}
end

local function format_preview(raw)
    if not raw then
        return ''
    end
    local size = string.len(raw)
    for i = 1, size do
        local b = string.byte(raw, i)
        if b < 9 or (b > 13 and b < 32) then
            return string.format('[Binary content: %d bytes]', size)
        end
    end
    return raw
end

local function draw()
    canvas:clear()
    local w, h = canvas:attrSize()
    w = w or 1280
    h = h or 720

    canvas:attrColor(48, 48, 48, 255)
    canvas:drawRect('fill', 0, 0, w, h)

    canvas:attrColor(72, 72, 72, 255)
    canvas:drawRect('fill', 0, 0, w, 64)

    canvas:attrColor(255, 255, 255, 255)
    canvas:attrFont('default', 20, 'normal', 'bold')
    local title = z and ('NCLua zip Explorer (' .. tostring(#entries) .. ' files): ' .. tostring(z:attrPath()))
        or ('Failed to open ' .. archive_url .. ': ' .. tostring(open_err))
    canvas:drawTextRect(title, 24, 12, w - 48, 40, 'left', 'center')

    if not z then
        canvas:flush()
        return
    end

    local left_w = math.floor(w * 0.42)
    local panel_top = 84
    local panel_h = h - panel_top - 56

    canvas:attrColor(64, 64, 64, 255)
    canvas:drawRect('fill', 24, panel_top, left_w, panel_h)
    canvas:drawRect('fill', left_w + 44, panel_top, w - left_w - 68, panel_h)

    canvas:attrColor(200, 200, 200, 255)
    canvas:attrFont('default', 16, 'normal', 'bold')
    canvas:drawText('Archive Entries (z:list)', 40, panel_top + 16)
    canvas:drawText('Entry Content (z:read)', left_w + 60, panel_top + 16)

    for i, item in ipairs(entries) do
        local row_y = panel_top + 48 + (i - 1) * 44
        if i == selected then
            canvas:attrColor('gray')
            canvas:drawRect('fill', 34, row_y, left_w - 20, 36)
            canvas:attrColor(255, 255, 255, 255)
        else
            canvas:attrColor(220, 220, 220, 255)
        end
        canvas:attrFont('default', 16, 'normal', 'normal')
        canvas:drawTextRect(item, 46, row_y, left_w - 44, 36, 'left', 'center')
    end

    local current_file = entries[selected]
    if current_file and z:exists(current_file) then
        local content = format_preview(z:read(current_file))
        canvas:attrColor(230, 230, 230, 255)
        canvas:attrFont('default', 15, 'normal', 'bold')
        canvas:drawText(current_file, left_w + 60, panel_top + 52)

        canvas:attrColor(245, 245, 245, 255)
        canvas:attrFont('default', 15, 'normal', 'normal')
        canvas:drawTextRect(
            content,
            left_w + 60,
            panel_top + 84,
            w - left_w - 100,
            panel_h - 100,
            'left',
            'top'
        )
    end

    canvas:attrColor(190, 190, 190, 255)
    canvas:attrFont('default', 15, 'normal', 'normal')
    canvas:drawTextRect(
        'Use CURSOR_UP and CURSOR_DOWN to inspect archive files',
        24,
        h - 44,
        w - 48,
        32,
        'center',
        'center'
    )

    canvas:flush()
end

draw()

event.register(function(evt)
    if evt.class == 'key' and evt.type == 'press' and #entries > 0 then
        if evt.key == 'CURSOR_UP' then
            selected = selected - 1
            if selected < 1 then
                selected = #entries
            end
            draw()
        elseif evt.key == 'CURSOR_DOWN' then
            selected = selected + 1
            if selected > #entries then
                selected = 1
            end
            draw()
        end
    end
end)
