function TableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function IsPedAbleToSell(ped)
  if IsPedFatallyInjured(ped) or IsPedInAnyVehicle(ped, true) or IsPedSprinting(ped) then
    return false
  end

  return true
end

function GetZone(coords)
  local zone = GetNameOfZone(coords.x, coords.y, coords.z)
  return zone:upper()
end
