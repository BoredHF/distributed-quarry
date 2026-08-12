local M={}
local function call(side, op, nav)
  if side=="front" then return turtle[op]() end
  if side=="up" then return turtle[op.."Up"]() end
  if side=="down" then return turtle[op.."Down"]() end
  if side~="left" and side~="right" and side~="back" then return false,"storage side must be front, back, left, right, up, or down" end
  local turn = side=="left" and nav.turnLeft or nav.turnRight
  local restore = side=="left" and nav.turnRight or nav.turnLeft
  local turns = side=="back" and 2 or 1
  local turned, err
  for _=1,turns do turned, err = turn(); if not turned then return false, err or "unable to turn toward storage" end end
  local ok, result = turtle[op]()
  for _=1,turns do local restored, restoreErr = restore(); if not restored then return false, restoreErr or "unable to restore dock facing" end end
  return ok, result
end
function M.unload(cfg, nav)
  if cfg.storage.unloadMode ~= "drop" then return false, "only storage.unloadMode=drop is implemented in v1" end
  for i=1,16 do if not (cfg.protectedSlots and cfg.protectedSlots[i]) and turtle.getItemCount(i)>0 then turtle.select(i); local ok=call(cfg.storage.unloadSide,"drop",nav);if not ok then return false,"cannot unload slot "..i end end end;return true
end
function M.refuel(cfg, nav)
  if cfg.storage.refuelMode=="none" then return true end
  if cfg.storage.refuelMode~="suck" then return false, "only storage.refuelMode=suck or none is implemented in v1" end
  local side=cfg.storage.fuelSide; local sucked=call(side,"suck",nav)
  if sucked then for i=1,16 do if not (cfg.protectedSlots and cfg.protectedSlots[i]) then turtle.select(i); turtle.refuel() end end end
  return turtle.getFuelLevel()=="unlimited" or turtle.getFuelLevel()>0
end
return M
