# 🍽️ Run a Restaurant Utility

An automation and movement utility for the Roblox game **Run a Restaurant** (by Burnt Toast Labs!), featuring automatic seating, order taking, cooking, serving, cleaning, cash/tip collection, instant interactions, and character physics enhancements.

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
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/run-a-restaurant/init.lua"))()
```

### 2. Standalone Single-File Bundle
Or run the bundled standalone version:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/run-a-restaurant/dist/main.lua"))()
```

---

## ⚡ Features

### 🍽️ Restaurant Automation
- **Auto-Seat Customers** — Automatically detects waiting customers at the entrance or host stand and seats them at vacant tables.
- **Auto-Take Orders** — Takes orders from seated customers as soon as they are ready.
- **Auto-Cook Food** — Automatically triggers cooking stations, grills, and ovens to prepare food tickets.
- **Auto-Serve Dishes** — Delivers cooked meals from counters to waiting tables.
- **Auto-Clean Tables** — Clears dirty dishes and wipes tables immediately after customers leave.
- **Auto-Collect Cash & Tips** — Automatically sweeps coins, cash drops, and register tips across the restaurant.
- **Instant Proximity Prompts** — Removes hold duration (`HoldDuration = 0`) and line-of-sight requirements for lightning-fast interactions.
- **Configurable Action Loop** — Adjustable loop speed slider to balance throughput and stealth.

### 🏃 Integrated Movement
- **WalkSpeed Override** — Sprint through large restaurants with smooth speed overrides and automatic restore.
- **JumpPower & JumpHeight** — Jump over furniture and counters with dynamic gravity compensation.
- **No-Clip** — Walk freely through walls, tables, and customers without getting stuck.
- **Infinite Jump** — Jump continuously in mid-air.

---

## ⌨️ Keybinds

| Key | Action |
| :--- | :--- |
| `RightShift` | Toggle Restaurant GUI |
| `N` | Toggle No-Clip |

*Additional keybinds for Speed, Jump, and Infinite Jump can be bound in the Settings tab.*

---

## 🏗️ Architecture

```
init.lua           → Entry point, lifecycle teardown, and module coordinator
modules/
  Config.lua       → Restaurant automation and movement settings with JSON persistence
  State.lua        → Runtime state and connection registry
  Utility.lua      → Connection registration and termination cleanup
  Restaurant.lua   → Workflow automation (seat, order, cook, serve, clean, cash)
  Movement.lua     → Physics overrides (Speed, Jump, No-Clip, InfJump)
  UI.lua           → Tab director (Restaurant, Movement, Settings)
  UILibrary.lua    → Clean, draggable, and touch-compatible UI library
  MainLoop.lua     → Input event dispatcher and keybind handler
```

---

## 🛠️ Build & Distribution

To compile all modules into a standalone single-file distribution:

```bash
npm run build
```

The output bundle will be saved to `dist/main.lua`.