local version=require("shared.version")
local util=require("shared.util")
local M={ name=version.protocol }
function M.openModem()
  for _,side in ipairs(rs.getSides()) do
    if peripheral.getType(side)=="modem" then rednet.open(side); return true,side end
  end
  return false,"No modem found. Attach a wireless or ender modem."
end
function M.send(id,msg) msg.protocol=M.name; return rednet.send(id,msg,M.name) end
function M.broadcast(msg) msg.protocol=M.name; rednet.broadcast(msg,M.name) end
function M.valid(msg) return type(msg)=="table" and msg.protocol==M.name and type(msg.type)=="string" end
function M.message(kind, data) local m=data or {}; m.type=kind; m.protocol=M.name; m.messageId=m.messageId or util.id(kind); return m end
return M
