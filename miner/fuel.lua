local M={}
function M.level() return turtle.getFuelLevel() end
function M.unlimited() return M.level()=="unlimited" end
function M.estimateReturnCost(nav,dock,transitY)
  local p=nav.state.nav; return math.abs(p.y-transitY)+math.abs(p.x-dock.x)+math.abs(p.z-dock.z)+math.abs(transitY-(dock.y or 0))
end
function M.canContinue(nav,dock,transitY,multiplier)
  if M.unlimited() then return true end; local n=M.level(); return type(n)=="number" and n>=math.ceil(M.estimateReturnCost(nav,dock,transitY)*multiplier+8)
end
return M
