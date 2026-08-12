local util=require("/shared.util")
local M={}
function M.new() return {state="BOOTING",nav={x=0,y=0,z=0,facing="north"},dockInitialized=false,job=nil,jobProgress=0,checkpoint=nil,lastControllerSeen=0,completionPending=false} end
function M.transition(s,to) s.state=to; s.lastTransition=util.now() end
return M
