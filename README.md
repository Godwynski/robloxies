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
- **⚡ Master Restaurant Auto-Farm** — One-click master toggle that synchronizes all essential workflows (seating, ordering, cooking, serving, cleaning, cash collection, and **complete quest lifecycle automation** including auto-doing quest objectives and auto-claiming quest rewards) without manual configuration.
- **🛡️ Capability & Affordability Guarded Auto-Buying** — Strictly evaluates player cash balance and prompt/catalog costs before attempting any purchase. Completely prevents buying land, floors, equipment, or staff when not affordable (`Utility.CanAfford`).
- **💰 Minimum Cash Reserve Protection** — Configurable safety slider (default `$2,500`) that prevents the auto-buyer from ever spending into your emergency cash reserve, keeping your restaurant solvent at all times.
- **🏰 Decoupled Land & Floor Expansions** — Land and multi-story floor unlocks are strictly manual opt-in (`AutoExpandEnabled`, `AutoBuyLand`, `AutoBuyFloors`) and are never forcibly triggered by Master Auto-Farm, eliminating premature land purchases.
- **📋 "What I Can Buy" Interactive Catalog Inspector** — Real-time shop and plot scanner that breaks down available upgrades into categorized types (🏰 Land & Floors, 🍳 Cooking Appliances, 🪑 Dining Furniture, 🍽️ Kitchen Equipment, 🌿 Decor, 👨‍🍳 Staff) with live affordability badges (`[ AFFORDABLE ]` vs `[ NEED +$X ]`) and direct buy buttons.
- **🛒 Granular Categorized Purchase Choices** — Fine-grained toggles to choose exactly what the auto-buyer is allowed to buy: Stoves & Ovens, BBQ Grills & Fryers, Dining Tables, Chairs & Booths, Sinks & Appliances, Prep Counters, Decor Plants, Lighting, and Staff (Cooks, Waiters, Cleaners).
- **📜 Auto-Do Quests & Bounties** — Scans for active quest givers, boards, and dialogs, accepts incoming contracts, and parses quest directives (cooking, serving, cleaning, harvesting, purchasing) to prioritize matching objectives in real-time.
- **🎁 Auto-Claim Quests & Rewards** — Automatically scans quest interfaces, dialog popups, and reward remotes to turn in completed missions, claim free gems/cash, and redeem daily gifts and playtime milestones.
- **🔒 Strict Task Completion Guard** — Guarantees the active task is 100% finished on the server (monitoring prompt deactivation, item collection/destruction, hold duration, and post-action settling delay) before moving the avatar to any other task, eliminating dropped actions and premature movement.
- **🔄 Simultaneous Multi-Queue Pipeline** — Eliminates queue starvation with an interleaved round-robin scheduler that balances cooking, serving, ordering, cleaning, seating, deliveries, and quest interactions every cycle rather than locking into a single category.
- **⚡ Workstation Spatial Clustering & Sequential Completion** — When visiting a kitchen counter or table cluster, processes all ready prompts within 14 studs sequentially to completion in a single visit before departing.
- **🪑 Auto-Add Chairs, Tables & Furniture** — Automatically purchases and places dining tables, chairs, stools, booths, appliances, and restaurant decor onto an expanding floor grid.
- **✨ Opportunistic Station Batching** — Concurrently fires nearby ready prompts across all enabled categories within 14 studs of the avatar's current station.
- **🪙 Decoupled Parallel Cash Sweeping** — Continuously collects dropped coins and cash drops across the restaurant floor via `firetouchinterest` on a high-speed background worker without affecting avatar movement or kitchen throughput.
- **🤖 Decoupled Background UI Manager** — Claims rewards, redeems daily gifts, accepts/turns in quests, and hires/upgrades staff on an independent parallel thread without stalling physical cooking or serving loops.
- **🛡️ Mutex In-Flight Locking** — Tracks active prompts in a garbage-collected weak table (`State.InFlightTasks`) to guarantee zero double-triggers, race conditions, or physics desyncs across concurrent workers.
- **🔨 Auto-Place Stored Furniture** — Automatically scans your build inventory for unplaced items, calculates open floor grid coordinates, and places furniture onto your restaurant layout.
- **👨‍🍳 Auto-Hire & Upgrade Staff** — Automatically hires and levels up Cooks, Waiters, and Cleaners from the Manage menu with strict affordability validation.
- **📍 Plot & Anchor Calibration** — Automatically locks onto your restaurant and provides a one-click in-game button to recalibrate your restaurant center, guaranteeing zero cross-plot interference.
- **Smooth Prioritized Dispatcher** — Eliminates teleport seizures by prioritizing and attending to one critical task at a time with configurable station stay duration (0.22s) so the Roblox server reliably processes interactions.
- **Zero-NaN Teleport Safety** — Safe workstation orientation math and downward floor raycasting guarantees the avatar lands stably in front of tables/stoves without flinging, void deaths, or getting stuck in furniture.
- **📊 Production Analytics Dashboard** — Live telemetry console featuring a Hero Master Farm card, live session uptime timer, real-time rate calculator, and a 15-tile responsive metric grid (cash swept, customers seated, tickets cooked, dishes served, tables cleaned, deliveries, harvested produce, restocked goods, floor expansions, store purchases, items placed, staff hired, quests completed, and rewards claimed).
- **🎨 Glassmorphic Fluent UI Suite** — Left-sidebar navigation with Lucide-style icons, active sliding indicator, 5 switchable dark theme presets (Midnight Violet, Emerald Cyber, Sapphire Ocean, Sunset Amber, Obsidian Carbon), and instant search filter.
- **🔔 Toast Notification Engine** — Smooth corner popups with type icons (Success, Info, Warning, Error), progress bars, and timed auto-dismissal.
- **📱 Dynamic Floating HUD Widget** — Compact status pill displaying live farming heartbeat dot, session status, and one-click expand/restore.
- **🎛️ Interactive Direct-Input Sliders & Component Descriptions** — Sliders with draggable tracks and clickable numeric badges to type exact values; every toggle includes clear, helpful sublabels.
- **Own Plot Scoping** — Automatically detects and filters all interactions exclusively to your own restaurant/farm plot.
- **Auto-Fulfill Delivery Orders** — Teleports to and fulfills takeout delivery packages, boxes, and scooters for massive cash multipliers.
- **Auto-Restock Kitchen Storage** — Deposits harvested ingredients into fridges, coolers, and pantries so chefs never run out of food.
- **Auto-Claim Quests & Gifts** — Automatically claims finished quest objectives, achievement milestones, and playtime gifts for free cash and gems.
- **Auto-Seat Customers** — Automatically detects waiting customers at the entrance or host stand and seats them at vacant tables.
- **Auto-Take Orders** — Takes orders from seated customers as soon as they are ready.
- **Auto-Cook Food** — Automatically triggers cooking stations, grills, and ovens to prepare food tickets.
- **Auto-Serve Dishes** — Delivers cooked meals from counters to waiting tables.
- **Auto-Clean Tables** — Clears dirty dishes and wipes tables immediately after customers leave.
- **🧽 Hand State Intelligence & Auto-Wash Sinks** — Real-time avatar hand tracking (Dirty Dishes vs Cooked Food). Automatically routes dirty dishes directly to sinks/dishwashers and scrubs dishes clean, eliminating "Your hands are full rn" and "Sinks are full buy more in shop" errors.
- **🛡️ Reactive Game Toast & Error Interceptor** — Intercepts in-game popups in real-time, applies backoff cooldowns to occupied stations, and serializes prompt interactions to eliminate "You can't do that rn" conflicts.
- **Auto-Collect Cash & Tips** — Sweeps coins, cash drops, and register tips across the restaurant.
- **Auto-Harvest Farm & Ranch** — Gathers crops (wheat, tomatoes) and animal goods to keep the kitchen supplied with ingredients.
- **One-Click Code Redeemer** — In-menu tool to submit active promotional codes (`FISHIES`, `RAR4EVER`) for free exclusive decor.
- **Instant Proximity Prompts** — Removes hold duration (`HoldDuration = 0`), removes line-of-sight requirements, and expands interaction range.
- **Anti-AFK Disconnect Guard** — Keeps sessions active to prevent Roblox's 20-minute idle disconnects.
- **Chair Sit Prevention** — Automatically keeps the avatar standing so you never get stuck sitting in customer chairs.
- **Memory Sanitation Engine** — Automatic periodic garbage collection and table cache recycling for stable 12+ hour overnight farming.
- **GPU Saver Mode** — Optional 3D render disabler for low-power, multi-hour background farming.
- **Complete Script Unload** — Dedicated Close header button (`✕`), right-click floating icon shortcut, and Unload buttons in both Restaurant and Settings tabs that disconnect all listeners, stop all background threads, restore character WalkSpeed/JumpPower/collisions to standard Roblox defaults, and destroy all ScreenGuis cleanly.
- **Configurable Action Loop** — Adjustable station delay and cycle speed sliders.

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