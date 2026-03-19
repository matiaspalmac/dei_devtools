Framework = {}
Framework.name = nil
Framework.obj = nil

CreateThread(function()
    -- Auto-detect framework
    if Config.Framework == 'esx' then
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and esx then
            Framework.name = 'esx'
            Framework.obj = esx
        end
    elseif Config.Framework == 'qbcore' then
        local ok, qb = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and qb then
            Framework.name = 'qbcore'
            Framework.obj = qb
        end
    end

    if not Framework.name then
        -- Try auto-detect
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and esx then
            Framework.name = 'esx'
            Framework.obj = esx
            return
        end

        local ok2, qb = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok2 and qb then
            Framework.name = 'qbcore'
            Framework.obj = qb
            return
        end

        Framework.name = 'standalone'
    end
end)

function Framework.IsAdmin(source)
    if Config.RequireAce then
        if IsPlayerAceAllowed(source, 'dei.devtools') then
            return true, 'ace'
        end
    end

    if Framework.name == 'esx' and Framework.obj then
        local xPlayer = Framework.obj.GetPlayerFromId(source)
        if xPlayer then
            local group = xPlayer.getGroup()
            for _, g in ipairs(Config.AllowedGroups) do
                if group == g then return true, 'group' end
            end
        end
    elseif Framework.name == 'qbcore' and Framework.obj then
        local player = Framework.obj.Functions.GetPlayer(source)
        if player then
            local perm = Framework.obj.Functions.HasPermission(source, 'admin')
            if perm then return true, 'group' end
            for _, g in ipairs(Config.AllowedGroups) do
                if Framework.obj.Functions.HasPermission(source, g) then
                    return true, 'group'
                end
            end
        end
    end

    -- Standalone: ACE only
    if IsPlayerAceAllowed(source, 'dei.devtools') then
        return true, 'ace'
    end

    return false, nil
end

function Framework.IsSuperAdmin(source)
    if IsPlayerAceAllowed(source, 'dei.devtools.console') then
        return true
    end
    if Framework.name == 'esx' and Framework.obj then
        local xPlayer = Framework.obj.GetPlayerFromId(source)
        if xPlayer then
            local group = xPlayer.getGroup()
            return group == 'superadmin' or group == 'god' or group == 'dev'
        end
    elseif Framework.name == 'qbcore' and Framework.obj then
        return Framework.obj.Functions.HasPermission(source, 'god') or
               Framework.obj.Functions.HasPermission(source, 'dev')
    end
    return false
end

function Framework.GetPlayerJob(source)
    if Framework.name == 'esx' and Framework.obj then
        local xPlayer = Framework.obj.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.getJob().name, xPlayer.getJob().grade_name
        end
    elseif Framework.name == 'qbcore' and Framework.obj then
        local player = Framework.obj.Functions.GetPlayer(source)
        if player then
            return player.PlayerData.job.name, player.PlayerData.job.grade.name
        end
    end
    return 'none', '0'
end

function Framework.GetPlayerIdentifiers(source)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local prefix = id:match('^([^:]+):')
            ids[prefix or ('id' .. i)] = id
        end
    end
    ids.name = GetPlayerName(source)
    return ids
end
