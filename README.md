# 🏃 Roblox Movement Utility

A lightweight, modular, and plain Roblox player movement utility featuring speed modification, jump customization, infinite jumping, and collision-safe no-clip.

---

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Features](#-features)
- [Keybinds](#-keybinds)
- [Architecture](#-architecture)
- [Build & Distribution](#-build--distribution)

---

## 🚀 Quick Start

### 1. Load via GitHub Raw
Load directly into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/plain/init.lua"))()
```

### 2. Standalone Single-File Bundle
Or run the bundled standalone version:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/plain/dist/main.lua"))()
```

---

## ⚡ Features

- **WalkSpeed Override** — Smoothly alter character walking speed with automatic original speed caching and restoration upon disable or respawn.
- **JumpPower & JumpHeight** — Override jump power with dynamic gravity support (`JumpHeight = JumpPower² / (2 * workspace.Gravity)`), restoring default values when disabled or respawning.
- **Collision-Safe No-Clip** — Suppress `CanCollide` on character parts using `RunService.Stepped` to walk through obstacles, restoring parts collision on disable.
- **Infinite Jump** — Jump continuously in mid-air via `UserInputService.JumpRequest` and humanoid state transitions.
- **Minimal Movement UI** — Clean, draggable, minimize-capable interface designed solely for movement controls, with touch/mobile support.
- **Clean Lifecycle Teardown** — Full connection cleanup, speed/jump restoration, and part collision restoration on re-execution or close.

---

## ⌨️ Keybinds

| Key | Action |
| :--- | :--- |
| `RightShift` | Toggle Movement GUI |
| `N` | Toggle No-Clip |

*Additional keybinds for Speed, Jump, and Infinite Jump can be bound in the Settings tab.*

---

## 🏗️ Architecture

```
init.lua           → Entry point, lifecycle guard, and module loader
modules/
  Config.lua       → Movement settings, keybinds, and JSON persistence
  State.lua        → Runtime state and active connection registry
  Utility.lua      → Connection registration and cleanup termination
  Movement.lua     → Physics manipulation, No-Clip, Speed, and Jump logic
  UI.lua           → Movement UI coordinator and settings tab builder
  UILibrary.lua    → Clean, draggable, and touch-compatible UI library
  MainLoop.lua     → Input event dispatcher and keybind handler
```

---

## 🛠️ Build & Distribution

To bundle all modules into a standalone single-file script:

```bash
npm run build
```

The bundled script will be output to `dist/main.lua`.