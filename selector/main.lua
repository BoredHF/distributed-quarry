local protocol=require("/shared.protocol");local persist=require("/shared.persistence");local sm=require("/miner.state_machine");local nav=require("/miner.navigation");local controls=require("/selector.controls")
local state=persist.load("selector/state.db",sm.new());local function save() persist.save("selector/state.db",state) end
local ok,err=protocol.openModem();if not ok then error(err) end;nav.init(state,{movementRetries=10},save)
local first,second=nil,nil
print("Quarry selector: place turtle at quarry origin/top corner.")
print("W/S move, A/D turn, R/F vertical, M mark, Enter confirm, Q cancel.")
while true do
 term.setCursorPos(1,4);term.clearLine();write(string.format("Position x=%d y=%d z=%d facing=%s",state.nav.x,state.nav.y,state.nav.z,state.nav.facing))
 local e,k=os.pullEvent("key")
 if k==keys.q then print("Cancelled.");return elseif k==keys.m then if not first then first={x=state.nav.x,y=state.nav.y,z=state.nav.z};print("First corner marked. Drive to opposite horizontal corner and press M.") elseif not second then second={x=state.nav.x,y=state.nav.y,z=state.nav.z};print("Second corner marked. Enter bottom Y (example -63):");local bottom=tonumber(read());if not bottom then print("Invalid depth.") else print("Press Enter to send, Q to cancel.");local _,confirm=os.pullEvent("key");if confirm==keys.enter then local q={minX=math.min(first.x,second.x),maxX=math.max(first.x,second.x),minZ=math.min(first.z,second.z),maxZ=math.max(first.z,second.z),topY=first.y,bottomY=bottom};protocol.broadcast(protocol.message("QUARRY_DEFINE",{quarry=q}));print("Definition sent. Check controller.");return end end end
 else local good,why=controls.handle(k);if not good then print("Move failed: "..tostring(why)) end end
end
