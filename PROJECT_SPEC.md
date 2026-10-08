# PeekMeow project spec

Status: living document. Update this when an architecture decision lands.

## Product

PeekMeow is intentionally simple. It is a macOS accessory app: a thin tab on a screen edge that expands into a daily memo. It is not Todoist, Things, Notion, or a project manager.

Core model: **Date, Category, Note, Task, Subtask, Completion.**

Nothing else is part of v0.1: no priority, tags, projects, reminders, recurrence, notifications, calendar sync, kanban, statistics, charts, Markdown, attachments, iCloud, or accounts.

Version: `0.1.0-rc.4` (published pre-release `v0.1.0-rc.4`; not stable `v0.1.0`)  
Bundle identifier: `com.peekmeow.app`  
Deployment target: macOS 14+

## Current development environment (2026-09-21)

| Item | Status |
| --- | --- |
| Host | macOS 27.0, arm64 |
| Swift | 6.4 (Command Line Tools) |
| SDK | `MacOSX.sdk` via CLT — AppKit, SwiftUI, ServiceManagement present |
| Xcode.app | **Not installed.** `xcodebuild` is unavailable locally. |
| Git | 2.54.0 |
| Workspace | The user home directory is not a git repository. The app lives in `/Users/weijiaren/PeekMeow`. |

Decision: **Swift Package Manager is the canonical build.** GitHub Actions runs `swift build --product PeekMeow` and `swift run PeekMeowCoreTests` on a macOS runner. A generated `.xcodeproj` is not required for v0.1. Installing Xcode.app is a system-level change and will not be done unless the user asks.

## Module split

```
PeekMeow/                        # git root
  Sources/PeekMeowCore/          # no AppKit, no SwiftUI, no SMAppService
  Sources/PeekMeow/              # app executable, AppKit adapters, SwiftUI views
  Tests/PeekMeowCoreTests/       # Swift Testing
```

Folder mapping versus the original sketch:

| Sketch | Lives in |
| --- | --- |
| `App/` | `Sources/PeekMeow/App/` |
| `Models/` | `Sources/PeekMeowCore/Models/` |
| `Core/AppState.swift` | `Sources/PeekMeow/App/AppState.swift` |
| `Window/` | `Sources/PeekMeow/Window/` |
| Geometry / hover | `Sources/PeekMeowCore/Geometry/`, `Hover/` |
| `Persistence/` | `Sources/PeekMeowCore/Persistence/` (GRDB). Window placement stays in `Sources/PeekMeow/Persistence/` (UserDefaults). |
| `Views/` | `Sources/PeekMeow/Views/` |
| `Utilities/` | `Sources/PeekMeow/Utilities/` |
| `Resources/` | `Sources/PeekMeow/Resources/` |

The macOS split stays. Windows is a separate native client under `windows/`. It does not reuse the Swift package, and the Swift package does not gain a Windows UI.

## Coordinate system

All geometry uses AppKit’s bottom-left origin (`CGRect` in screen space). Core never calls `NSScreen`.

`ScreenGeometry` is the portable snapshot:

- `identifier` — stable per-display id (`CGDirectDisplayID` as a string on macOS)
- `frame`
- `visibleFrame`

`ScreenManager` (app target) is the only type that reads `NSScreen`. It does not read notch safe-area insets or auxiliary top areas.

## Placement

`DisplayPlacement` stores `{displayIdentifier, edge, offset}`, never an absolute x/y as the source of truth.

Offset origin:

- Left / Right: from the **top** of `visibleFrame`, increasing downward
- Top / Bottom: from the **leading** (minX) of `visibleFrame`, increasing rightward

On mouse-up the stack always snaps to the nearest legal edge. Magnet range while dragging is `LayoutMetrics.magnetRange` (24 pt).

Dock / menu bar: the **along-edge** span is clamped to `visibleFrame`. The **perpendicular** position uses `frame` unless that edge is inset by the Dock, in which case `visibleFrame` is used so the tab stays hittable.

