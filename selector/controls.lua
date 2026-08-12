local nav=require("/miner.navigation")
local M={}
function M.handle(key)
 if key==keys.w then return nav.forward(true) elseif key==keys.s then return nav.back() elseif key==keys.a then return nav.turnLeft() elseif key==keys.d then return nav.turnRight() elseif key==keys.r then return nav.up(true) elseif key==keys.f then return nav.down(true) end
 return true
end
return M
