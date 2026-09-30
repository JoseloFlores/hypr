-- jo/updates-debian:widget
-- Muestra el numero de actualizaciones .deb + flatpak.
-- Solo visible cuando hay actualizaciones. Clic = instalar en alacritty.

local checking = false
local debCount = 0
local flatCount = 0
local totalCount = 0
local lastNotified = -1

local function cfg(key)
	return noctalia.getConfig(key)
end

local function checkScript()
	return (noctalia.pluginDir() or "") .. "/scripts/check-updates.sh"
end

local function render()
	if totalCount > 0 then
		barWidget.setVisible(true)
		barWidget.setGlyph("cloud-download")
		if cfg("show_count") then
			barWidget.setText(tostring(totalCount))
		else
			barWidget.setText("")
		end
		barWidget.setTooltip({
			{ key = ".deb", value = tostring(debCount) },
			{ key = "flatpak", value = tostring(flatCount) },
		})
	else
		barWidget.setText("")
		barWidget.clearTooltip()
		barWidget.setVisible(false)
	end
end

local function parseCounts(stdout)
	-- Espera "DEB FLAT TOTAL", ej. "3 2 5". Robusto ante ruido.
	local d, f, t = string.match(stdout or "", "(%d+)%s+(%d+)%s+(%d+)")
	if d == nil then
		return
	end
	debCount = tonumber(d) or 0
	flatCount = tonumber(f) or 0
	totalCount = tonumber(t) or 0
	if totalCount ~= debCount + flatCount then
		totalCount = debCount + flatCount
	end
	render()
	if totalCount > 0 and cfg("notify_on_updates") and totalCount ~= lastNotified then
		lastNotified = totalCount
		noctalia.notify(
			noctalia.tr("notification.updates_available"),
			".deb: " .. tostring(debCount) .. " / flatpak: " .. tostring(flatCount)
		)
	elseif totalCount == 0 then
		lastNotified = 0
	end
end

local function runCheck()
	if checking then
		return
	end
	checking = true
	local interval = cfg("interval_minutes") or 30
	local includeFlat = cfg("include_flatpak")
	local flatFlag = ""
	if includeFlat == false then
		flatFlag = " --no-flatpak"
	end
	local cmd = "bash '" .. checkScript() .. "'" .. flatFlag .. " " .. tostring(interval)
	noctalia.runAsync(cmd, function(res)
		checking = false
		if res.exitCode == 0 then
			parseCounts(res.stdout)
		else
			noctalia.log("check-updates fallo rc=" .. tostring(res.exitCode))
		end
	end)
end

-- Tick periodico. El chequeo real es barato (apt -s, sin sudo);
-- el intervalo configurable evita escanear de mas.
local intervalMin = cfg("interval_minutes") or 30
noctalia.setUpdateInterval(intervalMin * 60 * 1000)

-- Primer pintado: oculto hasta tener datos reales.
barWidget.setText("")
barWidget.setVisible(false)
runCheck()

function update()
	runCheck()
end

function onClick()
	local term = cfg("terminal") or "alacritty"
	if not noctalia.commandExists(term) then
		noctalia.notifyError(noctalia.tr("notification.no_terminal"))
		return
	end
	local autoYes = cfg("auto_yes")
	local yesFlag = ""
	if autoYes == false then
		yesFlag = " --no-yes"
	end
	local upgrade = (noctalia.pluginDir() or "") .. "/scripts/upgrade.sh"
	local cmd = term .. " -e bash '" .. upgrade .. "'" .. yesFlag
	if not noctalia.runAsync(cmd) then
		noctalia.notifyError(noctalia.tr("notification.launch_failed"))
	end
end

function onRightClick()
	-- Re-chequeo manual.
	checking = false
	runCheck()
end
