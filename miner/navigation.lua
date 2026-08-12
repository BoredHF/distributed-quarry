local persist=require("/shared.persistence")
local M={ state=nil, config=nil }
local dirs={north=0,east=1,south=2,west=3}; local names={"north","east","south","west"}
function M.init(state, config, saveFn) M.state=state; M.config=config; M.saveFn=saveFn end
local function save() if M.saveFn then M.saveFn() end end
local function moved(fn, dx,dy,dz)
  for _=1,M.config.movementRetries do if fn() then M.state.nav.x=M.state.nav.x+dx;M.state.nav.y=M.state.nav.y+dy;M.state.nav.z=M.state.nav.z+dz;save();return true end; sleep(.2) end
  return false,"movement blocked at ("..M.state.nav.x..","..M.state.nav.y..","..M.state.nav.z..")"
end
function M.turnLeft() if turtle.turnLeft() then local i=(dirs[M.state.nav.facing]+3)%4;M.state.nav.facing=names[i+1];save();return true end return false end
function M.turnRight() if turtle.turnRight() then local i=(dirs[M.state.nav.facing]+1)%4;M.state.nav.facing=names[i+1];save();return true end return false end
function M.face(dir) local target=dirs[dir]; if not target then return false,"bad direction" end; while M.state.nav.facing~=dir do local d=(target-dirs[M.state.nav.facing])%4; if d==3 then M.turnLeft() else M.turnRight() end end;return true end
function M.forward(dig)
  local f=M.state.nav.facing; local dx,dz=0,0;if f=="north" then dz=-1 elseif f=="south" then dz=1 elseif f=="east" then dx=1 else dx=-1 end
  return moved(function() if turtle.forward() then return true end; if dig and turtle.detect() then turtle.dig(); return turtle.forward() end; return false end,dx,0,dz)
end
function M.back() local f=M.state.nav.facing; local dx,dz=0,0;if f=="north" then dz=1 elseif f=="south" then dz=-1 elseif f=="east" then dx=-1 else dx=1 end;return moved(turtle.back,dx,0,dz) end
function M.up(dig) return moved(function() if turtle.up() then return true end;if dig and turtle.detectUp() then turtle.digUp();return turtle.up() end;return false end,0,1,0) end
function M.down(dig) return moved(function() if turtle.down() then return true end;if dig and turtle.detectDown() then turtle.digDown();return turtle.down() end;return false end,0,-1,0) end
function M.gotoLocal(x,y,z,dig)
  while M.state.nav.y<y do local ok,e=M.up(dig);if not ok then return false,e end end; while M.state.nav.y>y do local ok,e=M.down(dig);if not ok then return false,e end end
  local function axis(pos,target,plus,minus) while pos()~=target do local ok,e=M.face(pos()<target and plus or minus);if not ok then return false,e end;ok,e=M.forward(dig);if not ok then return false,e end end;return true end
  local ok,e=axis(function()return M.state.nav.x end,x,"east","west");if not ok then return false,e end;return axis(function()return M.state.nav.z end,z,"south","north")
end
return M
