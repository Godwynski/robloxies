# ⚡ Pure Auto-Aim v2.2 (Modular)

A modular Roblox auto-aim script with ESP, diagnostics, and a built-in game scanner.

## Quick Start

Paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/init.lua"))()
```

## Keybinds

| Key | Action |
|-----|--------|
| `RightShift` | Toggle UI visibility / restore from minimize |
| `CapsLock` | Toggle Auto-Aim on/off |
| `T` | Snap to nearest target |

## Features

- **Tabbed UI** — Combat, Visuals, Settings, and Info tabs
- **Auto-Aim** — FOV-based with smoothing, prediction, wall check, team check
- **ESP** — Boxes, names, health bars, distance, tracers
- **Scanners** — Built-in game diagnostics (remotes, configs, environment, teams)
- **Minimize** — Draggable floating circle with status indicator
- **Instant Refresh** — Hot-reload from GitHub without rejoining
- **Kill Feed** — Real-time kill/death/assist notifications

## Architecture

```
init.lua           → Entry point & module loader
modules/
  Config.lua       → Default settings
  State.lua        → Runtime state
  Utility.lua      → Helpers & cleanup
  Drawings.lua     → Drawing API objects
  Aim.lua          → Targeting logic
  ESP.lua          → Player/NPC overlays
  Hooks.lua        → Remote event listeners
  UI.lua           → Tabbed interface
  MainLoop.lua     → Render loop & keybinds
  Scanners.lua     → Game diagnostics
```