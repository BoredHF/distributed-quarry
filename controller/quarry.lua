local util=require("shared.util")
local M={}
function M.validate(q)
  if type(q)~="table" then return false,"quarry definition is not a table" end
  for _,k in ipairs({"minX","maxX","minZ","maxZ","topY","bottomY"}) do if not util.safeNumber(q[k]) then return false,"missing/invalid "..k end end
  if q.minX>q.maxX or q.minZ>q.maxZ or q.bottomY>q.topY then return false,"invalid quarry bounds" end
  return true
end
function M.define(def, config, existingId)
  local ok,err=M.validate(def); if not ok then return nil,err end
  local q=util.copy(def); q.id=q.id or existingId or ("Q"..tostring(util.now())); q.state="READY"; q.createdAt=util.now()
  q.cellWidth=config.cellWidth; q.cellLength=config.cellLength; return q
end
function M.cells(q)
  local r,id={},1
  for z=q.minZ,q.maxZ,q.cellLength do for x=q.minX,q.maxX,q.cellWidth do
    r[id]={id=id,minX=x,maxX=math.min(q.maxX,x+q.cellWidth-1),minZ=z,maxZ=math.min(q.maxZ,z+q.cellLength-1),topY=q.topY,bottomY=q.bottomY,state="AVAILABLE",progress=0,assignedComputerId=nil}
    id=id+1
  end end
  return r
end
function M.volume(q) return (q.maxX-q.minX+1)*(q.maxZ-q.minZ+1)*(q.topY-q.bottomY+1) end
return M
