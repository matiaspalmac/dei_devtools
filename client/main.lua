-- ═══════════════════════════════════════════════
-- dei_devtools | Client Main
-- ═══════════════════════════════════════════════

local isAuthorized = false
local isSuperAdmin = false
local authChecked = false

-- ── Auth ──
RegisterNetEvent('dei_devtools:authResult', function(allowed, super)
    isAuthorized = allowed
    isSuperAdmin = super
    authChecked = true

    if allowed then
        SendNUIMessage({
            action = 'authResult',
            allowed = true,
            superAdmin = super
        })
    end
end)

-- ── Keybind ──
RegisterCommand('+dei_devtools', function()
    if not authChecked then
        TriggerServerEvent('dei_devtools:requestAuth')
        -- Wait for auth response
        CreateThread(function()
            local timeout = 50
            while not authChecked and timeout > 0 do
                Wait(100)
                timeout = timeout - 1
            end
            if isAuthorized then
                toggleDevTools()
            else
                -- Silently ignore if not authorized
            end
        end)
        return
    end

    if not isAuthorized then return end
    toggleDevTools()
end, false)

RegisterCommand('-dei_devtools', function() end, false)

RegisterKeyMapping('+dei_devtools', 'Dei DevTools - Toggle overlay', 'keyboard', Config.OpenKey or 'F9')

function toggleDevTools()
    local open = not IsDevToolsOpen()
    SetDevToolsOpen(open)

    if open then
        local theme, lightMode = ClientFramework.GetTheme()
        SendNUIMessage({
            action = 'toggle',
            show = true,
            theme = theme,
            lightMode = lightMode,
            superAdmin = isSuperAdmin,
            opacity = Config.DefaultOpacity or 85
        })
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)

        -- Initial data load
        TriggerServerEvent('dei_devtools:requestResmon')
        collectPlayerData()
        TriggerServerEvent('dei_devtools:requestPlayerData')
    else
        SendNUIMessage({
            action = 'toggle',
            show = false
        })
        SetNuiFocus(false, false)
    end
end

-- ── Auth check on resource start ──
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('dei_devtools:requestAuth')
end)

-- ── Raycast keybind (R key while devtools open) ──
RegisterCommand('+dei_raycast', function()
    if IsDevToolsOpen() and isAuthorized then
        performRaycast()
    end
end, false)

RegisterCommand('-dei_raycast', function() end, false)

RegisterKeyMapping('+dei_raycast', 'Dei DevTools - Raycast Inspect', 'keyboard', 'R')

-- ── Track outgoing events for network monitor ──
local origTriggerServerEvent = TriggerServerEvent

-- We can't override TriggerServerEvent directly in FiveM,
-- but we can track events we know about
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        -- DevTools started
    end
end)
