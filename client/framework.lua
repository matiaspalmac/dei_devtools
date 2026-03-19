-- ═══════════════════════════════════════════════
-- dei_devtools | Client Framework (Theme Sync)
-- ═══════════════════════════════════════════════

ClientFramework = {}
ClientFramework.theme = 'dark'
ClientFramework.lightMode = false

-- Load theme from KVP (Dei ecosystem shared)
CreateThread(function()
    local savedTheme = GetResourceKvpString('dei_theme')
    local savedLight = GetResourceKvpString('dei_lightMode')

    if savedTheme and savedTheme ~= '' then
        ClientFramework.theme = savedTheme
    else
        ClientFramework.theme = Config.DefaultTheme or 'dark'
    end

    if savedLight == 'true' then
        ClientFramework.lightMode = true
    end
end)

-- Listen for theme changes from other Dei resources
RegisterNetEvent('dei:themeChanged', function(theme, light)
    if theme then
        ClientFramework.theme = theme
        SetResourceKvp('dei_theme', theme)
    end
    if light ~= nil then
        ClientFramework.lightMode = light
        SetResourceKvp('dei_lightMode', light and 'true' or 'false')
    end

    -- Sync to NUI
    SendNUIMessage({
        action = 'setTheme',
        theme = ClientFramework.theme,
        lightMode = ClientFramework.lightMode
    })
end)

function ClientFramework.GetTheme()
    return ClientFramework.theme, ClientFramework.lightMode
end
