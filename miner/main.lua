local protocol = require("shared.protocol")
local persist = require("shared.persistence")
local util = require("shared.util")
local configCheck = require("shared.config")
local sm = require("miner.state_machine")
local nav = require("miner.navigation")
local fuel = require("miner.fuel")
local inventory = require("miner.inventory")
local dock = require("miner.dock")
local mining = require("miner.mining")

local config = persist.load("miner/config.db", require("miner.config"))
local valid, configError = configCheck.miner(config)
if not valid then error("Invalid miner/config.lua: " .. configError) end
local state = persist.load("miner/state.db", sm.new())

local function save()
  local ok, err = persist.save("miner/state.db", state)
  if not ok then error("Cannot save miner state: " .. tostring(err)) end
  ok, err = persist.save("miner/config.db", config)
  if not ok then error("Cannot save miner config: " .. tostring(err)) end
end
local function log(message) util.log("logs/miner.log", message) end

nav.init(state, config, save)
local opened, modemError = protocol.openModem()
if not opened then error(modemError) end

local controllerId = config.controllerId
local function send(kind, data)
  if controllerId then return protocol.send(controllerId, protocol.message(kind, data or {})) end
  return false
end
local function heartbeat()
  send("HEARTBEAT", {
    computerId = os.getComputerID(), state = state.state,
    x = state.nav.x, y = state.nav.y, z = state.nav.z, facing = state.nav.facing,
    fuel = fuel.level(), jobId = state.job and state.job.id
  })
end
local function register()
  protocol.broadcast(protocol.message("REGISTER", {
    computerId = os.getComputerID(), role = "miner", softwareVersion = "1.0.0"
  }))
end

local function fail(reason)
  reason = tostring(reason)
  if state.job then
    send("JOB_FAILED", { computerId = os.getComputerID(), jobId = state.job.id, assignmentId = state.assignmentId, reason = reason })
  end
  state.error = reason
  sm.transition(state, "ERROR")
  save()
  log(reason)
end

local function requestJob(force)
  local now = util.now()
  if not controllerId then return end
  if force or not state.lastRequestAt or now - state.lastRequestAt >= config.requestInterval * 1000 then
    state.lastRequestAt = now
    send("REQUEST_JOB", { computerId = os.getComputerID(), state = state.state, jobId = state.job and state.job.id })
  end
end

local function returnDock()
  if not state.dock then return false, "no dock assigned by controller" end
  sm.transition(state, "RETURNING")
  save()
  local ok, err = nav.gotoLocal(state.dock.x, config.transitY, state.dock.z, true)
  if not ok then return false, err end
  ok, err = nav.gotoLocal(state.dock.x, state.dock.y or 0, state.dock.z, true)
  if not ok then return false, err end
  return nav.face(state.dock.facing)
end

local function completeJob()
  if not state.job then return end
  send("JOB_COMPLETE", {
    computerId = os.getComputerID(), jobId = state.job.id, assignmentId = state.assignmentId
  })
  state.lastCompletionSent = util.now()
  state.completionPending = true
  sm.transition(state, "AWAITING_COMPLETION")
  save()
end

local function finishAcknowledgedJob()
  state.job = nil
  state.assignmentId = nil
  state.jobAccepted = false
  state.completionPending = false
  state.jobProgress = 0
  state.checkpoint = nil
  sm.transition(state, "RETURNING")
  save()
end

local function resumeJobTravel()
  if not state.job then
    sm.transition(state, "IDLE")
    save()
    return true, "idle"
  end
  if not fuel.canContinue(nav, state.dock, config.transitY, config.fuelSafetyMultiplier) then
    sm.transition(state, "RETURNING")
    save()
    return true, "return"
  end
  if (state.jobProgress or 0) >= mining.total(state.job) then return true, "complete" end
  if not state.jobAccepted then
    send("JOB_ACCEPTED", { computerId = os.getComputerID(), jobId = state.job.id, assignmentId = state.assignmentId })
    state.jobAccepted = true
    save()
  end
  sm.transition(state, "TRAVELLING_TO_JOB")
  save()
  local x, y, z = mining.target(state.job, state.jobProgress or 0)
  local ok, err = nav.gotoLocal(x, config.transitY, z, true)
  if not ok then return false, err end
  ok, err = nav.gotoLocal(x, y, z, true)
  if not ok then return false, err end
  sm.transition(state, "MINING")
  save()
  return true, "mining"
end

local function assigned(message)
  local same = state.job and state.job.id == message.job.id and state.assignmentId == message.assignmentId
  state.dock = message.dock or state.dock
  if not same then
    state.job = message.job
    state.assignmentId = message.assignmentId
    state.jobProgress = 0
    state.checkpoint = nil
    state.jobAccepted = false
  end
  if same and state.recoveryState then
    local recovery = state.recoveryState
    state.recoveryState = nil
    if recovery == "RETURNING" or recovery == "UNLOADING" or recovery == "REFUELING" or recovery == "AWAITING_COMPLETION" then
      sm.transition(state, recovery)
    else
      sm.transition(state, "TRAVELLING_TO_JOB")
    end
  elseif state.state == "IDLE" or state.state == "CONNECTING" or state.state == "PAUSED" then
    sm.transition(state, "TRAVELLING_TO_JOB")
  end
  save()
end

local function cancelLocalJob(message)
  if not state.job or not message.jobId or state.job.id == message.jobId then
    state.job = nil
    state.assignmentId = nil
    state.jobAccepted = false
    state.jobProgress = 0
    state.checkpoint = nil
    if state.dock then sm.transition(state, "RETURNING") else sm.transition(state, "IDLE") end
    save()
    log("local job cancelled: " .. tostring(message.reason or "controller revoked ownership"))
  end
