local protocol = require("shared.protocol")
local persist = require("shared.persistence")
local util = require("shared.util")
local configCheck = require("shared.config")
local quarryLib = require("controller.quarry")
local minerLib = require("controller.miners")
local scheduler = require("controller.scheduler")
local ui = require("controller.ui")

local config = persist.load("controller/state/config.db", require("controller.config"))
local valid, configError = configCheck.controller(config)
if not valid then error("Invalid controller/config.lua: " .. configError) end

local quarry = persist.load("controller/state/quarry.db", { state = "UNCONFIGURED" })
local miners = persist.load("controller/state/miners.db", {})
local jobs = persist.load("controller/state/jobs.db", {})

local function log(message) util.log("logs/controller.log", message) end
local function save()
  local ok, err = persist.save("controller/state/quarry.db", quarry)
  if not ok then error("Cannot save quarry state: " .. tostring(err)) end
  ok, err = persist.save("controller/state/miners.db", miners)
  if not ok then error("Cannot save miner registry: " .. tostring(err)) end
  ok, err = persist.save("controller/state/jobs.db", jobs)
  if not ok then error("Cannot save jobs: " .. tostring(err)) end
  ok, err = persist.save("controller/state/config.db", config)
  if not ok then error("Cannot save controller config: " .. tostring(err)) end
end

local function send(miner, message) return protocol.send(miner.computerId, message) end
local function fromClaimedComputer(sender, message)
  return type(message.computerId) == "number" and sender == message.computerId
end

local function sendStatus(miner)
  send(miner, protocol.message("STATUS", { state = quarry.state, jobId = miner.jobId }))
end

local function assign(miner)
  local current = miner.jobId and jobs[miner.jobId]
  if current and current.assignedComputerId == miner.computerId and current.state ~= "DONE" and current.state ~= "FAILED" then
    send(miner, protocol.message("ASSIGN_JOB", { job = current, dock = miner.dock, assignmentId = current.assignmentId }))
    if quarry.state == "PAUSED" then send(miner, protocol.message("PAUSE", {})) end
    if quarry.state == "STOPPED" then send(miner, protocol.message("STOP", {})) end
    return
  end

  if quarry.state ~= "RUNNING" then
    sendStatus(miner)
    return
  end

  local job = scheduler.assign(jobs, miner)
  if not job then
    send(miner, protocol.message("QUARRY_STATUS", { state = quarry.state, noJobs = true }))
    return
  end

  miner.jobId = job.id
  miner.state = "ASSIGNED"
  save()
  log(miner.friendlyId .. " assigned job " .. job.id)
  send(miner, protocol.message("ASSIGN_JOB", { job = job, dock = miner.dock, assignmentId = job.assignmentId }))
end

local function releaseJob(job, reason)
  local owner = job.assignedComputerId and miners[tostring(job.assignedComputerId)]
  if owner then
    owner.jobId = nil
    send(owner, protocol.message("CANCEL_LOCAL_JOB", { jobId = job.id, reason = reason or "job released" }))
  end
  job.state = "AVAILABLE"
  job.assignedComputerId = nil
  job.assignmentId = nil
  job.assignedAt = nil
end

