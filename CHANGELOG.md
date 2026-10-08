# Changelog

All notable changes to PeekMeow are recorded here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). `0.1.0-rc.4` is the published pre-release. Earlier candidates stay published. `0.1.0-rc.2` failed device acceptance. This is not a stable `0.1.0`.

## [0.1.0-rc.4] — 2026-10-08

### Changed

- The macOS corner mark is the supplied calligraphy: a dark 23, a gold slash, and a gold star. It sits in the lower-right. Tasks, Add Task, and the quotation stay outside that rectangle.
- Dragging onto an edge shared with another display keeps 28 pt of clearance, so the rail can still be grabbed.

## [0.1.0-rc.3] — 2026-10-02

### Fixed

- macOS expand no longer traps when the gold mark cannot be loaded. The mark is read from `PeekMeow.app/Contents/Resources/PeekMeowMark.png`. If that file is missing, the panel still opens and the mark is absent.
- A second Windows process no longer silently reveals an older PeekMeow. The same version still asks the running copy to show. A different or unknown version shows a dialog and exits.

### Added

- macOS and Windows binaries carry the version, build number, and git commit. Settings shows the version. Windows also prints `PeekMeow.exe --version` and `--diagnose`, and the tray has About PeekMeow.
- Release checks decode the packaged mark and require `--version` plus `--smoke-ui` on the published Windows executable. Those checks do not replace a device click.

## [0.1.0-rc.2] — 2026-10-01

### Added

- PeekMeow cat app icon on macOS (`AppIcon.icns`) and Windows (`PeekMeow.ico`), including the tray. Small sizes use a simplified version of the same cat.
- Locale date header. Today in the current year includes the weekday and Today (`Oct 1 · Thu · Today`, or the system locale). Other years include the year.
- A short French quotation under Add Task. It hides when the panel is shorter than 350 pt/DIP, and while a root editor is open.
- A faint gold mark in the expanded panel’s lower-right corner. It sits behind the tasks, ignores clicks, and fades further on a light or very small panel.

### Changed

- All Tasks is a filter, not a category. Adding a task while All Tasks is selected stores no category. Uncategorized rows show no label.
- macOS expand/collapse eases out from the attached edge. Reduce Motion skips the spring and scale.
- Windows appearance sliders preview on the panel immediately. OK saves. Cancel or closing Settings restores the snapshot from when Settings opened.

### Fixed

- macOS edge drag uses an event-tracking loop, because a nonactivating panel does not deliver `mouseDragged`.
- Windows category menu is an owned window so it stays above the topmost panel and can be clicked. HWND z-order still needs a device check.

## [0.1.0-rc.1] — 2026-10-01

### Added

