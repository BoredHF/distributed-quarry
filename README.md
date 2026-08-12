# Distributed Multi-Turtle Quarry for CC:Tweaked

A restart-safe, no-GPS quarry coordinator. One controller owns the quarry map and cell assignments; any number of mining turtles register over Rednet and work independently. Turtles never coordinate with each other.

## Requirements and layout

Use CC:Tweaked with one computer/controller and mining turtles. Every machine needs a wireless or ender modem; each worker needs a mining tool. Put docks on an edge immediately outside the quarry (the default is `z=-1`, facing south). Put unload/fuel chests in the configured turtle-relative directions. No Geo Scanner, GPS, AE2, HTTP runtime access, or external storage is used.

Coordinates are local: the selected top origin is `(0,0,0)`, +X is width, +Z length, and mining goes toward negative Y. Workers dead-reckon every successful movement through `miner/navigation.lua`; its state is persisted. A transit layer at `Y=1` lets workers travel above the quarry before dropping into isolated cells.

## Install

After the initial project push, `install.lua` is already configured for this repository. If you fork it, change `BASE_URL` to your fork's raw `main` URL, then run one of:

```
wget run <RAW_URL>/install.lua controller
wget run <RAW_URL>/install.lua miner
wget run <RAW_URL>/install.lua selector
```

The installer downloads only the chosen role plus shared modules and creates `startup.lua` when one does not already exist. It intentionally retains existing config and startup files. Configure `controller/config.lua` before first run; worker settings are in `miner/config.lua`. Use ender modems if the controller is outside wireless range.

## Configure docks and storage

`controller/config.lua` generates docks from `dock.originX`, `dock.originY`, `dock.originZ`, `spacing`, `startingIndex`, and `facing`. For unusual layouts set `dock.docks` to a table such as `{ [1]={x=0,y=0,z=-1,facing="south"}, [2]={x=2,y=0,z=-1,facing="south"} }`. Place a newly installed turtle at the next free dock, facing its configured direction, before its first boot. The controller initializes that turtle's local coordinates from the assigned dock once; later boots use its persisted navigation state.

`miner/config.lua` controls `storage.unloadSide` and `storage.fuelSide`; supported sides are `front`, `back`, `left`, `right`, `up`, and `down`. The turtle uses the navigation layer to turn temporarily for rear/side storage and restores its dock-facing direction afterward. `unloadMode="drop"` drops every non-protected inventory slot. Refuelling sucks from the configured fuel side and calls `turtle.refuel()` on non-protected slots. Keep tool/fuel-reserve slots in `protectedSlots`.

## Select and run

1. Start the controller and selector; attach/open modems.
2. Put selector at the top origin. Use `W/S`, `A/D`, `R/F`; press `M` at first then opposite horizontal corner, enter bottom Y, then Enter to transmit.
3. Start/reboot miners. They register dynamically; known computer IDs keep their friendly IDs and docks.
4. At the controller press `s` to start. Press `:` for commands: `start`, `pause`, `resume`, `stop`, `return MINER-01`, `release 4`, `list miners`, `list jobs`, `show quarry`.

The controller creates clipped `cellWidth × cellLength` cells (default 8×8), so non-divisible edges remain in bounds. It assigns only AVAILABLE cells, uses heartbeats, and releases a cell only once its owner has been offline longer than `jobReleaseTimeout`.

## Mining and recovery

Each cell is mined one block high at a time in deterministic serpentine rows, then descends one layer. The worker checkpoints the next block index after each mined block and periodically reports aggregate progress. On low fuel or inventory threshold it returns via the transit layer, unloads/refuels, and resumes its assigned cell.

Controller files are `controller/state/{quarry,miners,jobs,config}.db`; worker files are `miner/{state,config}.db`. Writes go through a temporary file and replacement. After a reboot, the controller restores jobs and workers reconnect. A worker asks the controller to reconcile its saved job; it only resumes when the controller still assigns that job. If communications disappear, it never invents a new job.

## Troubleshooting and limitations

* “No modem found” means attach a modem and ensure it is enabled/openable by Rednet.
* A movement failure enters `ERROR` instead of attacking entities or blindly digging another turtle. Clear the obstruction, inspect `logs/miner.log`, then reboot/restart after checking position.
* Ensure the transit layer above the quarry is clear enough for travel and docks are physically reachable.
* This is an orthogonal rectangular quarry, not cave pathfinding. It deliberately has no ore logic, scanner integration, or arbitrary obstacle routing.
* The controller must remain authoritative; do not copy a miner state file to another turtle.

## Practical test checklist

1. Run a 5×5×5 quarry with one worker.
2. Run 16×16×10 with four workers; verify cell IDs differ and no overlap.
3. Add a worker during mining; it should register and request an AVAILABLE cell.
4. Reboot a worker mid-cell; confirm job ownership then checkpoint resume.
5. Reboot controller; confirm registrations/reconciliation continue.
6. Remove a worker; after its timeout its cell becomes AVAILABLE.
7. Force a full inventory and low fuel; verify dock unload/refuel and resume.
8. Select 10×13 using 4×4 cells; inspect that edge cells are clipped.
9. Pause/resume and confirm no jobs are assigned during pause.
10. Confirm all cells become DONE and controller shows COMPLETE / 100%.
