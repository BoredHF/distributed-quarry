local M = {}

function M.copy(t)
  if type(t) ~= "table" then return t end
  local r = {}; for k,v in pairs(t) do r[k] = M.copy(v) end; return r
end
function M.now() return os.epoch and os.epoch("utc") or os.clock() * 1000 end
function M.id(prefix) return prefix .. "-" .. tostring(os.getComputerID()) .. "-" .. tostring(M.now()) end
function M.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function M.count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
function M.tableContains(t, value) for _,v in pairs(t or {}) do if v == value then return true end end return false end
function M.log(path, message)
  local dir = fs.getDir(path); if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  if fs.exists(path) and fs.getSize(path) > 32768 then fs.delete(path) end
  local h = fs.open(path, "a"); if h then h.writeLine((textutils.formatTime(os.time(), true) or "?") .. " " .. tostring(message)); h.close() end
end
function M.safeNumber(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
function M.requireFields(msg, fields)
  if type(msg) ~= "table" or type(msg.type) ~= "string" then return false end
  for k,kind in pairs(fields or {}) do if type(msg[k]) ~= kind then return false end end
  return true
end
return M