- Windows SQLite persistence (`Microsoft.Data.Sqlite`, no EF Core) at `%LOCALAPPDATA%\PeekMeow\PeekMeow.sqlite`. Migration `v1_initial_schema` is transactional and is not repaired by deleting the file. A fresh database contains Work and Personal and no sample rows.
- Windows appearance settings in `settings.json`: theme, panel opacity, custom size, wedge color, background image (PNG, JPEG, WebP, BMP) copied into `Backgrounds\`.
- Self-contained Windows x64 publish and a macOS `.app` bundle. GitHub Release workflow on `v*` tags.
- Release candidate `v0.1.0-rc.1`. The macOS build is ad-hoc signed and not notarized. Windows interaction is build/test verified; device-level validation is still pending.

## [0.1.0-dev] — unreleased

### Added

- Project bootstrap: repository docs, MIT license, SPM package, CI workflow, release script.
- `PeekMeowCore` platform-agnostic models, layout metrics, edge geometry, screen migration, and hover state machine.
- Unit tests for geometry, offset clamping, and hover transitions (`swift run PeekMeowCoreTests`).
- Custom `PeekPanel` accessory window and a collapsed Edge Tab on the right screen edge (4 pt visible / 14 pt hit).
- Stub menu bar extra so the accessory app can be quit.
- Drag the Edge Tab to Left / Right / Bottom with 6 pt drag threshold and 24 pt magnetic snap. Top is not a snap target.
- Per-display `{edge, offset}` saved in UserDefaults (SQLite arrives in Phase 6).
- Menu Bar: Show, Hide, Reset Position, Quit.
- Hover reveal: 160 ms open / 350 ms close, 80 ms grace across the tab–panel gap. Click pins; second click collapses. Preview panel is a local Today list (no database). Peeking never becomes the key window.
- Panel expansion is a single AppKit `animator().setFrame` with a fixed contact edge (maxX / minX / maxY / minY). Expand 200 ms ease-out, collapse 170 ms. Content fades 40 ms after the shell. Edge Tab default is 3×56 pt.
- In-memory memo prototype: add, edit, checkbox, delete. Peeking does not take key; editing does. ⌘↩ saves, Esc cancels. Data is not persisted.
- EdgeAnchor: the handle center is the stable offset. Expanded panels stay centered on it; near corners the body is clamped and the handle stays put.
- Tasks can nest one level of subtasks. Completing a parent completes children; completing all children completes the parent. Completed items move into a collapsed Completed section after a short delay.
- Smart views Today / Inbox / Completed plus custom lists (Work, Personal, Ideas). Default view is Today. New items without a list go to Inbox.
- Inline `+ Add subtask` with continuous Enter. Parent rows show disclosure and `1/3`.
- Bottom nav is a fixed region. More is an AppKit `NSMenu` so it opens on the first click and is not clipped.
- Daily View: `selectedDate`, `scheduledDate` vs `dueDate` vs `completedAt`. Past completion uses `completedAt <= endOfDay`.
- Settings window with General, Appearance, and Behavior. Theme, panel opacity, width, maximum height, wedge thickness / length / opacity / color, hover delays, and Reduce Motion. Values live in UserDefaults and apply without a restart.
- Panel background can be the system material, a solid color, or a picture. The picture is copied into Application Support. Fill or Fit, opacity, and a light overlay are settings. Remove deletes only that copy.
- Launch at Login via `SMAppService.mainApp`. Settings… is in the menu bar. The icon stays visible.
- Category rename, color, order, and archive from Settings. Reset Appearance does not touch SQLite.

### Fixed

- Expanded-panel hit testing no longer mirrors clicks into the task list. The drag handle is the only drag origin.
- Hover collapse follows the live panel frame. Editing, the date picker, and the category menu pause collapse without pinning.
- Category All ▾ is an AppKit menu with a 32 pt target and opens on the first click.
- Static task titles do not take the I-beam cursor. The text field exists only while editing.

### Changed

- PeekMeow is a date + category + task tool, not a project manager. The expanded panel is always a Date View. Today means `selectedDate == today`.
- `UserList` / `listId` are now `Category` / `categoryId`. Default categories are Work and Personal. Filter with All ▾ next to the date.
- Inbox, Completed smart view, and bottom More navigation are withdrawn from v0.1 UI.
- Completed tasks stay in place (checkbox, strikethrough, lower opacity). There is no Completed section.
- Subtasks indent 18 pt under their parent. Only two levels.
- v0.1 edge snap is Left / Right / Bottom. Top is not currently supported. A stored Top placement restores to Right.
- The expanded memo defaults to 340×460 pt with 16 pt corners. It no longer shrinks when the day is short. Dragging the free corner saves a custom size without moving the edge anchor. Older width and height presets migrate once.
- The resize grip is a 22×22 pt corner target. The three ticks are drawn in 14×14 pt and no longer cover the memo.
- Unfinished root tasks from earlier days appear above Today as “未完成 · N”. Their `scheduledDate` is not rewritten. Other dates show only that day’s items.
- Items with no category have no badge. Right-click + Add Task to add a plain Note. Notes never enter the completion count.
- Local SQLite (GRDB) at `~/Library/Application Support/PeekMeow/PeekMeow.sqlite`. Migration `v1_initial_schema` seeds Work and Personal once and does not recreate deleted rows. A failed open or migration leaves the file in place.
- Daily items, categories, notes, subtasks, completion, and Past Unfinished survive quit and relaunch. `selectedDate` still starts at today. Window placement stays in UserDefaults.

### Removed

- Notch Cloak, including hide-in-notch placement, the notch activation sensor, notch hit probe, notch debug overlay, notch mouse monitors, and the DEBUG controls (Show Notch Geometry, Move to Notch Cloak, Experimental Top / Notch).
- Notch-only geometry, UserDefaults flags, and tests. Git history still has the old implementation. It is not on the current roadmap.

### Added

- Native Windows client bootstrap under `windows/`: .NET 8 class library, WPF project, solution, and core tests. No Electron, Tauri, or WebView UI. The WPF window is not device-verified.
- GitHub Actions workflow `.github/workflows/windows.yml` on `windows-latest`: restore, Release build, and test. The macOS workflow is unchanged.
- Windows tray app and a right-edge wedge. Hover expands a basic panel and does not activate the window. Not device-verified.
- Windows edge placement for Left, Right, and Bottom: drag snapping, corner resize, per-monitor DPI conversion, and monitor-name placement in `settings.json`. Not device-verified. Top is not a snap edge.
- Windows daily memo panel, in memory only: date, category filter, tasks, subtasks, notes, past unfinished, and progress. Editing and the date picker can take focus; hover does not. Not device-verified. SQLite is still not opened.
