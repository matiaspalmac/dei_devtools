-- ═══════════════════════════════════════════════
-- dei_devtools | Client NUI Callbacks & Data
-- ═══════════════════════════════════════════════

local isOpen = false
local isPaused = false
local activeTab = 'resmon'
local nuiLog = {}
local eventCounter = { incoming = 0, outgoing = 0, history = {} }
local lastEventCountTime = GetGameTimer()

-- ── NUI Callbacks ──

RegisterNUICallback('close', function(_, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('tabChange', function(data, cb)
    activeTab = data.tab
    cb('ok')
end)

RegisterNUICallback('requestResmon', function(_, cb)
    TriggerServerEvent('dei_devtools:requestResmon')
    cb('ok')
end)

RegisterNUICallback('requestEventLog', function(_, cb)
    TriggerServerEvent('dei_devtools:requestEventLog')
    cb('ok')
end)

RegisterNUICallback('clearEventLog', function(_, cb)
    TriggerServerEvent('dei_devtools:clearEventLog')
    cb('ok')
end)

RegisterNUICallback('togglePause', function(_, cb)
    isPaused = not isPaused
    cb({ paused = isPaused })
end)

RegisterNUICallback('watchEvent', function(data, cb)
    if data.eventName then
        TriggerServerEvent('dei_devtools:watchEvent', data.eventName)
    end
    cb('ok')
end)

RegisterNUICallback('requestPlayerData', function(_, cb)
    TriggerServerEvent('dei_devtools:requestPlayerData')
    cb('ok')
end)

RegisterNUICallback('requestEntities', function(_, cb)
    collectEntityData()
    cb('ok')
end)

RegisterNUICallback('inspectEntity', function(data, cb)
    inspectEntityById(data.netId, data.entityType)
    cb('ok')
end)

RegisterNUICallback('raycastInspect', function(_, cb)
    performRaycast()
    cb('ok')
end)

RegisterNUICallback('requestNetStats', function(_, cb)
    TriggerServerEvent('dei_devtools:requestNetStats')
    cb('ok')
end)

RegisterNUICallback('requestNuiLog', function(_, cb)
    TriggerServerEvent('dei_devtools:requestNuiLog')
    cb('ok')
end)

RegisterNUICallback('executeCommand', function(data, cb)
    if data.scope == 'client' then
        local ok, err = pcall(function()
            ExecuteCommand(data.command)
        end)
        SendNUIMessage({
            action = 'consoleOutput',
            data = {
                type = ok and 'success' or 'error',
                text = ok and ('Comando ejecutado: ' .. data.command) or ('Error: ' .. tostring(err))
            }
        })
    else
        TriggerServerEvent('dei_devtools:executeCommand', data.command)
    end
    cb('ok')
end)

RegisterNUICallback('executeLua', function(data, cb)
    if data.scope == 'client' then
        local fn, err = load(data.code, 'devtools_eval', 't')
        if fn then
            local ok, result = pcall(fn)
            SendNUIMessage({
                action = 'consoleOutput',
                data = {
                    type = ok and 'success' or 'error',
                    text = ok and ('Resultado: ' .. tostring(result)) or ('Error: ' .. tostring(result))
                }
            })
        else
            SendNUIMessage({
                action = 'consoleOutput',
                data = {
                    type = 'error',
                    text = 'Error de sintaxis: ' .. tostring(err)
                }
            })
        end
    else
        TriggerServerEvent('dei_devtools:executeLua', data.code)
    end
    cb('ok')
end)

RegisterNUICallback('copyToClipboard', function(data, cb)
    -- NUI handles clipboard via JS
    cb('ok')
end)

-- ── Server Event Handlers ──

RegisterNetEvent('dei_devtools:resmonData', function(resources, avgTick)
    if not isOpen then return end
    SendNUIMessage({
        action = 'resmonData',
        resources = resources,
        avgTick = avgTick
    })
end)

RegisterNetEvent('dei_devtools:eventLogData', function(log)
    if not isOpen then return end
    SendNUIMessage({
        action = 'eventLogData',
        entries = log
    })
end)

RegisterNetEvent('dei_devtools:eventEntry', function(entry)
    if not isOpen or isPaused then return end
    eventCounter.incoming = eventCounter.incoming + 1
    SendNUIMessage({
        action = 'eventEntry',
        entry = entry
    })
end)

RegisterNetEvent('dei_devtools:playerServerData', function(data)
    if not isOpen then return end
    SendNUIMessage({
        action = 'playerServerData',
        data = data
    })
end)

RegisterNetEvent('dei_devtools:consoleOutput', function(data)
    SendNUIMessage({
        action = 'consoleOutput',
        data = data
    })
end)

RegisterNetEvent('dei_devtools:netStatsData', function(data)
    if not isOpen then return end
    SendNUIMessage({
        action = 'netStatsData',
        data = data
    })
end)

RegisterNetEvent('dei_devtools:nuiLogData', function(log)
    if not isOpen then return end
    SendNUIMessage({
        action = 'nuiLogData',
        entries = log
    })
end)

RegisterNetEvent('dei_devtools:nuiEntry', function(entry)
    if not isOpen then return end
    SendNUIMessage({
        action = 'nuiEntry',
        entry = entry
    })
end)

-- ── Entity Data Collector ──

function collectEntityData()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local range = Config.EntityRange or 50.0

    -- Count all entities
    local pedCount = 0
    local vehCount = 0
    local objCount = 0
    local pickupCount = 0

    local allPeds = GetGamePool('CPed')
    local allVehs = GetGamePool('CVehicle')
    local allObjs = GetGamePool('CObject')
    local allPickups = GetGamePool('CPickup')

    pedCount = #allPeds
    vehCount = #allVehs
    objCount = #allObjs
    pickupCount = #allPickups

    -- Nearby entities
    local nearby = {}

    for _, entity in ipairs(allPeds) do
        local ePos = GetEntityCoords(entity)
        local dist = #(pos - ePos)
        if dist <= range and entity ~= ped then
            nearby[#nearby + 1] = {
                type = 'ped',
                handle = entity,
                model = GetEntityModel(entity),
                netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or -1,
                distance = math.floor(dist * 10) / 10,
                owner = NetworkGetEntityIsNetworked(entity) and NetworkGetEntityOwner(entity) or -1,
                health = GetEntityHealth(entity),
                coords = { x = math.floor(ePos.x * 100) / 100, y = math.floor(ePos.y * 100) / 100, z = math.floor(ePos.z * 100) / 100 }
            }
        end
    end

    for _, entity in ipairs(allVehs) do
        local ePos = GetEntityCoords(entity)
        local dist = #(pos - ePos)
        if dist <= range then
            nearby[#nearby + 1] = {
                type = 'vehicle',
                handle = entity,
                model = GetEntityModel(entity),
                netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or -1,
                distance = math.floor(dist * 10) / 10,
                owner = NetworkGetEntityIsNetworked(entity) and NetworkGetEntityOwner(entity) or -1,
                health = GetEntityHealth(entity),
                coords = { x = math.floor(ePos.x * 100) / 100, y = math.floor(ePos.y * 100) / 100, z = math.floor(ePos.z * 100) / 100 }
            }
        end
    end

    for _, entity in ipairs(allObjs) do
        local ePos = GetEntityCoords(entity)
        local dist = #(pos - ePos)
        if dist <= range then
            nearby[#nearby + 1] = {
                type = 'object',
                handle = entity,
                model = GetEntityModel(entity),
                netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or -1,
                distance = math.floor(dist * 10) / 10,
                owner = NetworkGetEntityIsNetworked(entity) and NetworkGetEntityOwner(entity) or -1,
                health = GetEntityHealth(entity),
                coords = { x = math.floor(ePos.x * 100) / 100, y = math.floor(ePos.y * 100) / 100, z = math.floor(ePos.z * 100) / 100 }
            }
        end
    end

    -- Sort by distance
    table.sort(nearby, function(a, b) return a.distance < b.distance end)

    -- Limit to 50 nearest
    local limited = {}
    for i = 1, math.min(#nearby, 50) do
        limited[i] = nearby[i]
    end

    SendNUIMessage({
        action = 'entityData',
        counts = {
            peds = pedCount,
            vehicles = vehCount,
            objects = objCount,
            pickups = pickupCount,
            total = pedCount + vehCount + objCount + pickupCount
        },
        nearby = limited
    })
end

function inspectEntityById(netId, entityType)
    local entity = -1
    if netId and netId > 0 then
        local ok, ent = pcall(NetworkGetEntityFromNetworkId, netId)
        if ok and ent and DoesEntityExist(ent) then
            entity = ent
        end
    end

    if entity == -1 or not DoesEntityExist(entity) then
        SendNUIMessage({
            action = 'entityInspect',
            data = nil
        })
        return
    end

    local pos = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    local vel = GetEntityVelocity(entity)
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z) * 3.6
    local model = GetEntityModel(entity)
    local health = GetEntityHealth(entity)
    local maxHealth = GetEntityMaxHealth(entity)

    local info = {
        model = model,
        modelName = string.format('0x%X', model),
        health = health,
        maxHealth = maxHealth,
        coords = { x = math.floor(pos.x * 100) / 100, y = math.floor(pos.y * 100) / 100, z = math.floor(pos.z * 100) / 100 },
        heading = math.floor(heading * 100) / 100,
        velocity = { x = math.floor(vel.x * 100) / 100, y = math.floor(vel.y * 100) / 100, z = math.floor(vel.z * 100) / 100 },
        speed = math.floor(speed * 10) / 10,
        netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or -1,
        entityType = entityType or 'unknown'
    }

    -- Extra vehicle info
    if IsEntityAVehicle(entity) then
        info.plate = GetVehicleNumberPlateText(entity)
        info.engineHealth = math.floor(GetVehicleEngineHealth(entity))
        info.bodyHealth = math.floor(GetVehicleBodyHealth(entity))
        info.dirtLevel = math.floor(GetVehicleDirtLevel(entity) * 10) / 10
    end

    SendNUIMessage({
        action = 'entityInspect',
        data = info
    })
end

function performRaycast()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 100.0, 0.0)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()

    -- Calculate direction
    local radX = camRot.x * math.pi / 180.0
    local radZ = camRot.z * math.pi / 180.0
    local dir = vector3(
        -math.sin(radZ) * math.abs(math.cos(radX)),
        math.cos(radZ) * math.abs(math.cos(radX)),
        math.sin(radX)
    )

    local dest = camPos + dir * 100.0
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, ped, 0)
    local _, hit, hitCoords, _, entity = GetShapeTestResult(ray)

    if hit == 1 and DoesEntityExist(entity) then
        local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or -1
        local eType = 'object'
        if IsEntityAPed(entity) then eType = 'ped'
        elseif IsEntityAVehicle(entity) then eType = 'vehicle' end

        inspectEntityById(netId, eType)
    else
        SendNUIMessage({
            action = 'entityInspect',
            data = nil
        })
    end
