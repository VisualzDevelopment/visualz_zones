local Zones = {}
local requests = {}
local existingOwner = nil

CreateThread(function()
    while true do
        Wait(1000)

        for k, v in pairs(requests) do
            if v.timeout > 0 then
                requests[k].timeout = v.timeout - 1
            else
                requests[k] = nil

                local xPlayer = ESX.GetPlayerFromId(v.allianceownerSource)
                if xPlayer then
                    TriggerClientEvent("visualz_zones:allianceRequestDone", xPlayer.source, "timeout")
                    TriggerClientEvent("ox_lib:notify", k, {
                        description = 'Du svaret ikke i tide',
                        type = 'error',
                        icon = 'times'
                    })
                end
            end
        end
    end
end)

if Config.ReducePointsEnabled then
    CreateThread(function()
        while true do
            Wait(ESX.Math.Round(Config.ReducePointsCheck, 0) * 60 * 1000)

            for _, zone in pairs(Zones) do
                local zoneLastTimeSold = ESX.Math.Round(zone.last_time_sold / 1000, 0)
                local reducePointsTimerInSec = (Config.ReducePointsTimer * 60) * 60

                if zoneLastTimeSold + reducePointsTimerInSec <= os.time() then
                    if zone.points > 0 then
                        local owner = zone.owner or "Ingen ejer"
                        local discordMessage =
                            "**Zone:** " .. zone.zone .. " - " .. Config.Zones[zone.zone] .. "\n" ..
                            "**Points:** " .. zone.points .. "\n" ..
                            "**Ejer:** " .. owner .. "\n\n" ..

                            "**Sidst solgt i zonen:** " .. os.date("%d/%m/%Y %H:%M:%S", zoneLastTimeSold) .. "\n" ..
                            "**Fjernet points:** " .. Config.PointsRemoveAmount .. "\n" ..
                            "**Nye points:** " .. zone.points - Config.PointsRemoveAmount .. "\n"

                        SendLog(Logs["ReducePoints"], 2829617, "Points fjernet", discordMessage, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))
                        zone.points = zone.points - Config.PointsRemoveAmount
                        if zone.points > 0 then
                            MySQL.update.await('UPDATE visualz_zones SET points = ? WHERE zone = ?', {
                                zone.points, zone.zone
                            })
                        else
                            MySQL.update.await('UPDATE visualz_zones SET points = ?, owner = ?, alliance = ? WHERE zone = ?', {
                                zone.points, nil, "[]", zone.zone
                            })
                        end
                    else

                    end
                end
            end
        end
    end)
end

function IsAllowedGang(gang)
    for _, v in pairs(Config.AllowedGangs) do
        if v == gang then
            return true
        end
    end
    return false
end

function IsAllowedGroup(group)
    for _, v in pairs(Config.AllowedGroups) do
        if v == group then
            return true
        end
    end
    return false
end

-- Load zones when MySQL is ready
MySQL.ready(function()
    MySQL.query('SHOW TABLES LIKE \'visualz_zones\'', {}, function(tableExists)
        if not tableExists or #tableExists == 0 then
            local createTableResponse = MySQL.query.await(
                'CREATE TABLE IF NOT EXISTS `visualz_zones` (' ..
                '`zone` varchar(50) NOT NULL,' ..
                '`owner` varchar(46) DEFAULT NULL,' ..
                '`alliance` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT \'[]\',' ..
                '`points` int(11) NOT NULL,' ..
                '`locked` int(11) NOT NULL DEFAULT 0,' ..
                '`last_time_sold` timestamp NOT NULL DEFAULT current_timestamp()' ..
                ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci',
                {}
            );

            if createTableResponse then
                for k, v in pairs(Config.Zones) do
                    MySQL.insert('INSERT INTO visualz_zones (zone, owner, alliance, points) VALUES (@zone, @owner, @alliance, @points)', {
                        ['@zone'] = k,
                        ['@owner'] = nil,
                        ['@alliance'] = json.encode({}),
                        ['@points'] = 0
                    })
                    Zones[k] = {
                        zone = k,
                        owner = nil,
                        alliance = {},
                        points = 0
                    }
                end
            end
        else
            MySQL.query('SELECT * FROM visualz_zones', {}, function(response)
                if response then
                    for i = 1, #response do
                        Zones[response[i].zone] = response[i]
                        Zones[response[i].zone].alliance = json.decode(response[i].alliance)
                    end
                end
            end)
        end
    end)
end)

