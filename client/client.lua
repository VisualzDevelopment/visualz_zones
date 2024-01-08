local currentAdminZone = nil

function ZoneMenu()
    local ownedZones = lib.callback.await('visualz_zones:GetOwnedZones')

    local options = {}

    if #ownedZones == 0 then
        table.insert(options, {
            title = "Ingen zoner",
            description = "Du ejer ingen zoner",
            readOnly = true,
        })
    else
        for _, v in pairs(ownedZones) do
            table.insert(options, {
                icon = "map-location-dot",
                title = Config.Zones[v.zone] .. " - " .. v.zone,
                description = "Zonen har opnået " .. v.points .. "/" .. Config.MaximumPoints .. " points",
                progress = v.points / Config.MaximumPoints * 100,
                colorScheme = "blue",
                onSelect = function()
                    OpenZone(v)
                end
            })
        end
    end

    table.sort(options, function(a, b)
        return a.title < b.title
    end)

    table.insert(options, {
        title = "",
        description = "   ‎   ‎   ‎   ‎   ‎   ‎  Visualz Development | Visualz.dk",
        readOnly = true,
    })

    lib.registerContext({
        id = 'zone_menu',
        title = 'Dine zoner',
        options = options
    })

    lib.showContext('zone_menu')
end

function AdminZone()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    local zones = lib.callback.await('visualz_zones:GetAdminZones')

    local options = {}
    for _, v in pairs(zones) do
        local owner = v.owner == nil and "Ingen" or v.owner
        table.insert(options, {
            icon = "map-location-dot",
            title = Config.Zones[v.zone] .. " - " .. v.zone,
            description = "Zonen har opnået " .. v.points .. "/" .. Config.MaximumPoints .. " points\n Ejer af zonen: " .. owner,
            progress = v.points / Config.MaximumPoints * 100,
            colorScheme = "blue",
            onSelect = function()
                currentAdminZone = v
                OpenZoneAdmin()
            end
        })
    end

    table.sort(options, function(a, b)
        return a.title < b.title
    end)

    table.insert(options, {
        title = "",
        description = "   ‎   ‎   ‎   ‎   ‎   ‎  Visualz Development | Visualz.dk",
        readOnly = true,
    })

    lib.registerContext({
        id = 'admin_zone_menu',
        title = 'Admin zoner',
        options = options
    })

    lib.showContext('admin_zone_menu')
end

function OpenZoneAdmin()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return AdminZone()
    end

    local owner = currentAdminZone.owner == nil and "Ingen" or currentAdminZone.owner
    local lockedIcon = currentAdminZone.locked == 1 and 'fa-solid fa-toggle-on' or 'fa-solid fa-toggle-off'
    local lockedDescription = currentAdminZone.locked == 1 and 'Klik for at åbne zonen' or 'Klik for at låse zonen'
    local lockedTitle = currentAdminZone.locked == 1 and 'Åben zone' or 'Lås zone'

    local options = {
        {
            icon = "map-location-dot",
            title = Config.Zones[currentAdminZone.zone] .. " - " .. currentAdminZone.zone,
            description = "Zonen har opnået " .. currentAdminZone.points .. "/" .. Config.MaximumPoints .. " points\n Ejer af zonen: " .. owner,
            progress = currentAdminZone.points / Config.MaximumPoints * 100,
            colorScheme = "blue",
            readOnly = true,
        },
        {
            icon = lockedIcon,
            title = lockedTitle,
            description = lockedDescription,
            onSelect = function()
                AdminToggleZone()
            end
        },
        {
            icon = "user-group",
            title = "Se alliancer",
            description = "Klik for at se/håndtere alliancer",
            onSelect = function()
                OpenAdminAlliances()
            end
        },
        {
            icon = "right-left",
            title = "Overfør zone",
            description = "Klik for at overfører zonen til en anden bande",
            onSelect = function()
                AdminTransferZone()
            end
        },
        {
            icon = "circle",
            title = "Angiv zone point",
            description = "Klik for at sætte zone point",
            onSelect = function()
                AdminSetPoint()
            end
        },
        {
            icon = "exclamation",
            title = "Reset zone",
            description = "Klik for at reset zonen",
            onSelect = function()
                AdminResetZone()
            end
        },
    }

    table.insert(options, {
        title = "",
        description = "   ‎   ‎   ‎   ‎   ‎   ‎  Visualz Development | Visualz.dk",
        readOnly = true,
    })

    lib.registerContext({
        id = 'admin_specific_zone_menu',
        title = 'Zone oversigt',
        menu = 'admin_zone_menu',
        options = options
    })

    lib.showContext('admin_specific_zone_menu')