end

-- ── Player Data Collector (Client-side) ──

function collectPlayerData()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local armor = GetPedArmour(ped)
    local vel = GetEntityVelocity(ped)
    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z) * 3.6

    local data = {
        coords = {
            x = math.floor(pos.x * 100) / 100,
            y = math.floor(pos.y * 100) / 100,
            z = math.floor(pos.z * 100) / 100
        },
        heading = math.floor(heading * 100) / 100,
        health = health,
        maxHealth = maxHealth,
        armor = armor,
        speed = math.floor(speed * 10) / 10,
        serverId = GetPlayerServerId(PlayerId()),
        clientId = PlayerId(),
        vehicle = nil
    }

    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        local vModel = GetEntityModel(veh)
        local vSpeed = GetEntitySpeed(veh) * 3.6
        data.vehicle = {
            model = string.format('0x%X', vModel),
            displayName = GetDisplayNameFromVehicleModel(vModel),
            plate = GetVehicleNumberPlateText(veh),
            speed = math.floor(vSpeed * 10) / 10,
            engineHealth = math.floor(GetVehicleEngineHealth(veh)),
            bodyHealth = math.floor(GetVehicleBodyHealth(veh)),
            rpm = math.floor(GetVehicleCurrentRpm(veh) * 100) / 100,
            gear = GetVehicleCurrentGear(veh),
            fuel = math.floor(GetVehicleFuelLevel(veh) * 10) / 10
        }
    end

    SendNUIMessage({
        action = 'playerData',
        data = data
    })