function TransferZone(xPlayer, zone, newOwner)
    local owner = xPlayer.job.name

    if not IsAllowedGang(newOwner) or not IsAllowedGang(owner) then
        return false
    end

    local row = MySQL.single.await('SELECT * FROM visualz_zones WHERE zone = ? LIMIT 1', { zone })

    if not row then
        return false
    end

    if row.owner == owner then
        MySQL.update.await('UPDATE visualz_zones SET owner = ?, alliance = ? WHERE zone = ?', {
            newOwner, "[]", zone
        })

        Zones[zone].owner = newOwner
        Zones[zone].alliance = {}
        return true
    end

    return false
end

function AddAlliance(xPlayer, zone, alliance)
    local gang = xPlayer.job.name
    local alliances = {}

    local row = MySQL.single.await('SELECT * FROM visualz_zones WHERE zone = ? LIMIT 1', { zone })
    if not row then return false end

    if not row.owner == gang then
        return
    end

    local existingAlliances = json.decode(row.alliance)

    if existingAlliances then
        for i = 1, #existingAlliances do
            table.insert(alliances, existingAlliances[i])
        end
    end

    if #alliances >= Config.MaxAlliances then
        TriggerClientEvent("ox_lib:notify", xPlayer.source, {
            description = 'Der er ikke flere alliance pladser',
            type = 'error',
        })
        return false
    end

    for _, v in pairs(alliances) do
        if v == alliance then
            TriggerClientEvent("ox_lib:notify", xPlayer.source, {
                description = 'I er allerede allieret',
                type = 'error',
            })
            return false
        end
    end

    table.insert(alliances, alliance)
    Zones[zone].alliance = alliances

    MySQL.Async.execute('UPDATE visualz_zones SET alliance = @alliance WHERE zone = @zone', {
        ['@alliance'] = json.encode(alliances),
        ['@zone'] = zone
    })
    return true
end

function AddPoints(xPlayer, zone, drugPrice, drugType)
    local clientZone = lib.callback.await("visualz_zones:getZone", xPlayer.source, xPlayer.getCoords(true))
    if clientZone ~= zone then
        return
    end

    local gang = xPlayer.job.name

    local zoneName = Config.Zones[zone]
    local alliance = false

    local popularDrugPrice = (drugPrice * Config.PopularDrugMultiplier) - drugPrice
    local OwnedZonePrice = (drugPrice * Config.OwnedZoneMultiplier) - drugPrice

    local hasGottenControlReward = false

    for k, v in pairs(Zones) do
        if k == zone then
            if not IsAllowedGang(gang) then
                break
            end
            if v.alliance ~= nil then
                local alliances = v.alliance
                if alliances ~= nil then
                    for _, v in pairs(alliances) do
                        if v == gang then
                            alliance = true
                        end
                    end
                end
            end
            if v.locked == 1 then
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    type = 'error',
                    description = 'Zonen er låst',
                })
                break
            end
            if (v.owner == gang and v.points == Config.MaximumPoints) or (alliance and v.points == Config.MaximumPoints) then
                xPlayer.addAccountMoney('black_money', math.floor(OwnedZonePrice))
                hasGottenControlReward = true
                if CheckControlReward(drugType, zone, xPlayer, popularDrugPrice) then
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'success',
                        description = math.floor(popularDrugPrice + OwnedZonePrice) ..
                            ' - DKK populæret stof & kontrollering i ' .. zoneName
                    })
                else
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'success',
                        description = math.floor(OwnedZonePrice) .. ' DKK - Kontrollering af ' .. zoneName
                    })
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'inform',
                        description = 'Du har opnået maksimum points i ' .. zoneName
                    })
                end
            elseif (v.owner == gang and v.points >= 0) or (alliance and v.points >= 0) then
                xPlayer.addAccountMoney('black_money', math.floor(OwnedZonePrice))
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    type = 'inform',
                    description = '+' .. Config.PointsAddAmount .. ' Points i ' .. zoneName
                })
                hasGottenControlReward = true
                if CheckControlReward(drugType, zone, xPlayer, popularDrugPrice) then
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'success',
                        description = math.floor(popularDrugPrice + OwnedZonePrice) .. ' - DKK populæret stof & kontrollering i ' .. zoneName
                    })
                else
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'success',
                        description = math.floor(OwnedZonePrice) .. ' DKK - Bonus for at eje ' .. zoneName
                    })
                end
                v.points = v.points + Config.PointsAddAmount
            elseif (v.owner ~= gang and not alliance and v.points >= 0) or (v.points < 0) then
                if v.points == 0 or v.points < 0 then
                    if v.owner == nil then
                        existingOwner = "Ingen ejer"
                    else
                        existingOwner = v.owner
                    end
                    v.points = 1
                    v.owner = gang
                    local didOwnerUpdate = MySQL.update.await('UPDATE visualz_zones SET owner = ?, points = ? WHERE zone = ?', {
                        gang, v.points, zone
                    })
                    if didOwnerUpdate then
                        local discordMessage =
                            "**Spillerens navn:** " .. xPlayer.getName() .. "\n" ..
                            "**Spillerens bande:** " .. xPlayer.job.label .. "\n\n" ..

                            "**Tidligere ejer:** " .. existingOwner .. "\n" ..
                            "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

                            "**Spillerens identifier:** " .. xPlayer.identifier .. "\n"

                        SendLog(Logs["TakeZone"], 2829617, "Zone overtaget", discordMessage, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

                        TriggerClientEvent("ox_lib:notify", xPlayer.source, {
                            type = 'success',
                            description = 'Du har overtaget ' .. zoneName
                        })
                    else
                        TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                            type = 'info',
                            description = 'Der skete en fejl ved overtagelsen af ' .. zoneName
                        })
                    end
                else
                    v.points = v.points - Config.PointsRemoveAmount
                    TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                        type = 'inform',
                        description = '-' .. Config.PointsRemoveAmount .. ' Points i ' .. zoneName
                    })

                    local chance = math.random(1, 100)

                    if chance <= Config.AlertGang then
                        AlertGang(xPlayer, v, zoneName)
                    end
                end
            end

            v.last_time_sold = os.time() * 1000
            MySQL.update.await('UPDATE visualz_zones SET points = ?, last_time_sold = ? WHERE zone = ?', {
                v.points, os.date("%Y-%m-%d %H:%M:%S"), zone
            })
        end
    end

    if not hasGottenControlReward then
        if CheckControlReward(drugType, zone, xPlayer, popularDrugPrice) then
            TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                type = 'success',
                description = math.floor(popularDrugPrice) .. ' - DKK populæret stof i ' .. zoneName
            })
        end
    end
