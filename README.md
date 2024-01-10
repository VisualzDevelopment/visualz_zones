# Visualz Zones

Thanks for buying our zone script

## Installation

The installation process is streamlined through a drag-and-drop mechanism. Ensure to make necessary edits in the configuration file.

For notifying gang members, navigate to:

```bash
server/functions.lua
```
**LB-Phone**
Are you using lb-phone, and want your gang to be alerted via that, add this in the file
```lua
function AlertGang(xPlayer, zone, zoneName)
    local xPlayers = ESX.GetExtendedPlayers('job', zone.owner)
    for _, tPlayer in pairs(xPlayers) do
        if tPlayer.source then
            local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(tPlayer.source)
            if phoneNumber then
                local message = 'Der er en der sælger stoffer i ' .. zoneName .. '!'
                local coords = xPlayer.getCoords(true)
                exports["lb-phone"]:SendMessage(Config.PhoneContactName, phoneNumber, message)
                exports["lb-phone"]:SendCoords(Config.PhoneContactName, phoneNumber, vector2(coords.x, coords.y))
            end
        end
    end
end

```

**GC-Phone or other phones**
Compatibility with GC-Phone or other phones
Currently, specific snippets for other phones are not available, but compatibility is supported.

## Usage
If you aren't using our sell script, you would need to use our export as listed below
```lua
  local xPlayer = ESX.GetPlayerFromId(source)
  local zone = -- Make your own way to get the zone the player is in.
  exports["visualz_zones"]:AddPoints(xPlayer, zone, price * amount, drug)
```