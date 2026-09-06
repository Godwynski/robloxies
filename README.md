# ⚡ Pure Auto-Aim v3.0 (Universal)

A modular, universal Roblox utility script with Auto-Aim, ESP, Movement enhancements, and dynamic kill feed. Works across every single Roblox game without game-specific dependencies.

## Quick Start

Paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/init.lua"))()
```

Or run the bundled single-file build:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/dist/main.lua"))()
```

## Keybinds

| Key | Action |
|-----|--------|
| `RightShift` | Toggle UI visibility / restore from minimize |
| `CapsLock` | Toggle Auto-Aim on/off |
| `T` | Snap to nearest target |

## Features

- **Universal Compatibility** — Pure Roblox engine lifecycle, team detection, and humanoid tracking compatible with all games.
- **Tabbed UI** — Combat, Visuals, Movement, and Settings tabs.
- **Auto-Aim** — FOV-based targeting, customizable smoothing, prediction, wall check, team check, priority modes, and TriggerBot.
- **ESP** — 2D bounding boxes, player names, dynamic health bars, distance indicators, and tracers.
- **Movement Hacks** — WalkSpeed multiplier, JumpPower override, Infinite Jump, and collision-safe No-Clip.
- **Minimize & Status** — Draggable floating indicator with active feature status.
- **Kill Feed & Hitmarker** — Real-time event notifications via standard humanoid lifecycle and leaderstats.

## Architecture

```
init.lua           → Universal entry point & module loader
modules/
  Config.lua       → Default settings & JSON persistence
  State.lua        → Runtime state & target tracking
  Utility.lua      → Helpers, connections & FPS optimization
  Drawings.lua     → Core Drawing API objects (FOV, HUD, Killfeed)
  Aim.lua          → Universal targeting, prediction & raycasting
  ESP.lua          → Player/NPC visual overlays
  Movement.lua     → Universal physics & character movement hacks
  Hooks.lua        → Engine event listeners, lifecycle & kill tracking
  UI.lua           → Tab director & settings tab
  UILibrary.lua    → Modular draggable UI component system
  MainLoop.lua     → Render loop & keybind handling
```