end

function CheckControlReward(drugType, zone, xPlayer, popularDrugPrice)
    for k, v in pairs(Config.PopularZoneDrugs) do
        for i = 1, #v do
            if drugType == v[i] then
                if k == zone then
                    xPlayer.addAccountMoney('black_money', math.floor(popularDrugPrice))
                    return true
                end
            end
        end
    end
    return false
end

lib.callback.register('visualz_zones:isAdmin', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    if not IsAllowedGroup(xPlayer.group) then
        return false
    end

    return true
end)

lib.callback.register('visualz_zones:GetAdminZones', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at se zoner',
            type = 'error',
            position = 'top',
        }
    end

    CreateThread(function()
        local discordMessage =
            "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
            "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

            "**Admins identifier:** " .. xPlayer.identifier .. "\n"

        SendLog(Logs["OpenAdminZones"], 2829617, "Admin åbnede liste over zoner", discordMessage, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))
    end)

    return Zones
end)

lib.callback.register('visualz_zones:AdminAddAlliance', function(source, zone, gang)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at tilføje alliancer',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGang(gang) then
        return {
            id = 'admin_zoes',
            description = 'Bande findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    if not Zones[zone] then
        return {
            id = 'admin_zoes',
            description = 'Zonen findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    local alliances = Zones[zone].alliance
    if alliances then
        for k, v in pairs(alliances) do
            if v == gang then
                return {
                    id = 'admin_zoes',
                    description = 'De er allerede allieret',
                    type = 'error',
                    position = 'top',
                }
            end
        end
    end

    table.insert(alliances, gang)
    Zones[zone].alliance = alliances

    MySQL.Async.execute('UPDATE visualz_zones SET alliance = @alliance WHERE zone = @zone', {
        ['@alliance'] = json.encode(alliances),
        ['@zone'] = zone
    })

    local discordMessage =
        "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
        "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

        "**Zone ejer:** " .. (Zones[zone].owner or "Ingen ejer") .. "\n" ..
        "**Alliance:** " .. gang .. "\n" ..
        "**Alliancer efter tilføjelse:** " .. json.encode(alliances) .. "\n" ..
        "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

        "**Admins identifier:** " .. xPlayer.identifier .. "\n"

    SendLog(Logs["AdminCreateAlliance"], 2829617, "Admin oprettet en alliance", discordMessage, "Visualz Development | Visualz.dk | " ..
        os.date("%d/%m/%Y %H:%M:%S"))

    return {
        id = 'admin_zoes',
        description = 'Du har nu tilføjet ' .. gang .. ' til alliancen',
        type = 'success',
        position = 'top',
    }
end)

lib.callback.register("visualz_zones:AdminRemoveAlliance", function(source, zone, gang)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at fjerne alliancer',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGang(gang) then
        return {
            id = 'admin_zoes',
            description = 'Bande findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    if not Zones[zone] then
        return {
            id = 'admin_zoes',
            description = 'Zonen findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    local alliances = Zones[zone].alliance
    if alliances then
        for k, v in pairs(alliances) do
            if v == gang then
                table.remove(alliances, k)
                Zones[zone].alliance = alliances

                MySQL.Async.execute('UPDATE visualz_zones SET alliance = @alliance WHERE zone = @zone', {
                    ['@alliance'] = json.encode(alliances),
                    ['@zone'] = zone
                })

                local discordMessage =
                    "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
                    "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

                    "**Zone ejer:** " .. (Zones[zone].owner or "Ingen ejer") .. "\n" ..
                    "**Alliance:** " .. gang .. "\n" ..
                    "**Alliancer efter fjernelse:** " .. json.encode(alliances) .. "\n" ..
                    "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

                    "**Admins identifier:** " .. xPlayer.identifier .. "\n"

                SendLog(Logs["AdminRemoveAlliance"], 2829617, "Admin fjernede en alliance", discordMessage, "Visualz Development | Visualz.dk | " ..
                    os.date("%d/%m/%Y %H:%M:%S"))

                return {
                    id = 'admin_zoes',
                    description = 'Du har nu fjernet ' .. gang .. ' fra alliancen',
                    type = 'success',
                    position = 'top',
                }
            end
        end
    end

    return {
        id = 'admin_zoes',
        description = 'De er ikke allieret',
        type = 'error',
        position = 'top',
    }
end)

lib.callback.register('visualz_zones:AdminTransferZone', function(source, zone, gang)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at overføre zoner',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGang(gang) then
        return {
            id = 'admin_zoes',
            description = 'Bande findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    if not Zones[zone] then
        return {
            id = 'admin_zoes',
            description = 'Zonen findes ikke',
            type = 'error',
            position = 'top',
        }
    end
    local existingOwner = Zones[zone].owner or "Ingen ejer"

    local didTransfer = AdminTransferZone(xPlayer, zone, gang)
    if didTransfer then
        local discordMessage =
            "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
            "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

            "**Zone ejer:** " .. existingOwner .. "\n" ..
            "**Ny ejer:** " .. gang .. "\n" ..
            "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

            "**Admins identifier:** " .. xPlayer.identifier .. "\n"

        SendLog(Logs["AdminTransferZone"], 2829617, "Admin overførte en zone", discordMessage, "Visualz Development | Visualz.dk | " ..
            os.date("%d/%m/%Y %H:%M:%S"))
        return {
            id = 'admin_zoes',
            description = 'Du har nu overført zonen til ' .. gang,
            type = 'success',
            position = 'top',
        }
    end

    return {
        id = 'admin_zoes',
        description = 'Der skete en fejl',
        type = 'error',
        position = 'top',
    }
end)

lib.callback.register('visualz_zones:AdminResetZone', function(source, zone)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at nulstille zoner',
            type = 'error',
            position = 'top',
        }
    end

    if not Zones[zone] then
        return {
            id = 'admin_zoes',
            description = 'Zonen findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    local didReset = MySQL.update.await('UPDATE visualz_zones SET owner = ?, alliance = ?, points = ? WHERE zone = ?', {
        nil, "[]", 0, zone
    })

    if didReset then
        local discordMessage =
            "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
            "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

            "**Zone ejer:** " .. (Zones[zone].owner or "Ingen ejer") .. "\n" ..
            "**Alliancer:** " .. json.encode(Zones[zone].alliance) .. "\n" ..
            "**Points:** " .. Zones[zone].points .. "\n" ..
            "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

            "**Admins identifier:** " .. xPlayer.identifier .. "\n"

        SendLog(Logs["AdminResetZone"], 2829617, "Admin nulstillede en zone", discordMessage, "Visualz Development | Visualz.dk | " ..
            os.date("%d/%m/%Y %H:%M:%S"))
        Zones[zone].owner = nil
        Zones[zone].alliance = {}
        Zones[zone].points = 0
        return {
            id = 'admin_zoes',
            description = 'Du har nu nulstillet zonen',
            type = 'success',
            position = 'top',
        }
    end

    return {
        id = 'admin_zoes',
        description = 'Der skete en fejl',
        type = 'error',
        position = 'top',
    }
end)

lib.callback.register("visualz_zones:AdminSetPoint", function(source, zone, point)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at sætte points',
            type = 'error',
            position = 'top',
        }
    end

    if not Zones[zone] then
        return {
            id = 'admin_zoes',
            description = 'Zonen findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    if not tonumber(point) then
        return {
            id = 'admin_zoes',
            description = 'Du skal skrive et tal',
            type = 'error',
            position = 'top',
        }
    end

    local point = tonumber(point)

    if point > Config.MaximumPoints then
        return {
            id = 'admin_zoes',
            description = 'Du kan ikke sætte points højere end ' .. Config.MaximumPoints,
            type = 'error',
            position = 'top',
        }
    end

    if point < 0 then
        return {
            id = 'admin_zoes',
            description = 'Du kan ikke sætte points lavere end 0',
            type = 'error',
            position = 'top',
        }
    end

    local didReset = MySQL.update.await('UPDATE visualz_zones SET points = ? WHERE zone = ?', {
        point, zone
    })

    if didReset then
        local discordMessage =
            "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
            "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

            "**Zone ejer:** " .. (Zones[zone].owner or "Ingen ejer") .. "\n" ..
            "**Nuværende points:** " .. Zones[zone].points .. "\n" ..
            "**Point efter:** " .. point .. "\n" ..
            "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

            "**Admins identifier:** " .. xPlayer.identifier .. "\n"

        SendLog(Logs["AdminSetPoint"], 2829617, "Admin satte points", discordMessage, "Visualz Development | Visualz.dk | " ..
            os.date("%d/%m/%Y %H:%M:%S"))
        Zones[zone].points = point
        return {
            id = 'admin_zoes',
            description = 'Du har nu sat points til ' .. point,
            type = 'success',
            position = 'top',
        }
    end

    return {
        id = 'admin_zoes',
        description = 'Der skete en fejl',
        type = 'error',
        position = 'top',
    }
end)

lib.callback.register('visualz_zones:AdminToggleZone', function(source, zone, locked)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return {
            id = 'admin_zoes',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    if not IsAllowedGroup(xPlayer.group) then
        return {
            id = 'admin_zoes',
            description = 'Du har ikke rettigheder til at låse zoner',
            type = 'error',
            position = 'top',
        }
    end

    if not Zones[zone] then
        return {
            id = 'admin_zoes',
            description = 'Zonen findes ikke',
            type = 'error',
            position = 'top',
        }
    end

    if locked == 0 then
        locked = 1
    else
        locked = 0
    end

    local didLock = MySQL.update.await('UPDATE visualz_zones SET locked = ? WHERE zone = ?', {
        locked, zone
    })

    if didLock then
        local discordMessage =
            "**Admins navn:** " .. xPlayer.getName() .. "\n" ..
            "**Admins bande:** " .. xPlayer.job.label .. " - " .. xPlayer.job.name .. " \n\n" ..

            "**Zone ejer:** " .. (Zones[zone].owner or "Ingen ejer") .. "\n" ..
            "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

            "**Admins identifier:** " .. xPlayer.identifier .. "\n"

        SendLog(Logs["AdminToggleZone"], 2829617, "Admin " .. (locked == 0 and 'åbnet' or 'låste') .. " en zone", discordMessage, "Visualz Development | Visualz.dk | " ..
            os.date("%d/%m/%Y %H:%M:%S"))
        Zones[zone].locked = locked
        return {
            id = 'admin_zoes',
            description = 'Du har nu ' .. (locked == 0 and 'åbnet' or 'låst') .. ' zonen',
            type = 'success',
            position = 'top',
        }
    end

    return {
        id = 'admin_zoes',
        description = 'Der skete en fejl',
        type = 'error',
        position = 'top',
    }
end)

function AdminTransferZone(xPlayer, zone, newOwner)
    if not IsAllowedGang(newOwner) then
        return false
    end

    if not IsAllowedGroup(xPlayer.group) then
        return false
    end

    local row = MySQL.single.await('SELECT * FROM visualz_zones WHERE zone = ? LIMIT 1', { zone })

    if not row then
        return false
    end

    MySQL.update.await('UPDATE visualz_zones SET owner = ?, alliance = ? WHERE zone = ?', {
        newOwner, "[]", zone
    })

    Zones[zone].owner = newOwner
    Zones[zone].alliance = {}
    return true
end

-- Function to get zones owned by a player
lib.callback.register('visualz_zones:GetOwnedZones', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    local gang = xPlayer.job.name

    local zones = {}

    for _, v in pairs(Zones) do
        if v.owner == gang then
            table.insert(zones, v)
        end
    end

    return zones
end)

lib.callback.register("visualz_zones:requestTransferFromPlayer", function(source, zone, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            description = 'Der skete en fejl',
            type = 'error',
        }
    end

    local tPlayer = ESX.GetPlayerFromId(id)
    if not tPlayer then
        return {
            description = 'Spilleren er ikke online',
            type = 'error',
        }
    end

    if #(xPlayer.getCoords(true) - tPlayer.getCoords(true)) > 5.0 then
        return {
            description = 'Spilleren er for langt væk',
            type = 'error',
        }
    end

    if requests[tPlayer.source] then
        return {
            description = 'Der er allerede en forespørgsel på denne spiller',
            type = 'error',
        }
    end

    if xPlayer.source == tPlayer.source then
        return {
            description = 'Du kan ikke overføre til dig selv',
            type = 'error',
        }
    end

    if not IsAllowedGang(xPlayer.job.name) then
        return {
            description = 'Din bande kan ikke overføre zoner',
            type = 'error',
        }
    end


    if not IsAllowedGang(tPlayer.job.name) then
        return {
            description = 'Du kan ikke overføre til denne bande',
            type = 'error',
        }
    end

    if tPlayer.job.name == xPlayer.job.name then
        return {
            description = 'Du kan ikke overføre til din egen bande',
            type = 'error',
        }
    end

    if not Zones[zone] then
        return {
            description = 'Zonen findes ikke, burde ikke ske',
            type = 'error',
        }
    end

    if Zones[zone].owner ~= xPlayer.job.name then
        return {
            description = 'Du ejer ikke denne zone',
            type = 'error',
        }
    end

    if xPlayer.job.grade_name ~= "boss" then
        return {
            description = 'Du har ikke rettigheder til at overføre zoner',
            type = 'error',
        }
    end

    if tPlayer.job.grade_name ~= "boss" then
        return {
            description = 'Personen har ikke rettigheder til at modtage zoner',
            type = 'error',
        }
    end

    requests[tPlayer.source] = {
        transferownerSource = xPlayer.source,
        timeout = 60
    }

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'create_alliance_request',
        description = 'Du har sendt en forespørgsel til ' ..
            tPlayer.getName() .. ' om at overføre zone: ' .. zone .. ' - ' .. Config.Zones[zone] .. '',
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'create_alliance_request',
        description = 'Du er blevet forespurgt om at modtage zonen af ' ..
            xPlayer.getName() .. ' i zone: ' .. zone .. ' - ' .. Config.Zones[zone],
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    local requestResponse = lib.callback.await("visualz_zones:requestTransferFromOtherPlayer", tPlayer.source, xPlayer.getName(), zone)
    if not requestResponse then
        requests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'create_alliance_request',
            description = 'Du har afvist forespørgslen om at modtage zonen',
            type = 'error',
            position = 'top',
        })

        return {
            id = 'create_alliance_request',
            description = 'Det er blevet afvist at overføre zonen til ' .. tPlayer.job.label,
            type = 'error',
            position = 'top',
        }
    end

    if requests[tPlayer.source] == nil then
        return {
            id = 'create_alliance_request',
            description = 'Forespørgslen er udløbet',
            type = 'success',
            position = 'top',
        }
    end

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'create_alliance_request',
        description = 'Venter på svar fra dig',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })
    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'create_alliance_request',
        description = 'Venter på svar fra modparten',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })

    local transferResponse = lib.callback.await("visualz_zones:transferResponse", xPlayer.source, tPlayer.job.label, zone)
    if not transferResponse then
        requests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'create_alliance_request',
            description = 'Det er blevet afvist at modtage zonen fra ' .. xPlayer.job.label,
            type = 'error',
            position = 'top',
        })
        return {
            id = 'create_alliance_request',
            description = 'Du har afvist at overføre zonen',
            type = 'error',
            position = 'top',
        }
    end

    if requests[tPlayer.source] == nil then
        return {
            id = 'create_alliance_request',
            description = 'Forespørgslen er udløbet',
            type = 'success',
            position = 'top',
        }
    end

    local transfer = TransferZone(xPlayer, zone, tPlayer.job.name)
    if not transfer then
        requests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'create_alliance_request',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'create_alliance_request',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    local discordMessage =
        "**Spillerens navn:** " .. xPlayer.getName() .. "\n" ..
        "**Modtagerens navn:** " .. tPlayer.getName() .. "\n\n" ..

        "**Spillerens bande:** " .. xPlayer.job.label .. "\n" ..
        "**Modtagerens bande:** " .. tPlayer.job.label .. "\n\n" ..

        "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

        "**Spilleren identifier:** " .. xPlayer.identifier .. "\n" ..
        "**Modtagerens identifier:** " .. tPlayer.identifier .. "\n"

    SendLog(Logs["TransferZone"], 2829617, "Zone overført", discordMessage, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    requests[tPlayer.source] = nil
    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'create_alliance_request',
        description = 'Du har nu modtaget zonen fra ' .. xPlayer.job.label,
        type = 'success',
        position = 'top',
    })
    return {
        id = 'create_alliance_request',
        description = 'Du har nu overført zonen til ' .. tPlayer.job.label,
        type = 'success',
        position = 'top',
    }
