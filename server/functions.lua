function AlertGang(xPlayer, zone, zoneName)
    local xPlayers = ESX.GetExtendedPlayers('job', zone.owner)
    for _, tPlayer in pairs(xPlayers) do
        if tPlayer then
            local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(tPlayer.source)
            if phoneNumber then
                local message = 'Der er nogle der sælger stoffer i ' .. zoneName .. ' - ' .. Config.Zones[zone] .. '!'
                local coords = xPlayer.getCoords(true)
                exports["lb-phone"]:SendMessage(Config.PhoneContactName, phoneNumber, message)
                exports["lb-phone"]:SendCoords(Config.PhoneContactName, phoneNumber, vector2(coords.x, coords.y))
            end
        end
    end
end
