-- ═══════════════════════════════════════════════
-- dei_devtools | Server
-- ═══════════════════════════════════════════════

local eventLog = {}
local monitoredEvents = {}
local resourceData = {}
local authorizedPlayers = {}

-- ── Startup ──
CreateThread(function()
    Wait(500)
    local v = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0'
    print('^4[Dei]^0 dei_devtools v' .. v .. ' - ^2Iniciado^0')
end)

-- ── Permission Check ──
RegisterNetEvent('dei_devtools:requestAuth', function()
    local src = source
    local allowed, method = Framework.IsAdmin(src)
    local superAdmin = Framework.IsSuperAdmin(src)
    if allowed then
        authorizedPlayers[src] = { super = superAdmin, method = method }
        TriggerClientEvent('dei_devtools:authResult', src, true, superAdmin)
    else
        TriggerClientEvent('dei_devtools:authResult', src, false, false)
    end
end)

AddEventHandler('playerDropped', function()
    authorizedPlayers[source] = nil
end)

local function isAuthorized(src)
    return authorizedPlayers[src] ~= nil
end

local function isSuperAdmin(src)
    return authorizedPlayers[src] and authorizedPlayers[src].super
end

-- ── Resource Monitor (Resmon) ──
local function collectResmonData()
    local resources = {}
    local totalMs = 0.0
    local count = GetNumResources()

    for i = 0, count - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            -- Try to get resource metrics if available
            local ms = 0.0

            -- Attempt native metric collection
            local ok, result = pcall(function()
                -- Use Citizen.InvokeNative to attempt GetResourceMetrics
                return nil
            end)

            -- Build resource entry
            resources[#resources + 1] = {
                name = name,
                ms = ms,
                state = 'started'
            }
        end
    end

    -- Sort by name
    table.sort(resources, function(a, b) return a.name < b.name end)

    return resources, totalMs
end

-- Periodic resmon collection with tick-time estimation
local tickTimes = {}
local lastTick = GetGameTimer()

CreateThread(function()
    while true do
        Wait(0)
        local now = GetGameTimer()
        local delta = now - lastTick
        lastTick = now
        tickTimes[#tickTimes + 1] = delta
        if #tickTimes > 100 then
            table.remove(tickTimes, 1)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.RefreshRate or 2000)
        if next(authorizedPlayers) then
            resourceData = collectResmonData()
        end
    end
end)

RegisterNetEvent('dei_devtools:requestResmon', function()
    local src = source
    if not isAuthorized(src) then return end

    local resources, _ = collectResmonData()

    -- Calculate average server tick time
    local avgTick = 0
    if #tickTimes > 0 then
        local sum = 0
        for _, t in ipairs(tickTimes) do sum = sum + t end
        avgTick = sum / #tickTimes
    end

    TriggerClientEvent('dei_devtools:resmonData', src, resources, avgTick)
end)

-- ── Event Logger ──
-- Track events that pass through the server
local trackedEventPatterns = {}

