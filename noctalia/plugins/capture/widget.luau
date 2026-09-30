--!nonstrict
-- jo/capture:capture — un solo widget para foto + video.
--   click-izq  = foto region (nativo screenshot-region, respeta [shell.screenshot])
--   click-medio = foto pantalla (nativo screenshot-fullscreen)
--   click-der  = video toggle: region (slurp) si idle, stop si grabando
-- El video lo posee el [[service]] via canal "command"/"status".

local state, available = "idle", true

local function send(action)
    noctalia.state.set("command", { action = action, nonce = noctalia.nowMs(), focusedOutputName = noctalia.focusedOutputName() })
end

local function applyStatus(status)
    if type(status) == "table" then
        state = status.state or "idle"
        available = if status.available ~= nil then status.available else true
    end

    local hideInactive = noctalia.getConfig("hide_inactive")
    if not available then
        barWidget.setGlyph("camera-off")
        barWidget.setGlyphColor("on_surface_variant")
        barWidget.setTooltip(noctalia.tr("widget.unavailable"))
        barWidget.setVisible(not hideInactive)
        return
    end

    if state == "recording" then
        barWidget.setGlyph("disc")
        barWidget.setGlyphColor("error")
        if type(barWidget.setColor) == "function" then barWidget.setColor("error") end
        barWidget.setTooltip(noctalia.tr("widget.recording"))
        barWidget.setVisible(true)
    elseif state == "selecting" then
        barWidget.setGlyph("crosshair")
        barWidget.setGlyphColor("primary")
        if type(barWidget.setColor) == "function" then barWidget.setColor("primary") end
        barWidget.setTooltip(noctalia.tr("widget.selecting"))
        barWidget.setVisible(true)
    else
        barWidget.setGlyph("camera")
        barWidget.setGlyphColor("on_surface")
        if type(barWidget.setColor) == "function" then barWidget.setColor("") end
        barWidget.setTooltip(noctalia.tr("widget.idle"))
        barWidget.setVisible(not hideInactive)
    end
end

function onClick()
    -- Foto region via IPC nativo (misma politica que el widget screenshot).
    noctalia.runAsync("noctalia msg screenshot-region")
end

function onRightClick()
    if not available then return end
    if state == "idle" then
        send("toggle-region")
    else
        send("stop")
    end
end

function onMiddleClick()
    noctalia.runAsync("noctalia msg screenshot-fullscreen")
end

function onIpc(event, _payload)
    -- Atajos externos sin pasar por el service:
    -- `noctalia msg plugin jo/capture:capture focused photo` => foto region.
    if event == "photo" then
        onClick()
    elseif event == "photo-fullscreen" then
        onMiddleClick()
    elseif event == "video" then
        onRightClick()
    end
end

applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
