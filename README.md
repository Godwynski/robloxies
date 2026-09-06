# ⚡ Roblox Script Suite: Pure Auto-Aim & LuauLens

A production-grade, modular Roblox toolchain featuring **Pure Auto-Aim v3.0** (a universal, dependency-free in-game utility) and **LuauLens** (an educational game architecture, network diagnostics, and hierarchy analysis suite).

---

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Project Overview](#-project-overview)
- [⚡ Pure Auto-Aim v3.0 (Universal)](#-pure-auto-aim-v30-universal)
  - [Keybinds](#keybinds)
  - [Features](#features)
  - [Architecture](#architecture)
- [🔍 LuauLens Architecture & Diagnostics Suite](#-luaulens-architecture--diagnostics-suite)
  - [Features](#luaulens-features)
  - [LuauLens Keybinds](#luaulens-keybinds)
  - [Module Structure](#luaulens-module-structure)
  - [Offline Report Generation](#offline-report-generation)
- [🛠️ Build & Developer Workflow](#️-build--developer-workflow)
  - [NPM Scripts](#npm-scripts)
  - [Test Suite](#test-suite)
- [🛡️ Code Integrity & Quality Assurance](#️-code-integrity--quality-assurance)
- [📚 Educational Resources](#-educational-resources)

---

## 🚀 Quick Start

### 1. Pure Auto-Aim v3.0 (In-Game Utility)

Load directly into your executor via raw GitHub URL:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/init.lua"))()
```

Or run the compiled standalone single-file bundle:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/dist/main.lua"))()
```

### 2. LuauLens (Roblox Studio & Diagnostics)

Run the standalone single-file analyzer bundle in Roblox Studio Command Bar or in-game diagnostics:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/dist/LuauLens.bundle.lua"))()
```

---

## ⚡ Pure Auto-Aim v3.0 (Universal)

A universal Roblox utility built directly on native engine lifecycles, humanoid tracking, and camera matrices. Operates cleanly across games without hardcoded title-specific dependencies.

### Keybinds

| Key | Action |
| :--- | :--- |
| `RightShift` | Toggle UI dashboard visibility / restore from floating indicator |
| `CapsLock` | Toggle Auto-Aim targeting on/off |
| `T` | Instant snap to nearest target in FOV |

### Features

- **Universal Targeting Engine** — Distance-safe CFrame calculations, configurable FOV radius, smooth aim interpolation (lerp / direct mouse input), velocity prediction, and line-of-sight raycasting.
- **ESP & Visual Overlays** — 2D bounding boxes, customizable player labels, dynamic health bars, distance tags, and snap tracers. Includes safe fallbacks for environments without native Drawing APIs.
- **Movement Enhancements** — WalkSpeed multiplier, JumpPower override, Infinite Jump listener, and collision-safe No-Clip.
- **Kill Feed & Hitmarkers** — Real-time event notifications via standard humanoid lifecycle events and leaderstats.
- **Modern Tabbed UI** — Draggable, minimize-ready interface with Combat, Visuals, Movement, and Settings tabs, supporting both desktop and touch/mobile devices.

### Architecture

```
init.lua           → Universal entry point & runtime module loader
modules/
  Config.lua       → Settings state with JSON persistence and method protection
  State.lua        → Runtime state & target tracking
  Utility.lua      → Helpers, thread management & FPS optimization
  Drawings.lua     → Core Drawing API wrapper with Studio mock proxy
  Aim.lua          → Targeting, prediction & division-by-zero guarded raycasting
  ESP.lua          → Player visual overlays with safe Drawing fallbacks
  Movement.lua     → Physics manipulation & character movement hacks
  Hooks.lua        → Event listeners, scoped per-character health & kill tracking
  UI.lua           → Tab director & settings coordinator
  UILibrary.lua    → Draggable, touch-compatible UI component library
  MainLoop.lua     → Non-blocking RenderStepped loop & keybind dispatcher
```

---

## 🔍 LuauLens Architecture & Diagnostics Suite

An educational software engineering and diagnostic suite designed to help developers, students, and game designers inspect data models, network replication, and client controller hierarchies.

### LuauLens Features

- **Hierarchy & Controller Analysis** — Scans client data spaces (`ReplicatedStorage`, `Players`, `PlayerScripts`, etc.) and categorizes controllers, services, UI components, and replication remotes with recursion depth guards.
- **Network Traffic Monitor** — Intercepts `FireServer`, `InvokeServer`, and `UnreliableRemoteEvent` calls via `__namecall` hooks to record data throughput, argument patterns, and transmission frequencies.
- **Content & Asset Snapshotting** — Captures lightweight structural snapshots of games, computes structural diffs over time, and highlights newly added/removed remotes or altered attributes.
- **Mermaid Architecture Documentation** — Automatically generates system architecture flowcharts, sequence diagrams, and client-server remote contract tables in Markdown.
- **Interactive In-Game UI** — Dark-mode diagnostic dashboard with packet inspection, live search filtering, and clipboard/file export utilities.

### LuauLens Keybinds

| Key | Action |
| :--- | :--- |
| `RightControl` | Toggle LuauLens Diagnostic Dashboard |

### LuauLens Module Structure

```
LuauLens/
  init.lua               → Bootstrapper with hot-reload guard & lifecycle management
  modules/
    Serializer.lua       → Deep table serialization with cycle detection & JSON export
    Utility.lua          → File export, clipboard fallback, and time formatting
    CodeAnalyzer.lua     → Hierarchy scanning & controller classification (depth-capped)
    NetworkMonitor.lua   → Low-overhead remote hooking & packet throughput logging
    ContentTracker.lua   → Target-filtered asset snapshotting & structural diff engine
    DocGenerator.lua     → Mermaid diagram generation & Markdown architecture reports
    UI.lua               → Bounded-buffer, dark-mode diagnostic GUI
```

### Offline Report Generation

Analyze JSON snapshots collected from game sessions offline to generate Markdown reports and interactive HTML dashboards:

```bash
npm run analyze:offline
```

Outputs:
- `examples/sample_generated_report.md` (Mermaid diagrams & remote contracts)
- `dist/report.html` (Interactive web dashboard with rendered Mermaid diagrams)

---

## 🛠️ Build & Developer Workflow

### NPM Scripts

| Command | Description |
| :--- | :--- |
| `npm run build` | Bundles `modules/` into the standalone single-file `dist/main.lua`. |
| `npm run build:analyzer` | Bundles `LuauLens/` into standalone executables `dist/LuauLens.bundle.lua` and `dist/analyzer.bundle.lua`. |
| `npm test` | Runs the automated test suite verifying AST syntax via `luaparse`, method signatures, API parity, schema diffs, and module resolution. |
| `npm run analyze:offline` | Processes sample game analysis JSON into Markdown documentation and HTML dashboard. |

### Test Suite

Run tests locally using Node.js:

```bash
npm test
```

Verification covers:
1. LuauLens file hierarchy and module integrity.
2. API method signatures across all diagnostic submodules.
3. Standalone bundle generation and file size checks.
4. Schema validation and diff engine simulation on sample game data.
5. Offline Markdown report and HTML dashboard generation.
6. API aliases and parity checks (`TakeSnapshot`, `RunAnalysis`, `GetStats`, `GetHistory`, `GenerateArchitectureReport`, `UI.Init`, `UI.Destroy`).
7. Bundler module resolution and prevention of dangling unconditional requires.
8. Full AST syntax validation of all Lua/Luau scripts using `luaparse`.

---

## 🛡️ Code Integrity & Quality Assurance

Recent quality assurance passes introduced several structural and runtime protections:
- **Numerical Stability**: Camera aim operations guard against `Magnitude < 0.05` studs, preventing `NaN` CFrame rotation matrices.
- **Studio & Non-Drawing Compatibility**: Drawing wrappers include mock fallback proxies, ensuring code runs without throwing errors in environments lacking native `Drawing` APIs.
- **Memory & Resource Caps**: Real-time packet inspection buffers are capped (300 logs / 200 Gui elements) to prevent UI frame stutters and memory exhaustion.
- **Class Method Protection**: Configuration loaders enforce strict type checking (`type(self[k]) ~= "function"`) to prevent JSON configs from overwriting class methods.
- **Hot-Reload Safety**: Diagnostic initialization uses global lifecycle tracking (`_G.__LuauLens_Running`) to disconnect connections and clean up Gui elements before re-executing.

---

## 📚 Educational Resources

For an in-depth breakdown of Roblox software engineering, Model-View-Controller (MVC) architecture, component systems via `CollectionService`, and client-server network replication security, see the [Educational Guide](docs/EDUCATIONAL_GUIDE.md).