## Collapsed modes

1. **Edge Tab** (default) — 4 pt visible wedge, 14 pt hit region.
2. **Cloak** — hidden until the pointer enters the edge hit region.

Visual thickness and hit thickness are independent constants in `LayoutMetrics`. Notch Cloak is not a mode. PeekMeow does not hide in the MacBook camera housing.

## Window

`PeekPanel` is a custom `NSPanel`:

- borderless, transparent, not movable by the system
- `.nonactivatingPanel` so peeking does not steal key focus
- `canBecomeKey` is gated and enabled only in editing
- `collectionBehavior` includes `.canJoinAllSpaces` and `.fullScreenAuxiliary`
- activation policy: `.accessory` (no Dock icon)

Hover is owned by `HoverEngine` (Core) plus an AppKit `HoverController` that feeds pointer enter/exit for the **union** of the edge item and expanded panel (`HoverRegion`, 6 pt padding, 80 ms grace). SwiftUI `onHover` is not the source of truth.

There is no notch sensor window and no notch mouse monitor. The remaining global `mouseMoved` monitor tracks hover enter and exit outside the panel. It is not a notch probe.

## Product model

PeekMeow is intentionally not a project-management application.

Core model:

- **Date** (`selectedDate` / `scheduledDate`) — which day a task is for
- **Category** (`Category`, `categoryId`) — Work, Personal, or user-created. Not a separate page
- **Note** — plain text, no checkbox, no subtasks, not in the completion count
- **Task / Subtask** — one extra indent level only
- **Completion** — stays in place with strikethrough

`Today` is not a list. It only means `selectedDate` is the current calendar day.

There is no Inbox page, no Completed smart view, and no bottom More navigation.

`dueDate` exists on the domain model but is not shown in v0.1 UI.

## Daily View

The expanded panel is always a date view. Default `selectedDate` is today.

- `scheduledDate` — the day the user plans to work on the item
- `dueDate` — deadline; hidden in v0.1
- `completedAt` — when it was actually finished

Historical daily view is derived from current `scheduledDate` + `completedAt`.
Full activity history / event log is a future enhancement.

Completed tasks remain in the day’s list (checked + strikethrough). They are not moved to a Completed section.

Notes with a `scheduledDate` appear on that day but never enter the task completion ratio. A note cannot have a subtask. Add a note from the context menu on + Add Task.

On Today only, unfinished root tasks whose `scheduledDate` is before today appear above the day’s list as “未完成 · N”. Completing one does not change its date. Looking at a past day shows only items scheduled for that day.

A nil `categoryId` is valid and included in All. The row does not show an Uncategorized badge.

## Edge snapping (v0.1)

Supported snap targets: **Left, Right, Bottom**.

**Top is not currently supported.** `ScreenEdge.top` remains so shared geometry can still describe a top frame, but `PlacementPolicy` does not snap to it, the release UI does not offer it, and a stored Top placement restores to Right. Do not keep fixing Top.

Notch Cloak is removed. There is no notch placement, notch snap threshold, notch activation strip, or DEBUG notch menu. Old UserDefaults keys for that feature are ignored. There is no migration.

The Core type `HoverPhase` must be spelled `PeekMeowCore.HoverPhase` in SwiftUI files; SwiftUI also defines `HoverPhase`.

## Persistence (Phase 6)

SQLite via GRDB.swift. The file is `~/Library/Application Support/PeekMeow/PeekMeow.sqlite`. It is never stored in the source tree. Tests open a database under the system temporary directory and must not touch Application Support.

Window configuration stays in UserDefaults: edge, position, panel size, hover delays, and appearance. `selectedDate` is UI state and defaults to today on every launch. It is not stored.

### Migration policy

