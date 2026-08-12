local jobsLib=require("controller.jobs")
local M={ input="", commandMode=false, notice="" }
local function writeAt(x,y,s) term.setCursorPos(x,y); term.write(s) end
local function fit(s,w) s=tostring(s or ""); return s:sub(1,w) end
function M.draw(quarry,jobs,miners)
  local w,h=term.getSize(); term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
  local s=jobsLib.summary(jobs); local title=" DISTRIBUTED QUARRY CONTROLLER "
  writeAt(1,1,fit(title..string.rep(" ",w),w)); writeAt(1,2,fit("Quarry: "..(quarry.id or "none").."  State: "..(quarry.state or "UNCONFIGURED"),w))
  if quarry.id then writeAt(1,3,fit(string.format("Size: %d x %d x %d",quarry.maxX-quarry.minX+1,quarry.maxZ-quarry.minZ+1,quarry.topY-quarry.bottomY+1),w)) end
  local barW=math.max(8,w-22); local filled=math.floor(barW*s.progress); writeAt(1,4,"Progress: ["..string.rep("#",filled)..string.rep("-",barW-filled).."] "..string.format("%5.1f%%",s.progress*100))
  writeAt(1,5,fit(string.format("Cells: %d  Done: %d  Active: %d  Free: %d",s.total,s.done,s.active,s.free),w)); writeAt(1,7,"MINER        STATE          JOB  LINK")
  local y=8; for _,m in pairs(miners) do if y>=h-2 then break end; writeAt(1,y,fit(string.format("%-12s %-14s %-4s %s",m.friendlyId or "?",m.state or "?",m.jobId or "-",m.online or "?"),w)); y=y+1 end
  writeAt(1,h-1,fit("[: command] s=start p=pause r=resume t=stop m=miners j=jobs",w)); writeAt(1,h,fit(M.commandMode and (":"..M.input) or M.notice,w))
end
function M.key(key)
  if M.commandMode then
    if key==keys.enter then local c=M.input; M.input=""; M.commandMode=false; return c end
    if key==keys.backspace then M.input=M.input:sub(1,-2) end; return nil
  end
  if key==keys.colon then M.commandMode=true; M.input=""; return nil end
  local map={[keys.s]="start",[keys.p]="pause",[keys.r]="resume",[keys.t]="stop",[keys.m]="list miners",[keys.j]="list jobs",[keys.q]="show quarry"}; return map[key]
end
function M.char(ch) if M.commandMode then M.input=M.input..ch end end
return M