end)

lib.callback.register("visualz_zones:requestAllianceFromPlayer", function(source, zone, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return {
            description = 'Der skete en fejl',
            type = 'error',
        }
    end

    local tPlayer = ESX.GetPlayerFromId(id)
    if not tPlayer then
        return {
            description = 'Spilleren er ikke online',
            type = 'error',
        }
    end

    if #(xPlayer.getCoords(true) - tPlayer.getCoords(true)) > 5.0 then
        return {
            description = 'Spilleren er for langt væk',
            type = 'error',
        }
    end

    if requests[tPlayer.source] then
        return {
            description = 'Der er allerede en forespørgsel på denne spiller',
            type = 'error',
        }
    end

    if xPlayer.source == tPlayer.source then
        return {
            description = 'Du kan ikke alliere dig med dig selv',
            type = 'error',
        }
    end

    if not IsAllowedGang(xPlayer.job.name) then
        return {
            description = 'Du kan ikke alliere dig med denne bande',
            type = 'error',
        }
    end

    if not IsAllowedGang(tPlayer.job.name) then
        return {
            description = 'Du kan ikke alliere dig med denne bande',
            type = 'error',
        }
    end

    if tPlayer.job.name == xPlayer.job.name then
        return {
            description = 'Du kan ikke alliere dig med dit eget gang',
            type = 'error',
        }
    end

    if not Zones[zone.zone] then
        return {
            description = 'Zonen findes ikke',
            type = 'error',
        }
    end

    if Zones[zone.zone].owner ~= xPlayer.job.name then
        return {
            description = 'Du ejer ikke zonen',
            type = 'error',
        }
    end

    if xPlayer.job.grade_name ~= "boss" then
        return {
            description = 'Du har ikke rettigheder til at alliere dig med andre',
            type = 'error',
        }
    end

    if tPlayer.job.grade_name ~= "boss" then
        return {
            description = 'Han har ikke rettigheder til at alliere sig med andre',
            type = 'error',
        }
    end

    if Zones[zone.zone].alliance then
        local alliances = Zones[zone.zone].alliance
        for k, v in pairs(alliances) do
            if v == tPlayer.job.name then
                return {
                    description = 'I er allerede allieret',
                    type = 'error',
                }
            end
        end
    end

    requests[tPlayer.source] = {
        allianceownerSource = xPlayer.source,
        timeout = 60
    }

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'create_alliance_request',
        description = 'Forespørgsel sendt til ' .. tPlayer.getName() .. ' om at oprette en alliance',
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'create_alliance_request',
        description = 'Du er blevet forespurgt om at oprette en alliance af ' .. xPlayer.getName(),
        icon = 'spinner',
        iconAnimation = "spin",
        duration = 60000,
        position = 'top',
    })

    local requestResponse = lib.callback.await("visualz_zones:requestAllianceFromOtherPlayer", tPlayer.source, xPlayer.getName(), xPlayer.job.label, zone.zone)
    if not requestResponse then
        requests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'create_alliance_request',
            description = 'Du har afvist forespørgslen om at oprette en alliance',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'create_alliance_request',
            description = 'Personen har afvist forespørgslen om at oprette en alliance',
            type = 'error',
            position = 'top',
        }
    end

    if requests[tPlayer.source] == nil then
        return {
            id = 'create_alliance_request',
            description = 'Forespørgslen er udløbet',
            type = 'success',
            position = 'top',
        }
    end

    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'create_alliance_request',
        description = 'Venter på svar fra dig',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })
    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'create_alliance_request',
        description = 'Venter på svar fra modparten',
        icon = 'spinner',
        iconAnimation = "spin",
        position = 'top',
        duration = 60000,
    })


    local response = lib.callback.await("visualz_zones:allianceResponse", xPlayer.source, tPlayer.getName(), tPlayer.job.label, zone.zone)
    if not response then
        requests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'create_alliance_request',
            description = 'Det er blevet afvist at alliere sig med ' .. xPlayer.job.label,
            type = 'error',
            position = 'top',
        })
        return {
            id = 'create_alliance_request',
            description = 'Du har afvist at alliere dig med ' .. tPlayer.job.label,
            type = 'error',
            position = 'top',
        }
    end

    if requests[tPlayer.source] == nil then
        return {
            id = 'create_alliance_request',
            description = 'Forespørgslen er udløbet',
            type = 'success',
            position = 'top',
        }
    end

    local alliance = AddAlliance(xPlayer, zone.zone, tPlayer.job.name)
    if not alliance then
        requests[tPlayer.source] = nil
        TriggerClientEvent("ox_lib:notify", tPlayer.source, {
            id = 'create_alliance_request',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        })
        return {
            id = 'create_alliance_request',
            description = 'Der skete en fejl',
            type = 'error',
            position = 'top',
        }
    end

    requests[tPlayer.source] = nil
    TriggerClientEvent("ox_lib:notify", xPlayer.source, {
        id = 'create_alliance_request',
        description = 'Du er nu allieret med ' .. tPlayer.job.label,
        type = 'success',
        position = 'top',
    })

    local discordMessage =
        "**Spillerens navn:** " .. xPlayer.getName() .. "\n" ..
        "**Modparten navn:** " .. tPlayer.getName() .. "\n\n" ..

        "**Spillerens bande:** " .. xPlayer.job.label .. "\n" ..
        "**Modpartens bande:** " .. tPlayer.job.label .. "\n\n" ..

        "**Zone:** " .. zone.zone .. " - " .. Config.Zones[zone.zone] .. "\n\n" ..

        "**Spilleren identifier:** " .. xPlayer.identifier .. "\n" ..
        "**Modpartens identifier:** " .. tPlayer.identifier .. "\n"

    SendLog(Logs["CreateAlliance"], 2829617, "Alliance oprettet", discordMessage, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    TriggerClientEvent("ox_lib:notify", tPlayer.source, {
        id = 'create_alliance_request',
        description = 'Du er nu allieret med ' .. xPlayer.job.label,
        type = 'success',
        position = 'top',
    })
end)