`DatabaseMigrator` starts with `v1_initial_schema`. Later schema changes are new migrations. A mismatch, a failed migration, or a database that will not open must not delete or recreate the file. DEBUG builds print `[Persistence]`. A failed write does not update the UI as if it had succeeded.

The first migration inserts Work and Personal and no sample tasks. That seed runs only inside the migration, so deleting or archiving those categories is permanent across launches.

### Schema

`categories`: `id` TEXT PK, `name` TEXT NOT NULL, `icon` TEXT NULL, `color` TEXT NULL, `sort_order` INTEGER NOT NULL, `is_archived` INTEGER NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL, `updated_at` DATETIME NOT NULL.

`memo_items`: `id` TEXT PK, `category_id` TEXT NULL → `categories.id`, `parent_id` TEXT NULL → `memo_items.id`, `type` TEXT NOT NULL (`task` | `note`), `title` TEXT NOT NULL, `body` TEXT NULL, `is_completed` INTEGER NOT NULL DEFAULT 0, `completed_at` DATETIME NULL, `sort_order` INTEGER NOT NULL, `scheduled_date` DATETIME NULL, `due_date` DATETIME NULL, `is_archived` INTEGER NOT NULL DEFAULT 0, `created_at` DATETIME NOT NULL, `updated_at` DATETIME NOT NULL.

There is no `forToday` column. `PRAGMA foreign_keys = ON`. Indexes: `scheduled_date`, `category_id`, `parent_id`, `is_completed`, and `(scheduled_date, category_id)`.

Color is stored as an RGBA hex string, never as a SwiftUI `Color`.

### Date semantics

Values are absolute timestamps. A civil day is `[dayStart, nextDayStart)` from `Calendar.current` / `TimeZone.current`. Queries use `scheduled_date >= dayStart AND scheduled_date < nextDayStart`, not `DATE(scheduled_date)`.

`scheduledDate` is the day the item appears. `dueDate` is a reserved deadline and is not shown in v0.1. `completedAt` is when a task was actually completed.

### Queries

Views do not run SQL. `CategoryRepository` and `MemoRepository` do.

A daily query returns root rows (`parent_id IS NULL`, not archived) scheduled on the selected day, including completed tasks. A category filter adds `category_id = selected`. A nil `categoryId` still appears in All. Subtasks are loaded with their parent and are not roots.

Past Unfinished runs only for Today: `scheduled_date < todayStart AND is_completed = 0 AND is_archived = 0 AND parent_id IS NULL AND type = 'task'`, ordered by `scheduled_date DESC, sort_order ASC`. The query does not rewrite `scheduledDate`. A past day shows only that day's rows.

Completing a parent completes its children, completing the last child completes the parent, uncompleting a child reopens the parent, and uncompleting a parent leaves children as they were. Those updates are one SQLite transaction. Deleting a parent deletes its children in one transaction. Archiving a category hides it from the picker and leaves its items in place.

A note may have a `scheduledDate` and a `categoryId`. It cannot have a parent or a subtask, and it has no completion state. Daily progress counts root tasks only.

## Settings

Preferences is a normal macOS window (General, Appearance, Behavior), opened from the menu bar. The menu bar icon stays visible so Settings and Quit cannot be lost.

Appearance and behavior live in UserDefaults under `peekmeow.preferences.*`, through `PreferencesStore`. Views do not call `UserDefaults.set` themselves. Nothing in this window is written to SQLite.

