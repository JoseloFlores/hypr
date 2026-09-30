--!nonstrict
-- jo/capture:service
-- Logica de video con wf-recorder (fork de h-jangra/region-recorder con fixes
-- Debian trixie multi-monitor ya integrados: codec ffmpeg + -o monitor).
-- El widget es solo presentacion; este servicio es singleton y sobrevive a
-- rebuilds del widget (ej. abrir settings a mitad de grabacion).

noctalia.setUpdateInterval(250)

local state = "idle" -- idle | selecting | recording
local isAvailable = false
local outputPath = ""
local recordingProcessName = "wf-recorder"
local tickCount = 0
local CHECK_TICKS = 8 -- 8 * 250ms = 2s entre chequeos

local function cfg(key) return noctalia.getConfig(key) end
local function log(msg) noctalia.log(`capture: {msg}`) end
local function shellQuote(val) return "'" .. tostring(val):gsub("'", [["'"']]) .. "'" end

local function publishStatus()
    noctalia.state.set("status", { state = state, available = isAvailable, outputPath = outputPath })
end

local function setState(nextState)
    if state == nextState then return end
    state = nextState
    publishStatus()
end

local function checkAvailability()
    return noctalia.commandExists("slurp") and noctalia.commandExists("wf-recorder")
end

local function outputDirectory()
    local configured = cfg("directory")
    local dir = noctalia.expandPath(if configured == "" or configured == nil then "~/Vídeos/Recordings" else configured)
    if dir:sub(-1) ~= "/" then dir ..= "/" end
    noctalia.mkdirAll(dir)
    return dir
end

local function copyToClipboard(path)
    local escapedPath = path:gsub(" ", "%%20"):gsub("'", "%%27"):gsub('"', "%%22")
    noctalia.copyToClipboard(`file://{escapedPath}`, "text/uri-list")
end

local function focusedMonitor(focusedOutputName)
    local mon = focusedOutputName
    if mon == nil or mon == "" then
        mon = noctalia.focusedOutputName()
    end
    if mon == nil or mon == "" then mon = "eDP-1" end
    return mon
end

local function buildRecordCommand(geom, targetPath, focusedOutputName)
    local fps = cfg("frame_rate") or 30
    local codec = cfg("video_codec") or "h264"
    local audioSource = cfg("audio_source") or "none"
    -- FIX Debian trixie: wf-recorder espera nombres ffmpeg (libx264...), no h264.
    local wfCodec = if codec == "hevc" then "libx265" elseif codec == "av1" then "libaom-av1" else "libx264"
    local parts = { "wf-recorder", string.format("-f %s", shellQuote(targetPath)), string.format("-r %d", fps), string.format("-c %s", wfCodec) }
    if geom and geom ~= "" and geom ~= "screen" then
        table.insert(parts, string.format("-g %s", shellQuote(geom)))
    end
    if geom == "screen" or geom == "" or geom == nil then
        -- FIX multi-monitor: sin -o wf-recorder pregunta por stdin y muere sin TTY.
        table.insert(parts, string.format("-o %s", shellQuote(focusedMonitor(focusedOutputName))))
    end
    if audioSource ~= "none" then table.insert(parts, "-a") end
    return table.concat(parts, " ")
end

local function startRecordingWithGeometry(geom, focusedOutputName)
    local dir = outputDirectory()
    local pattern = cfg("filename_pattern") or "Video_%Y%m%d_%H%M%S"
    local filename = `{noctalia.formatTime(pattern)}.mp4`
    outputPath = `{dir}{filename}`

    local cmd = buildRecordCommand(geom, outputPath, focusedOutputName)
    log(`executing recorder: {cmd}`)
    if noctalia.runAsync(cmd) then
        setState("recording")
        noctalia.notify(noctalia.tr("notify.recording_started"), outputPath)
    else
        setState("idle")
        outputPath = ""
        noctalia.notifyError(noctalia.tr("notify.recording_failed"))
    end
end

local function startSlurpSelection(focusedOutputName)
    if not isAvailable or state ~= "idle" then return end
    setState("selecting")
    log("starting slurp region selection...")

    noctalia.runAsync("sleep 0.2 && slurp -f '%x,%y %wx%h'", function(res)
        if state ~= "selecting" then return end
        if res.exitCode == 0 and res.stdout and res.stdout:match("%d+,%d+ %d+x%d+") then
            local geom = res.stdout:match("%d+,%d+ %d+x%d+")
            log(`slurp selected region: {geom}`)
            startRecordingWithGeometry(geom, focusedOutputName)
        else
            log("slurp selection cancelled or empty")
            setState("idle")
        end
    end)
end

local function stopRecording()
    if state ~= "recording" then return end
    log(`stopping recording: {outputPath}`)
    local targetEscaped = shellQuote(outputPath)
    noctalia.runAsync(string.format("pkill -SIGINT -x %s 2>/dev/null || pkill -SIGINT -f %s 2>/dev/null || true", shellQuote(recordingProcessName), targetEscaped))

    local savedPath = outputPath
    setState("idle")
    -- FIX: wf-recorder tarda en muxear el mp4 tras SIGINT; reintentar ~6s.
    noctalia.runAsync(string.format("for i in 1 2 3 4 5 6; do test -s %s && break; sleep 1; done; test -s %s", targetEscaped, targetEscaped), function(res)
        if res.exitCode == 0 then
            log(`recording saved: {savedPath}`)
            noctalia.notify(noctalia.tr("notify.recording_saved"):format(savedPath), savedPath)
            if cfg("copy_to_clipboard") then copyToClipboard(savedPath) end
        else
            log("recording stopped, file empty or missing")
            noctalia.notifyError(noctalia.tr("notify.recording_failed"), savedPath)
        end
        outputPath = ""
        publishStatus()
    end)
end

function update()
    tickCount += 1
    if state == "recording" and tickCount % CHECK_TICKS == 0 and outputPath ~= "" then
        noctalia.processMatches(function(matched)
            if not matched and state == "recording" then
                log("recording process exited externally")
                stopRecording()
            end
        end, recordingProcessName, outputPath)
    end
end

local function handleCommand(cmd)
    local action = if type(cmd) == "table" and cmd.action ~= nil then cmd.action else cmd
    if type(action) ~= "string" then return end
    local focusedOutputName = if type(cmd) == "table" then cmd.focusedOutputName else nil

    if action == "select-region" or action == "toggle-region" or action == "toggle" or action == "start" then
        if state == "recording" then
            if action == "toggle" or action == "toggle-region" then stopRecording() end
        elseif state == "idle" then
            startSlurpSelection(focusedOutputName)
        end
    elseif action == "record-fullscreen" then
        if state == "idle" then startRecordingWithGeometry("screen", focusedOutputName) end
    elseif action == "stop" then
        stopRecording()
    end
end

function onIpc(event, payload)
    -- CLI: `noctalia msg plugin jo/capture:service all <event> [payload]`
    -- Widget: state channel con tabla {action, focusedOutputName}.
    if type(payload) == "table" and payload.action ~= nil then
        handleCommand(payload)
    else
        handleCommand(event)
    end
end

isAvailable = checkAvailability()
if not isAvailable then log("wf-recorder or slurp missing; widget hidden unless hide_inactive=false") end
publishStatus()
noctalia.state.watch("command", handleCommand)