end

function OpenAdminAlliances()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return AdminZone()
    end

    local options = {}

    local alliances = lib.callback.await('visualz_zones:GetAlliances', false, currentAdminZone.zone)

    if alliances ~= nil then
        for k, v in pairs(alliances) do
            table.insert(options, {
                title = v,
                description = "Klik for at fjerne alliance",
                onSelect = function()
                    AdminRemoveAlliance(k, v)
                end
            })
        end
        if TableLength(alliances) == 0 then
            table.insert(options, {
                title = "Ingen alliancer",
                description = "Der er ingen alliancer i denne zone",
                readOnly = true,
            })
        end
        if #alliances < Config.MaxAlliances then
            table.insert(options, {
                title = "Tilføj alliance",
                onSelect = function()
                    AdminAddAlliance()
                end
            })
        end
    end

    lib.registerContext({
        id = 'alliance_menu',
        title = 'Alliance Menu',
        menu = 'admin_specific_zone_menu',
        options = options
    })

    lib.showContext('alliance_menu')
end

function AdminAddAlliance()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return OpenZoneAdmin()
    end

    local input = lib.inputDialog('Opret alliance', {
        { type = 'input',    label = 'Zone',                                      description = "Aliancen er i",    icon = 'map',       default = Config.Zones[currentAdminZone.zone], disabled = true },
        { type = 'input',    label = 'Bande',                                     description = 'Navnet på banden', icon = 'signature', disabled = false },
        { type = 'checkbox', label = 'Bekræft at du ønsker at oprette alliancen', required = true },
    })

    if not input then
        return OpenAdminAlliances()
    end

    if input[2] == "" then
        return lib.notify({
            type = 'error',
            description = 'Du skal indtaste et navn'
        })
    end

    if input[3] then
        local response = lib.callback.await('visualz_zones:AdminAddAlliance', false, currentAdminZone.zone, input[2])

        if response.type == 'success' then
            currentAdminZone.alliance[input[2]] = input[2]
        end

        lib.notify({
            type = response.type,
            description = response.description
        })
    end

    OpenAdminAlliances()
end

