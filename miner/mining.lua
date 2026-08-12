local nav=require("miner.navigation")
local M={}
function M.total(job) return (job.maxX-job.minX+1)*(job.maxZ-job.minZ+1)*(job.topY-job.bottomY+1) end
function M.target(job,index)
  local w=job.maxX-job.minX+1; local l=job.maxZ-job.minZ+1; local per=w*l; local layer=math.floor(index/per); local inLayer=index%per; local row=math.floor(inLayer/w); local col=inLayer%w
  local x=(row%2==0) and job.minX+col or job.maxX-col; return x,job.topY-layer,job.minZ+row,layer,row,col
end
function M.step(state, checkpoint)
  local job=state.job; local i=state.jobProgress or 0; local total=M.total(job)
  if i>=total then return true,"complete" end
  local x,y,z,layer,row,col=M.target(job,i)
  local ok,err=nav.gotoLocal(x,y,z,true); if not ok then return false,err end
  state.jobProgress=i+1; state.checkpoint={index=i+1,layer=layer,row=row,column=col}; checkpoint(); return true,"progress"
end
return M