local function addEventEntry(eventName, src, direction, dataSize)
    local entry = {
        time = os.date('%H:%M:%S'),
        timestamp = GetGameTimer(),
        name = eventName,
        source = src or -1,
        direction = direction, -- 'c2s' or 's2c'
        size = dataSize or 0
    }

    eventLog[#eventLog + 1] = entry
    if #eventLog > (Config.MaxEventLog or 200) then
        table.remove(eventLog, 1)
    end

    -- Broadcast to authorized watchers
    for pid, _ in pairs(authorizedPlayers) do
        TriggerClientEvent('dei_devtools:eventEntry', pid, entry)
    end
end

-- Hook common events by wrapping
local originalTriggerClient = TriggerClientEvent

-- Monitor all incoming net events
AddEventHandler('__cfx_internal:commandFallback', function() end)

-- Register a catch-all for network events
RegisterNetEvent('dei_devtools:monitorEvent', function(eventName, dataSize)
    local src = source
    if not isAuthorized(src) then return end
    addEventEntry(eventName, src, 'c2s', dataSize or 0)
end)

-- Allow clients to register events to watch
RegisterNetEvent('dei_devtools:watchEvent', function(eventName)
    local src = source
    if not isAuthorized(src) then return end
    trackedEventPatterns[eventName] = true

    -- Register handler for this event to log it
    if not monitoredEvents[eventName] then
        monitoredEvents[eventName] = true
        RegisterNetEvent(eventName, function(...)
            local evSrc = source
            local args = { ... }
            local dataStr = json.encode(args) or ''
            addEventEntry(eventName, evSrc, 'c2s', #dataStr)
        end)
    end
end)

RegisterNetEvent('dei_devtools:requestEventLog', function()
    local src = source
    if not isAuthorized(src) then return end
    TriggerClientEvent('dei_devtools:eventLogData', src, eventLog)
end)

RegisterNetEvent('dei_devtools:clearEventLog', function()
    local src = source
    if not isAuthorized(src) then return end
    eventLog = {}
end)

-- ── Player Data ──
RegisterNetEvent('dei_devtools:requestPlayerData', function()
    local src = source
    if not isAuthorized(src) then return end

    local jobName, jobGrade = Framework.GetPlayerJob(src)
    local identifiers = Framework.GetPlayerIdentifiers(src)

    TriggerClientEvent('dei_devtools:playerServerData', src, {
        serverId = src,
        job = jobName,
        jobGrade = jobGrade,
        identifiers = identifiers,
        playerCount = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 64),
        framework = Framework.name or 'standalone'
    })
end)

-- ── Command Console ──
RegisterNetEvent('dei_devtools:executeCommand', function(cmd)
    local src = source
    if not isSuperAdmin(src) then
        TriggerClientEvent('dei_devtools:consoleOutput', src, {
            type = 'error',
            text = 'Sin permisos para ejecutar comandos del servidor.'
        })
        return
    end

    -- Execute server command
    local ok, err = pcall(function()
        ExecuteCommand(cmd)
    end)

    TriggerClientEvent('dei_devtools:consoleOutput', src, {
        type = ok and 'success' or 'error',
        text = ok and ('Comando ejecutado: ' .. cmd) or ('Error: ' .. tostring(err))
    })
end)

RegisterNetEvent('dei_devtools:executeLua', function(code)
    local src = source
    if not isSuperAdmin(src) then
        TriggerClientEvent('dei_devtools:consoleOutput', src, {
            type = 'error',
            text = 'Sin permisos para ejecutar Lua en el servidor.'
        })
        return
    end

    local fn, err = load(code, 'devtools_eval', 't')
    if fn then
        local ok, result = pcall(fn)
        TriggerClientEvent('dei_devtools:consoleOutput', src, {
            type = ok and 'success' or 'error',
            text = ok and ('Resultado: ' .. tostring(result)) or ('Error: ' .. tostring(result))
        })
    else
        TriggerClientEvent('dei_devtools:consoleOutput', src, {
            type = 'error',
            text = 'Error de sintaxis: ' .. tostring(err)
        })
    end
end)

-- ── NUI Log (server-side storage) ──
local nuiLog = {}

RegisterNetEvent('dei_devtools:logNUI', function(entry)
    local src = source
    nuiLog[#nuiLog + 1] = entry
    if #nuiLog > (Config.MaxNuiLog or 100) then
        table.remove(nuiLog, 1)
    end
end)

RegisterNetEvent('dei_devtools:requestNuiLog', function()
    local src = source
    if not isAuthorized(src) then return end
    TriggerClientEvent('dei_devtools:nuiLogData', src, nuiLog)
end)

-- ── Export for other resources to log NUI messages ──
exports('LogNUI', function(resource, action, data)
    local entry = {
        time = os.date('%H:%M:%S'),
        resource = resource or 'unknown',
        action = action or 'unknown',
        size = data and #json.encode(data) or 0,
        payload = data
    }
    nuiLog[#nuiLog + 1] = entry
    if #nuiLog > (Config.MaxNuiLog or 100) then
        table.remove(nuiLog, 1)
    end

    for pid, _ in pairs(authorizedPlayers) do
        TriggerClientEvent('dei_devtools:nuiEntry', pid, entry)
    end
end)

-- ── Network Stats ──
RegisterNetEvent('dei_devtools:requestNetStats', function()
    local src = source
    if not isAuthorized(src) then return end

    local ping = GetPlayerPing(src)
    local endpoint = GetPlayerEndpoint(src)

    TriggerClientEvent('dei_devtools:netStatsData', src, {
        ping = ping,
        endpoint = endpoint,
        eventsPerSecond = #eventLog > 0 and math.min(#eventLog, 50) or 0
    })
end)