function AdminRemoveAlliance(gang, label)
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return OpenZoneAdmin()
    end

    local alert = lib.alertDialog({
        header = 'Fjern Alliance',
        content = 'Er du sikker på du vil fjerne denne alliance?\n\nBande: ' .. label .. '\n\nZone: ' .. Config.Zones[currentAdminZone.zone] .. '\n\nZone Forkortelse: ' .. currentAdminZone.zone,
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        local response = lib.callback.await('visualz_zones:AdminRemoveAlliance', false, currentAdminZone.zone, gang)

        if response.type == 'success' then
            currentAdminZone.alliance[gang] = nil
        end

        lib.notify({
            type = response.type,
            description = response.description
        })
    end

    OpenAdminAlliances()
end

function AdminTransferZone()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return AdminZone()
    end

    local input = lib.inputDialog('Overfør zone', {
        { type = 'input',    label = 'Zone',                                   description = "Zonen der skal overføres", icon = 'map',       default = Config.Zones[currentAdminZone.zone], disabled = true },
        { type = 'input',    label = 'Bande',                                  description = 'Navnet på banden',         icon = 'signature', disabled = false },
        { type = 'checkbox', label = 'Bekræft at du ønsker at overføre zonen', required = true },
    })

    if not input then
        return AdminZone()
    end

    if input[2] == "" then
        return lib.notify({
            type = 'error',
            description = 'Du skal indtaste et navn'
        })
    end

    if input[3] then
        local response = lib.callback.await('visualz_zones:AdminTransferZone', false, currentAdminZone.zone, input[2])

        if response.type == 'success' then
            currentAdminZone.owner = input[2]
        end

        lib.notify({
            type = response.type,
            description = response.description
        })
    end

    OpenZoneAdmin()
end

function AdminResetZone()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return AdminZone()
    end

    local alert = lib.alertDialog({
        header = 'Reset Zone',
        content = 'Er du sikker på du vil resete denne zone?\n\nZone: ' .. Config.Zones[currentAdminZone.zone] .. '\n\nZone Forkortelse: ' .. currentAdminZone.zone,
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        local response = lib.callback.await('visualz_zones:AdminResetZone', false, currentAdminZone.zone)

        if response.type == 'success' then
            currentAdminZone.points = 0
            currentAdminZone.owner = nil
            currentAdminZone.alliance = {}
        end

        lib.notify({
            type = response.type,
            description = response.description
        })
    end

    OpenZoneAdmin()
end

function AdminSetPoint()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return AdminZone()
    end

    local input = lib.inputDialog('Sæt point', {
        { type = 'input',    label = 'Zone',                                description = "Zonen der skal sættes point på", icon = 'map',       default = Config.Zones[currentAdminZone.zone], disabled = true },
        { type = 'input',    label = 'Nuværende point',                     description = 'Nuværende point',                icon = 'signature', default = currentAdminZone.points,             disabled = true },
        { type = 'number',   label = 'Point',                               description = 'Antal point',                    icon = 'signature', disabled = false },
        { type = 'checkbox', label = 'Bekræft at du ønsker at sætte point', required = true },
    })

    if not input then
        return AdminZone()
    end

    if input[3] == "" then
        return lib.notify({
            type = 'error',
            description = 'Du skal indtaste et antal point'
        })
    end

    if input[4] then
        local response = lib.callback.await('visualz_zones:AdminSetPoint', false, currentAdminZone.zone, input[3])

        if response.type == 'success' then
            currentAdminZone.points = tonumber(input[3])
        end

        lib.notify({
            type = response.type,
            description = response.description
        })
    end

    OpenZoneAdmin()
end

function AdminToggleZone()
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end

    if not currentAdminZone then
        return AdminZone()
    end

    if currentAdminZone.locked == nil then
        currentAdminZone.locked = 0
    end

    local alert = lib.alertDialog({
        header = 'Toggle Zone',
        content = 'Er du sikker på du vil ' .. (currentAdminZone.locked == 1 and 'låse' or 'åbne') .. ' denne zone?\n\nZone: ' .. Config.Zones[currentAdminZone.zone] .. '\n\nZone Forkortelse: ' .. currentAdminZone.zone,
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        local response = lib.callback.await('visualz_zones:AdminToggleZone', false, currentAdminZone.zone, currentAdminZone.locked)

        if response.type == 'success' then
            currentAdminZone.locked = currentAdminZone.locked == 1 and 0 or 1
        end

        lib.notify({
            type = response.type,
            description = response.description
        })
    end

    OpenZoneAdmin()
end

RegisterCommand(Config.AdminCommand, function(source, args, raw)
    local isAdmin = lib.callback.await('visualz_zones:isAdmin')
    if not isAdmin then
        return lib.notify({
            type = 'error',
            description = 'Du har ikke adgang til denne kommando'
        })
    end
    AdminZone()
end)

RegisterCommand(Config.ZoneCommand, function(source, args, raw)
    if not IsAllowedGang() then
        return lib.notify({
            type = 'error',
            description = 'Du er ikke i en tilladt bande'
        })
    end
    ZoneMenu()
end)

function OpenZone(zone)
    local options = {
        {
            icon = "map-location-dot",
            title = Config.Zones[zone.zone] .. " - " .. zone.zone,
            description = "Zonen har opnået " .. zone.points .. "/" .. Config.MaximumPoints .. " points",
            progress = zone.points / Config.MaximumPoints * 100,
            colorScheme = "blue",
            readOnly = true,
        },
        {
            icon = "user-group",
            title = "Se alliancer",
            description = "Klik for at se/håndtere alliancer",
            onSelect = function()
                OpenAlliances(zone)
            end
        },
    }

    if zone.owner == ESX.PlayerData.job.name and ESX.PlayerData.job.grade_name == "boss" then
        table.insert(options, {
            icon = "right-left",
            title = "Overfør zone",
            description = "Klik for at overfører zonen til en anden bande",
            onSelect = function()
                TransferZoneNearby(zone)
            end
        })
    end

    lib.registerContext({
        id = 'specific_zone_menu',
        title = 'Zone oversigt',
        menu = 'zone_menu',
        options = options
    })

    lib.showContext('specific_zone_menu')
end

function OpenAlliances(zone)
    local options = {}
    local alliances = lib.callback.await('visualz_zones:GetAlliances', false, zone.zone)
    if alliances ~= nil then
        local description = ESX.PlayerData.job.grade_name ~= "boss" and "" or "Klik for at fjerne alliance"
        for k, v in pairs(alliances) do
            table.insert(options, {
                title = v,
                description = description,
                readOnly = ESX.PlayerData.job.grade_name ~= "boss" and true or false,
                onSelect = function()
                    RemoveAlliance(zone, k, v)
                end
            })
        end
        if TableLength(alliances) == 0 then
            table.insert(options, {
                title = "Ingen alliancer",
                description = "Der er ingen alliancer i denne zone",
                readOnly = true,
            })
        end
        if zone.owner == ESX.PlayerData.job.name and ESX.PlayerData.job.grade_name == "boss" then
            if #alliances < Config.MaxAlliances then
                table.insert(options, {
                    title = "Tilføj alliance",
                    onSelect = function()
                        AddAllianceNearbyPlayers(zone)
                    end
                })
            end
        end
    end

    lib.registerContext({
        id = 'alliance_menu',
        title = 'Alliance Menu',
        menu = 'specific_zone_menu',
        options = options
    })
    lib.showContext('alliance_menu')
end

function TransferZoneNearby(zone)
    local players = ESX.Game.GetPlayersInArea(GetEntityCoords(cache.ped), 3.0)

    local playersId = {}
    for _, v in ipairs(players) do
        table.insert(playersId, GetPlayerServerId(v))
    end

    local options = {}
    if #playersId == 0 then
        table.insert(options, {
            title = "Ingen spillere i nærheden",
            icon = "user",
            readOnly = true,
        })
    else
        table.insert(options, {
            title = "Spillere i nærheden:",
            readOnly = true,
        })
        for _, v in ipairs(playersId) do
            print(v)
            table.insert(options, {
                title = tostring(v),
                icon = "user",
                onSelect = function()
                    TransferZone(zone, v)
                end,
            })
        end
    end
    lib.registerContext({
        id = 'transfer_zone_menu',
        title = 'Overfør Zone',
        menu = 'specific_zone_menu',
        options = options
    })
    lib.showContext('transfer_zone_menu')
end

function TransferZone(zone, id)
    local sendRequestToPlayer = lib.alertDialog({
        header = "Overførsel af zone",
        content = 'Du er ved at overføre zone: ' ..
            zone.zone .. ' - ' .. Config.Zones[zone.zone] .. '\n\nEr du sikker på du vil overføre denne zone?',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Forsæt',
            cancel = 'Annuller'
        }
    })

    if sendRequestToPlayer == 'confirm' then
        local requestResponse = lib.callback.await("visualz_zones:requestTransferFromPlayer", false, zone.zone, id)
        lib.notify(requestResponse)
    end

    if sendRequestToPlayer == 'cancel' then
        return TransferZoneNearby(zone)
    end
end

function AddAllianceNearbyPlayers(zone)
    local players = ESX.Game.GetPlayersInArea(GetEntityCoords(cache.ped), 3.0)

    local playersId = {}
    for _, v in ipairs(players) do
        table.insert(playersId, GetPlayerServerId(v))
    end
    local options = {}
    if #playersId == 0 then
        table.insert(options, {
            title = "Ingen spillere i nærheden",
            icon = "user",
            readOnly = true,
        })
    else
        table.insert(options, {
            title = "Spillere i nærheden:",
            readOnly = true,
        })
        for _, v in ipairs(playersId) do
            table.insert(options, {
                title = tostring(v),
                icon = "user",
                onSelect = function()
                    AddAlliance(zone, v)
                end,
            })
        end
    end
    lib.registerContext({
        id = 'add_alliance_menu',
        title = 'Tilføj Alliance',
        menu = 'alliance_menu',
        options = options
    })
    lib.showContext('add_alliance_menu')
end

function AddAlliance(zone, id)
    local sendRequestToPlayer = lib.alertDialog({
        header = "Oprettelse af alliance i zone - " .. zone.zone .. " - " .. Config.Zones[zone.zone],
        content = 'Du er ved at oprette en alliance i zone: ' ..
            zone.zone .. ' - ' .. Config.Zones[zone.zone] .. '\n\nEr du sikker på du vil oprette denne alliance?',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Forsæt',
            cancel = 'Annuller'
        }
    })

    if sendRequestToPlayer == "cancel" then
        return AddAllianceNearbyPlayers(zone)
    elseif sendRequestToPlayer == "confirm" then
        local requestResponse = lib.callback.await("visualz_zones:requestAllianceFromPlayer", false, zone, id)
        lib.notify(requestResponse)
    end
end

function RemoveAlliance(zone, gang, label)
    if not IsAllowedGang() then
        return lib.notify({
            type = 'error',
            description = 'Du er ikke i en tilladt bande'
        })
    end
    local alert = lib.alertDialog({
        header = 'Fjern Alliance',
        content = 'Er du sikker på du vil fjerne denne alliance?\n\nBande: ' ..
            label .. '\n\nZone: ' .. Config.Zones[zone.zone] .. '\n\nZone Forkortelse: ' .. zone.zone,
        centered = true,
        cancel = true
    })
    if alert == 'confirm' then
        local response = lib.callback.await('visualz_zones:RemoveAlliance', false, zone.zone, gang)
        lib.notify({
            type = response.type,
            description = response.description
        })
    end
    OpenAlliances(zone)
end

lib.callback.register("visualz_zones:requestTransferFromOtherPlayer", function(name, zone)
    local dialog = lib.alertDialog({
        header = "Overførsel af zone - " .. zone .. " - " .. Config.Zones[zone],
        content = 'Du har modtaget en overførsels anmodning fra ' .. name .. ' i zonen: ' .. zone .. ' - ' .. Config.Zones[zone] .. '\n\nEr du sikker på du vil overføre denne zone?',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Modtag Zone',
            cancel = 'Annuller'
        }
    })

    if dialog == "confirm" then
        return true
    end

    return false
end)

lib.callback.register("visualz_zones:transferResponse", function(transferGang, transferZone)
    local input = lib.inputDialog('Overfør zone', {
        { type = 'input',    label = 'Zone',                          description = "Zonen der skal overføres", icon = 'map',       default = Config.Zones[transferZone], disabled = true },
        { type = 'input',    label = 'Bande',                         description = 'Navnet på banden',         icon = 'signature', default = transferGang,               disabled = true },
        { type = 'checkbox', label = 'Accepter overførsel af zonen?', description = "Godkender du overførslen", required = true },
    })

    if not input then
        return false
    end

    return input[3]
end)

lib.callback.register("visualz_zones:requestAllianceFromOtherPlayer", function(name, gang, zone)
    local dialog = lib.alertDialog({
        header = "Oprettelse af alliance",
        content = 'Du har modtaget en alliance anmodning fra ' ..
            name .. '(' .. gang .. ')\n\nEr du sikker på du vil oprette denne alliance?',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Opret Alliance',
            cancel = 'Annuller'
        }
    })

    if dialog == "confirm" then
        return true
    end

    return false
end)

lib.callback.register("visualz_zones:allianceResponse", function(allianceId, allianceGang, allianceZone)
    local input = lib.inputDialog('Opret alliance', {
        { type = 'input',    label = 'Zone',                                 description = "Aliancen er i",             icon = 'map',       default = Config.Zones[allianceZone], disabled = true },
        { type = 'input',    label = 'Bande',                                description = 'Navnet på banden',          icon = 'signature', default = allianceGang,               disabled = true },
        { type = 'checkbox', label = 'Accepter oprettelse du af alliancen?', description = "Godkender du virksomheden", required = true },
    })
    print(json.encode(input))
    if not input then
        return false
    end

    return input[3]
end)

lib.callback.register("visualz_zones:getZone", function(coords)
    local zone = GetZone(coords)
    return zone
end)


function IsAllowedGang()
    for _, v in ipairs(Config.AllowedGangs) do
        if v == ESX.PlayerData.job.name then
            return true
        end
    end
    return false
end

function IsAllowedGroup()
    for _, v in ipairs(Config.AllowedGroups) do
        print(json.encode(ESX.PlayerData))
        if v == ESX.PlayerData.group then
            return true
        end
    end
    return false
end