local function onMessage(sender, message)
  if not protocol.valid(message) then return end

  if message.type == "REGISTER" and util.requireFields(message, { computerId = "number", role = "string" }) and message.role == "miner" then
    if not fromClaimedComputer(sender, message) then return end
    local miner = minerLib.register(miners, message.computerId, config)
    save()
    log("registered " .. miner.friendlyId)
    send(miner, protocol.message("REGISTER_ACK", {
      minerId = miner.friendlyId, dockId = miner.dockId, dock = miner.dock,
      quarryId = quarry.id, quarryState = quarry.state, controllerId = os.getComputerID()
    }))
    return
  end

  -- Selectors are deliberately not part of the miner registry.
  if message.type == "QUARRY_DEFINE" and type(message.quarry) == "table" then
    if quarry.state == "RUNNING" then
      protocol.send(sender, protocol.message("ERROR", { message = "cannot redefine a running quarry" }))
      return
    end
    local newQuarry, errorMessage = quarryLib.define(message.quarry, config, quarry.id)
    if not newQuarry then
      protocol.send(sender, protocol.message("ERROR", { message = errorMessage }))
      return
    end
    quarry = newQuarry
    jobs = quarryLib.cells(quarry)
    save()
    log("defined " .. quarry.id)
    protocol.send(sender, protocol.message("QUARRY_STATUS", { state = "READY", quarry = quarry }))
    return
  end

  if not fromClaimedComputer(sender, message) then return end
  local miner = miners[tostring(message.computerId)]
  if not miner then return end

  if message.type == "HEARTBEAT" then
    minerLib.status(miner, message)
    save()
    sendStatus(miner) -- Workers use this acknowledgement to detect a lost controller.
  elseif message.type == "REQUEST_JOB" then
    minerLib.status(miner, message)
    local savedJob = message.jobId and jobs[message.jobId]
    if message.jobId and (not savedJob or savedJob.assignedComputerId ~= miner.computerId or savedJob.state == "DONE" or savedJob.state == "FAILED") then
      miner.jobId = nil
      save()
      send(miner, protocol.message("CANCEL_LOCAL_JOB", { jobId = message.jobId, reason = "controller no longer grants ownership" }))
      return
    end
    save()
    assign(miner)
  elseif message.type == "JOB_ACCEPTED" and type(message.jobId) == "number" then
    local job = jobs[message.jobId]
    if job and job.assignedComputerId == miner.computerId and job.assignmentId == message.assignmentId then
      job.state = "MINING"
      save()
    end
  elseif message.type == "JOB_PROGRESS" and type(message.jobId) == "number" and type(message.progress) == "number" then
    local job = jobs[message.jobId]
    if job and job.assignedComputerId == miner.computerId and job.assignmentId == message.assignmentId then
      job.state = "MINING"
      job.progress = math.max(job.progress or 0, math.max(0, message.progress))
      job.lastProgress = util.now()
      save()
    end
  elseif message.type == "JOB_COMPLETE" and type(message.jobId) == "number" then
    local job = jobs[message.jobId]
    if job and job.assignedComputerId == miner.computerId and job.assignmentId == message.assignmentId then
      job.state = "DONE"
      job.progress = (job.maxX - job.minX + 1) * (job.maxZ - job.minZ + 1) * (job.topY - job.bottomY + 1)
      miner.jobId = nil
      miner.state = "IDLE"
      scheduler.completeIfDone(quarry, jobs)
      save()
      log("job " .. job.id .. " complete")
      send(miner, protocol.message("JOB_COMPLETE_ACK", { jobId = job.id, assignmentId = message.assignmentId }))
    end
  elseif message.type == "JOB_FAILED" and type(message.jobId) == "number" then
    local job = jobs[message.jobId]
    if job and job.assignedComputerId == miner.computerId and job.assignmentId == message.assignmentId then
      job.state = "FAILED"
      job.failure = tostring(message.reason or "worker reported an unspecified failure")
      job.assignedComputerId = nil
      miner.jobId = nil
      miner.state = "ERROR"
      save()
      log("job " .. job.id .. " failed: " .. job.failure)
    end
  end
end

local function findMiner(label)
  for _, miner in pairs(miners) do
    if miner.friendlyId:lower() == label:lower() then return miner end
  end
end

local function command(text)
  local action, argument = text:lower():match("^(%S+)%s*(.*)$")
  if not action then return end

  if action == "start" and quarry.id then
    quarry.state = "RUNNING"; save(); ui.notice = "quarry running"
  elseif action == "pause" and argument == "" then
    quarry.state = "PAUSED"
    for _, miner in pairs(miners) do send(miner, protocol.message(config.pauseReturnsWorkers and "RETURN" or "PAUSE", {})) end
    save(); ui.notice = "paused"
  elseif action == "resume" and argument == "" then
    quarry.state = "RUNNING"
    for _, miner in pairs(miners) do send(miner, protocol.message("RESUME", {})) end
    save(); ui.notice = "resumed"
  elseif action == "stop" then
    quarry.state = "STOPPED"
    for _, miner in pairs(miners) do send(miner, protocol.message("STOP", {})) end
    save(); ui.notice = "workers returning before stop"
  elseif (action == "return" or action == "pause" or action == "resume") and argument ~= "" then
    local miner = findMiner(argument)
    if miner then send(miner, protocol.message(action:upper(), {})); ui.notice = action .. " sent to " .. miner.friendlyId else ui.notice = "unknown miner " .. argument end
  elseif action == "release" then
    local job = jobs[tonumber(argument)]
    if job and job.state ~= "DONE" then releaseJob(job, "operator released job"); save(); ui.notice = "released job " .. argument else ui.notice = "unknown or completed job" end
  elseif action == "list" then
    ui.notice = argument == "jobs" and ("jobs " .. util.count(jobs)) or ("miners " .. util.count(miners))
  elseif action == "show" then
    ui.notice = "quarry " .. (quarry.id or "not configured")
  else
    ui.notice = "commands: start pause [miner] resume [miner] stop return <miner> release <job>"
  end
end

local opened, modemError = protocol.openModem()
if not opened then error(modemError) end
save()
log("controller started")

local timer = os.startTimer(1)
while true do
  ui.draw(quarry, jobs, miners)
  local event, p1, p2 = os.pullEvent()
  if event == "rednet_message" then
    onMessage(p1, p2)
  elseif event == "timer" and p1 == timer then
    minerLib.refresh(miners, config)
    if scheduler.releaseExpired(jobs, miners, config) then
      save()
      log("released work held by offline workers")
    end
    if scheduler.completeIfDone(quarry, jobs) then save() end
    timer = os.startTimer(1)
  elseif event == "key" then
    local entered = ui.key(p1)
    if entered then command(entered) end
  elseif event == "char" then
    ui.char(p1)
  end
end