- Theme: System / Light / Dark. Default System. The panel follows it immediately. Text and controls follow the theme. A background image does not.
- Panel opacity: 0.70–1.00. Default 0.94. Applied as the expanded window alpha.
- Panel size: Small 300×360, Medium 340×460 (default), Large 420×560, or Custom. The card is the size. Left and Right add the 14 pt hit rail beside it; Top and Bottom add it above or below. Minimum stored size is 280×300. The window is also clamped to the current `visibleFrame`, and that clamp is not written back.
- Short lists keep the saved size. Overflow scrolls inside the card. The header stays fixed. `+ Add Task` stays under the scroll.
- Dragging the resize grip on the free corner (right edge: bottom-left, left edge: bottom-right, bottom edge: top-right) sets Custom and saves `panelWidth` and `panelHeight`. Width and height are independent. The edge anchor does not move. Auto-collapse pauses while the pointer is down on the grip.
- Corner radius is 16 pt for the expanded card. The material, the image, the content, and the hairline border use that same rounded clip. The expanded window uses the system shadow. The collapsed wedge does not.
- Background: System Material (default), Solid Color, or Image. Solid color has its own opacity (0.40–1.00). An opaque light or dark solid switches text contrast. Image fit is Fill (default) or Fit, never stretched, aligned Top, Center, or Bottom. Image opacity is 0.20–1.00, default 0.60. Overlay is 0–0.80, default 0.25, black in Dark and white in Light.
- A chosen image is copied to `~/Library/Application Support/PeekMeow/Backgrounds/` under a `background-<uuid>` name. Preferences store that filename only, not the original path and not the bytes. Replace copies the new file before deleting the previous copy. Remove and Reset Appearance delete only that copy. A missing or unreadable image draws System Material and Settings says “Background image unavailable”.
- Edge tab: one Wedge. Thickness 2–6 pt (default 3), length 32–96 pt (default 56), opacity default 0.55. Color is System Accent or a custom color stored as hex RGBA. Hover raises wedge opacity slightly. No glow, gradient, or extra shapes. Panel size does not change the wedge.
- The hit region stays 14 pt. Visual thickness does not change it.
- Hover open delay: 0, 0.10, 0.16, 0.25, 0.40 s. Default 0.16. Close: 0.15, 0.25, 0.35, 0.50, 0.75 s. Default 0.35. `HoverEngine` reads the new values without a restart.
- Reduce Motion: the preference or `accessibilityDisplayShouldReduceMotion`. Panel movement duration becomes 0. The short content fade stays.
- Categories in Appearance: rename, color, Move Up / Down, Archive, New Category. Color is a small label only. Defaults remain Work and Personal.
- Reset Appearance to Defaults restores appearance and behavior only. It does not touch tasks, notes, categories, or Launch at Login.

Launch at Login uses `SMAppService.mainApp` only. The switch shows the real system status. A failed register or unregister is shown; PeekMeow does not install a LaunchAgent or rewrite the status on launch.

Hide-in-fullscreen is **experimental** and off by default. No private APIs. Top is not currently supported. Notch Cloak is not part of the product.

## Animation

Duration window: 120–220 ms for expansion, 100–180 ms for handle reveal. No bounce. Direction follows the edge (right opens left, and so on). Reduce Motion skips the frame travel and keeps the short content fade. There is no display link and no mouse polling.

## Testing policy

Anything that does not need AppKit UI is a unit test: edge placement, offset clamping, screen migration, color serialization, hover transitions, resize-handle geometry, later database CRUD. Do not keep tests for removed Notch Cloak behavior.

Tests live in the `PeekMeowCoreTests` **executable** (`swift run PeekMeowCoreTests`). Command Line Tools does not ship XCTest, and a CLT-built Swift Testing `.xctest` cannot `dlopen` `Testing.framework`. The harness is a few dozen lines in `Tests/PeekMeowCoreTests/Harness.swift` and covers the same geometry / hover / color cases. GitHub Actions runs the same command so local and CI stay aligned.

## Out of scope for v0.1

iCloud, AI, agents, Workbench integration, plugins, a full Markdown editor, mobile, analytics, telemetry, crash SDKs, accounts, cloud sync, notarization, Developer ID signing. The Windows client is in `windows/` and is not a port of the AppKit UI.

## Windows client

Native C# / .NET 8 / WPF under `windows/PeekMeow.Windows.sln`. It is not Electron, Tauri, MAUI, Avalonia, or a WebView shell. macOS sources stay where they are.

