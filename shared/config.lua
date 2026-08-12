local util = require("/shared.util")

local M = {}

local function positive(value, name)
  if not util.safeNumber(value) or value <= 0 then return false, name .. " must be a positive number" end
  return true
end

function M.controller(config)
  if type(config) ~= "table" then return false, "controller config must return a table" end
  local ok, err = positive(config.cellWidth, "cellWidth"); if not ok then return ok, err end
  ok, err = positive(config.cellLength, "cellLength"); if not ok then return ok, err end
  ok, err = positive(config.heartbeatTimeout, "heartbeatTimeout"); if not ok then return ok, err end
  ok, err = positive(config.jobReleaseTimeout, "jobReleaseTimeout"); if not ok then return ok, err end
  if config.jobReleaseTimeout < config.heartbeatTimeout then return false, "jobReleaseTimeout must be at least heartbeatTimeout" end
  if type(config.dock) ~= "table" or not util.safeNumber(config.dock.originX) or not util.safeNumber(config.dock.originY or 0) or not util.safeNumber(config.dock.originZ) then
    return false, "dock.originX, dock.originY, and dock.originZ must be numbers"
  end
  ok, err = positive(config.dock.spacing, "dock.spacing"); if not ok then return ok, err end
  if not ({ north=true, east=true, south=true, west=true })[config.dock.facing] then return false, "dock.facing must be north, east, south, or west" end
  return true
end

function M.miner(config)
  if type(config) ~= "table" then return false, "miner config must return a table" end
  local ok, err = positive(config.heartbeatInterval, "heartbeatInterval"); if not ok then return ok, err end
  ok, err = positive(config.inventoryFullSlotThreshold, "inventoryFullSlotThreshold"); if not ok then return ok, err end
  if config.inventoryFullSlotThreshold > 16 then return false, "inventoryFullSlotThreshold cannot exceed 16" end
  ok, err = positive(config.fuelSafetyMultiplier, "fuelSafetyMultiplier"); if not ok then return ok, err end
  ok, err = positive(config.requestInterval, "requestInterval"); if not ok then return ok, err end
  ok, err = positive(config.registerInterval, "registerInterval"); if not ok then return ok, err end
  ok, err = positive(config.controllerLostTimeout, "controllerLostTimeout"); if not ok then return ok, err end
  if type(config.storage) ~= "table" then return false, "storage config must be a table" end
  local validSides = { front=true, back=true, left=true, right=true, up=true, down=true }
  if not validSides[config.storage.unloadSide] or not validSides[config.storage.fuelSide] then return false, "storage sides must be front, back, left, right, up, or down" end
  if config.storage.unloadMode ~= "drop" then return false, "only storage.unloadMode=drop is implemented in v1" end
  if config.storage.refuelMode ~= "suck" and config.storage.refuelMode ~= "none" then return false, "storage.refuelMode must be suck or none" end
  return true
end

return M
