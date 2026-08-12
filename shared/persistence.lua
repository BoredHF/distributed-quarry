local M = {}
local function ensure(path) local d=fs.getDir(path); if d ~= "" and not fs.exists(d) then fs.makeDir(d) end end
function M.load(path, fallback)
  local source = path
  if not fs.exists(source) and fs.exists(path .. ".bak") then source = path .. ".bak" end
  if not fs.exists(source) then return fallback end
  local h=fs.open(source,"r"); if not h then return fallback end
  local raw=h.readAll(); h.close(); local ok,value=pcall(textutils.unserialize,raw)
  if ok and type(value)=="table" then return value end
  return fallback
end
function M.save(path, value)
  ensure(path); local tmp=path..".tmp"; local backup=path..".bak"; local h=fs.open(tmp,"w")
  if not h then return false,"cannot open "..tmp end
  h.write(textutils.serialize(value)); h.close()
  if fs.exists(backup) then fs.delete(backup) end
  if fs.exists(path) then
    local backedUp, backupErr = pcall(fs.move, path, backup)
    if not backedUp or not fs.exists(backup) then return false, backupErr or ("cannot back up "..path) end
  end
  local moved, err = pcall(fs.move, tmp, path)
  if not moved or not fs.exists(path) then
    if fs.exists(backup) and not fs.exists(path) then pcall(fs.move, backup, path) end
    return false, err or ("cannot replace "..path)
  end
  if fs.exists(backup) then fs.delete(backup) end
  return true
end
return M