`PeekMeow.Core` (`net8.0`) holds models, daily rules, edge and resize geometry, and JSON settings. It does not reference WPF. `PeekMeow.Windows` is the WPF app. Tests are `windows/tests/PeekMeow.Windows.Tests` and must use a temp directory, not the real `%LOCALAPPDATA%\PeekMeow`.

Data root, when the app runs: `%LOCALAPPDATA%\PeekMeow\`. Settings file: `settings.json`. Database file, later: `PeekMeow.sqlite`. Backgrounds, later: `Backgrounds\`. IDs are uppercase `8-4-4-4-12` text, the same shape as Swift `UUID.uuidString`.

The SQLite column lists in `MemoSchema` match macOS. Windows does not add task columns. The database is `%LOCALAPPDATA%\PeekMeow\PeekMeow.sqlite`. Appearance stays in `settings.json`.

Supported edges are Left, Right, and Bottom. Top is not a snap target. A stored Top value resolves to Right. Placement is monitor id + edge + offset, not absolute x/y.

Geometry uses a top-left origin, Y down, in DIPs. Win32 monitor rectangles are physical pixels and are converted at the `DpiScale` boundary (`dpi / 96`). Core placement does not mix the two. The working rectangle comes from the monitor work area (`rcWork`), so the taskbar is already excluded. Do not hard-code a taskbar height.

The anchor is `{ monitor device name, edge, offset }`. The device name is `MONITORINFOEX.szDevice`, not a monitor index and not an absolute x/y. Left/Right offset is the anchor center measured down from the working-area top. Bottom offset is measured right from the working-area left. Expand, collapse, hover, and resize do not change it. Only a drag does. A missing monitor moves the window to the current primary. Top is stored only long enough to restore as Right.

Drag starts on the collapsed wedge or, when expanded, on a wedge-sized handle on the outer edge. The panel itself is not a drag surface. Movement under 6 DIP stays a click. Within 24 DIP of a legal edge the wedge magnets; farther away it follows the pointer. Mouse-up always snaps to the nearest of Left, Right, and Bottom on the monitor under the pointer. Right grows left with max X fixed, Left grows right with min X fixed, and Bottom grows up with max Y fixed. Near a corner the panel body clamps and the handle stays on the anchor.

The resize hit target is a 22×22 DIP corner, never larger than 24×24. Right uses the bottom-left, Left the bottom-right, Bottom the top-right. The saved size is the user’s request clamped to 280×300 through 2400×2400. A smaller working area shrinks the live window only. Hover uses the card plus the handle, not the bounding union of the collapsed and expanded rects. Drag and resize pause auto-collapse. Hover and drag do not call `Activate`. `WS_EX_NOACTIVATE` stays on in peek mode. An edit or the date picker clears it without moving the frame, then restores it. That is not a pin.

Launch at startup, when the user turns it on, is one `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` value named `PeekMeow`. No administrator, no `HKLM`, no shell replacement. Memo data is not written to the registry.

The window is a borderless topmost WPF window (`WindowStyle=None`, `ShowInTaskbar=false`, `ShowActivated=false`, `WS_EX_NOACTIVATE` while peeking). The expanded card is a daily memo: `DateOnly` for the selected day, category filter, root tasks and notes, one subtask level, in-place completion, and past unfinished only when the selected day is today. Rows live in `MemoBoard` and are written through SQLite. The sample seed is not used at startup. The tray is `System.Windows.Forms.NotifyIcon` with Show, Reset Position, Settings, and Quit. Reset Position returns to the primary monitor’s right edge, centered. Display and work-area changes come from system events, not a timer. The saved panel size is not replaced by the list.

The WPF UI has not been run on Windows from this macOS workspace. `windows-latest` is the build and test check. A local `EnableWindowsTargeting` compile is not a device test.
