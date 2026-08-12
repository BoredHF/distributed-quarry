local M={}
local function distance(m,j)
  local p=m.position or m.dock or {x=0,z=0}; return math.abs((p.x or 0)-j.minX)+math.abs((p.z or 0)-j.minZ)
end
function M.assign(jobs, miner)
  local chosen,best
  for _,j in pairs(jobs) do if j.state=="AVAILABLE" then local d=distance(miner,j); if not best or d<best then chosen,best=j,d end end end
  if chosen then chosen.state="ASSIGNED"; chosen.assignedComputerId=miner.computerId; chosen.assignmentId="assignment-"..chosen.id.."-"..os.epoch("utc"); chosen.assignedAt=os.epoch("utc") end
  return chosen
end
function M.releaseExpired(jobs, miners, cfg)
  local now=os.epoch("utc"); local changed=false
  for _,j in pairs(jobs) do if j.state=="ASSIGNED" or j.state=="MINING" then local m=miners[tostring(j.assignedComputerId)]
    if not m or m.online=="OFFLINE" then j.state="AVAILABLE"; j.assignedComputerId=nil; j.assignmentId=nil; changed=true end
  end end
  return changed
end
function M.completeIfDone(quarry,jobs)
  if quarry.state=="COMPLETE" then return false end
  for _,j in pairs(jobs) do if j.state~="DONE" then return false end end
  if next(jobs) then quarry.state="COMPLETE"; return true end; return false
end
return M
