-- Change this before publishing. It must be the raw directory containing this repository.
local BASE_URL="https://raw.githubusercontent.com/BoredHF/distributed-quarry/main/"
local role=...
if role~="controller" and role~="miner" and role~="selector" then print("Usage: wget run https://raw.githubusercontent.com/BoredHF/distributed-quarry/main/install.lua controller|miner|selector");return end
local files={"shared/version.lua","shared/util.lua","shared/persistence.lua","shared/protocol.lua","shared/config.lua"}
if role=="controller" then files[#files+1]="controller/config.lua";files[#files+1]="controller/quarry.lua";files[#files+1]="controller/jobs.lua";files[#files+1]="controller/miners.lua";files[#files+1]="controller/scheduler.lua";files[#files+1]="controller/ui.lua";files[#files+1]="controller/main.lua";files[#files+1]="controller/startup.lua"
elseif role=="miner" then for _,f in ipairs({"config.lua","navigation.lua","fuel.lua","inventory.lua","dock.lua","mining.lua","state_machine.lua","main.lua","startup.lua"}) do files[#files+1]="miner/"..f end
else files[#files+1]="miner/navigation.lua";files[#files+1]="miner/state_machine.lua";files[#files+1]="selector/controls.lua";files[#files+1]="selector/main.lua" end
for _,path in ipairs(files) do if fs.exists(path) and (path:find("config.lua") or path=="startup.lua") then print("Keeping existing "..path) else local dir=fs.getDir(path);if dir~="" and not fs.exists(dir) then fs.makeDir(dir) end;print("Downloading "..path);local ok,why=pcall(shell.run,"wget","-f",BASE_URL..path,path);if not ok then error("download failed: "..tostring(why)) end end end
local startup=role.."/startup.lua"; if fs.exists("startup.lua") then print("Existing startup.lua retained; run "..startup.." or replace startup.lua manually.") else local h=fs.open("startup.lua","w");h.write('shell.run("'..startup..'")');h.close() end
print("Installed "..role..". Attach/open a modem, configure files, then reboot.")
