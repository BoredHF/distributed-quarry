local M={}
function M.progress(j)
  local w=j.maxX-j.minX+1; local l=j.maxZ-j.minZ+1; local h=j.topY-j.bottomY+1
  return math.max(0,math.min(1,(j.progress or 0)/(w*l*h)))
end
function M.summary(jobs)
  local s={total=0,done=0,active=0,free=0,failed=0,progress=0}
  for _,j in pairs(jobs) do s.total=s.total+1; s.progress=s.progress+M.progress(j)
    if j.state=="DONE" then s.done=s.done+1 elseif j.state=="AVAILABLE" then s.free=s.free+1 elseif j.state=="FAILED" then s.failed=s.failed+1 else s.active=s.active+1 end
  end
  if s.total>0 then s.progress=s.progress/s.total end; return s
end
return M