-- Function to remove an alliance through a callback
lib.callback.register('visualz_zones:RemoveAlliance', function(source, zone, alliance)
    local xPlayer = ESX.GetPlayerFromId(source)
    local gang = xPlayer.job.name
    local alliances = {}
    local row = MySQL.single.await('SELECT * FROM visualz_zones WHERE zone = ? LIMIT 1', { zone })

    if not row then
        return { type = "error", description = "Der skete en fejl." }
    end
    if row.owner ~= gang then
        return { type = "error", description = "Du ejer ikke zonen." }
    end
    if xPlayer.job.grade_name ~= "boss" then
        return { type = "error", description = "Du har ikke rettigheder til at fjerne alliancer." }
    end


    local existingAlliances = json.decode(row.alliance)

    if existingAlliances then
        for i = 1, #existingAlliances do
            table.insert(alliances, existingAlliances[i])
        end
    end

    for k, v in pairs(alliances) do
        if v == alliance then
            table.remove(alliances, k)
        end
    end

    Zones[zone].alliance = alliances

    MySQL.Async.execute('UPDATE visualz_zones SET alliance = @alliance WHERE zone = @zone', {
        ['@alliance'] = json.encode(alliances),
        ['@zone'] = zone
    })

    local discordMessage =
        "**Spillerens navn:** " .. xPlayer.getName() .. "\n\n" ..

        "**Spillerens bande:** " .. xPlayer.job.label .. "\n" ..
        "**Modpartens bande:** " .. alliance .. "\n\n" ..

        "**Zone:** " .. zone .. " - " .. Config.Zones[zone] .. "\n\n" ..

        "**Spillerens identifier:** " .. xPlayer.identifier .. "\n"

    SendLog(Logs["RemoveAlliance"], 2829617, "Alliance slettet", discordMessage, "Visualz Development | Visualz.dk | " .. os.date("%d/%m/%Y %H:%M:%S"))

    return { type = "success", description = "Alliancen er nu slettet" }
end)