end

-- ── Network Event Counter ──
CreateThread(function()
    while true do
        Wait(1000)
        if isOpen then
            local entry = {
                time = GetGameTimer(),
                incoming = eventCounter.incoming,
                outgoing = eventCounter.outgoing
            }
            eventCounter.history[#eventCounter.history + 1] = entry
            if #eventCounter.history > 30 then
                table.remove(eventCounter.history, 1)
            end

            SendNUIMessage({
                action = 'networkHistory',
                history = eventCounter.history
            })

            eventCounter.incoming = 0
            eventCounter.outgoing = 0
        end
    end
end)

-- ── Auto-refresh loops ──
CreateThread(function()
    while true do
        Wait(500)
        if isOpen and activeTab == 'player' then
            collectPlayerData()
            TriggerServerEvent('dei_devtools:requestPlayerData')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if isOpen and activeTab == 'entities' then
            collectEntityData()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.RefreshRate or 2000)
        if isOpen and activeTab == 'resmon' then
            TriggerServerEvent('dei_devtools:requestResmon')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if isOpen and activeTab == 'network' then
            TriggerServerEvent('dei_devtools:requestNetStats')
        end
    end
end)

-- ── Export for NUI logging ──
exports('LogNUI', function(resource, action, data)
    local entry = {
        time = string.format('%02d:%02d:%02d', GetClockHours(), GetClockMinutes(), GetClockSeconds()),
        resource = resource or GetCurrentResourceName(),
        action = action or 'unknown',
        size = data and #json.encode(data) or 0,
        payload = data
    }

    SendNUIMessage({
        action = 'nuiEntry',
        entry = entry
    })

    TriggerServerEvent('dei_devtools:logNUI', entry)
end)

-- ── Expose isOpen state ──
function IsDevToolsOpen()
    return isOpen
end

function SetDevToolsOpen(state)
    isOpen = state
end

exports('IsOpen', IsDevToolsOpen)
