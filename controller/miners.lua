local util=require("shared.util")
local M={}
local function dockFor(dockId,cfg)
  if cfg.dock.docks and cfg.dock.docks[dockId] then return util.copy(cfg.dock.docks[dockId]) end
  local d=cfg.dock; local n=(dockId-(d.startingIndex or 1))*d.spacing
  if d.facing=="south" or d.facing=="north" then return {x=d.originX+n,y=d.originY or 0,z=d.originZ,facing=d.facing}
  else return {x=d.originX,y=d.originY or 0,z=d.originZ+n,facing=d.facing} end
end
function M.register(miners, computerId, cfg)
  local m=miners[tostring(computerId)]
  if not m then
    local max=0; for _,v in pairs(miners) do max=math.max(max,v.number or 0) end
    local number=max+1; local dockId=(cfg.dock.startingIndex or 1)+number-1
    m={computerId=computerId,number=number,friendlyId=string.format("MINER-%02d",number),dockId=dockId,dock=dockFor(dockId,cfg)}; miners[tostring(computerId)]=m
  end
  m.lastSeen=util.now(); m.online="ONLINE"; return m
end
function M.status(m, msg) m.lastSeen=util.now(); m.online="ONLINE"; m.state=msg.state or m.state; m.position={x=msg.x,y=msg.y,z=msg.z,facing=msg.facing}; m.fuel=msg.fuel; m.jobId=msg.jobId end
function M.refresh(miners,cfg)
  local now=util.now(); for _,m in pairs(miners) do
    local age=(now-(m.lastSeen or 0))/1000; m.online=age>cfg.jobReleaseTimeout and "OFFLINE" or (age>cfg.heartbeatTimeout and "STALE" or "ONLINE")
  end
end
return M