-- Function to get player data through a callback
lib.callback.register('visualz_zones:GetPlayerData', function(source, target)
    local xPlayer = ESX.GetPlayerFromId(target)
    return xPlayer
end)

-- Function to get alliances of a zone through a callback
lib.callback.register('visualz_zones:GetAlliances', function(source, zone)
    local alliances = {}
    local LabelAliances = {}
    local row = MySQL.single.await('SELECT * FROM visualz_zones WHERE zone = ? LIMIT 1', { zone })

    if not row then
        return
    end

    if row.alliance ~= nil then
        alliances = json.decode(row.alliance)
    end

    for _, z in pairs(alliances) do
        local jobs = ESX.GetJobs()
        for k, v in pairs(jobs) do
            if v.name == z then
                LabelAliances[z] = v.label
                break
            end
        end
    end

    return LabelAliances
end)

function SendLog(WebHook, color, title, message, footer)
    local embedMsg = {
        {
            ["color"] = color,
            ["title"] = title,
            ["description"] = "" .. message .. "",
            ["footer"] = {
                ["text"] = footer,
            },
        }
    }
    PerformHttpRequest(WebHook, function(err, text, headers) end, 'POST',
        json.encode({
            username = Config.whName,
            avatar_url = Config.whLogo,
            embeds = embedMsg
        }),
        { ['Content-Type'] = 'application/json' })
end

exports("AddPoints", AddPoints)