end

local function message(sender, incoming)
  if not protocol.valid(incoming) then return end

  if incoming.type == "REGISTER_ACK" then
    controllerId = sender
    config.controllerId = sender
    state.lastControllerSeen = util.now()
    state.dock = incoming.dock or state.dock
    -- A brand-new turtle has no usable local coordinates until it is assigned
    -- a dock. The player must place it at that dock, facing the configured way.
    if not state.dockInitialized and state.dock then
      state.nav.x = state.dock.x
      state.nav.y = state.dock.y or 0
      state.nav.z = state.dock.z
      state.nav.facing = state.dock.facing
      state.dockInitialized = true
    end
    if not state.job then
      if state.recoveryState == "RETURNING" or state.recoveryState == "UNLOADING" or state.recoveryState == "REFUELING" then
        sm.transition(state, state.recoveryState)
      elseif state.recoveryState ~= "STOPPED" then
        sm.transition(state, "IDLE")
      end
      state.recoveryState = nil
    end
    save()
    log("registered as " .. tostring(incoming.minerId))
    requestJob(true)
    return
  end

  -- Only the selected controller may command a worker after registration.
  if sender ~= controllerId then return end
  state.lastControllerSeen = util.now()

  if incoming.type == "ASSIGN_JOB" and type(incoming.job) == "table" and type(incoming.job.id) == "number" and type(incoming.assignmentId) == "string" then
    assigned(incoming)
  elseif incoming.type == "CANCEL_LOCAL_JOB" then
    cancelLocalJob(incoming)
  elseif incoming.type == "JOB_COMPLETE_ACK" and state.job and incoming.jobId == state.job.id and incoming.assignmentId == state.assignmentId then
    finishAcknowledgedJob()
  elseif incoming.type == "PAUSE" then
    sm.transition(state, "PAUSED")
    save()
  elseif incoming.type == "RESUME" then
    if state.state == "PAUSED" or state.state == "STOPPED" then
      state.stopAfterReturn = false
      sm.transition(state, state.job and "TRAVELLING_TO_JOB" or "IDLE")
      save()
    end
  elseif incoming.type == "RETURN" then
    sm.transition(state, "RETURNING")
    save()
  elseif incoming.type == "STOP" then
    state.stopAfterReturn = true
    sm.transition(state, "RETURNING")
    save()
  end
end

state.recoveryState = state.state
sm.transition(state, "CONNECTING")
save()
register()
local heartbeatTimer = os.startTimer(config.heartbeatInterval)
local tickTimer = os.startTimer(0.2)
local lastProgress = 0
local lastRegister = util.now()

while true do
  local event, p1, p2 = os.pullEvent()
  if event == "rednet_message" then
    message(p1, p2)
  elseif event == "timer" and p1 == heartbeatTimer then
    heartbeat()
    heartbeatTimer = os.startTimer(config.heartbeatInterval)
  elseif event == "timer" and p1 == tickTimer then
    local now = util.now()
    if state.state ~= "CONNECTING" and state.state ~= "STOPPED" and state.state ~= "ERROR" and controllerId
      and now - (state.lastControllerSeen or 0) > config.controllerLostTimeout * 1000 then
      state.recoveryState = state.state
      sm.transition(state, "CONNECTING") -- pause in place; reconnect before any further movement.
      save()
      log("controller acknowledgement timed out; waiting in place for reconnection")
    end

    if state.state == "CONNECTING" then
      if now - lastRegister >= config.registerInterval * 1000 then register(); lastRegister = now end
    elseif state.state == "IDLE" then
      requestJob(false)
    elseif state.state == "TRAVELLING_TO_JOB" then
      local ok, result = resumeJobTravel()
      if not ok then fail(result) elseif result == "complete" then completeJob() end
    elseif state.state == "MINING" then
      if inventory.isFull(config.inventoryFullSlotThreshold, config.protectedSlots) or not fuel.canContinue(nav, state.dock, config.transitY, config.fuelSafetyMultiplier) then
        sm.transition(state, "RETURNING")
        save()
      else
        local ok, result = mining.step(state, save)
        if not ok then
          fail(result)
        elseif result == "complete" then
          completeJob()
        elseif now - lastProgress >= config.progressInterval * 1000 then
          send("JOB_PROGRESS", { computerId = os.getComputerID(), jobId = state.job.id, assignmentId = state.assignmentId, progress = state.jobProgress })
          lastProgress = now
        end
      end
    elseif state.state == "AWAITING_COMPLETION" then
      if state.job and (not state.lastCompletionSent or now - state.lastCompletionSent >= config.requestInterval * 1000) then
        send("JOB_COMPLETE", { computerId = os.getComputerID(), jobId = state.job.id, assignmentId = state.assignmentId })
        state.lastCompletionSent = now
      end
    elseif state.state == "RETURNING" then
      local ok, err = returnDock()
      if not ok then
        fail(err)
      elseif state.stopAfterReturn then
        sm.transition(state, "STOPPED")
        save()
      else
        sm.transition(state, "UNLOADING")
        save()
      end
    elseif state.state == "UNLOADING" then
      local ok, err = dock.unload(config, nav)
      if not ok then fail(err) else sm.transition(state, "REFUELING"); save() end
    elseif state.state == "REFUELING" then
      local refueled = dock.refuel(config, nav)
      if state.job and (not refueled or not fuel.canContinue(nav, state.dock, config.transitY, config.fuelSafetyMultiplier)) then
        fail("unable to refuel enough to safely return from the current job")
      elseif state.job then
        sm.transition(state, "TRAVELLING_TO_JOB")
        save()
      else
        sm.transition(state, "IDLE")
        save()
      end
    end
    tickTimer = os.startTimer(0.2)
  end
end
