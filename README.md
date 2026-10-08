# PeekMeow

A lightweight edge-mounted memo utility for macOS and Windows.

PeekMeow keeps a short list of tasks and notes on the edge of the screen. It opens when the pointer rests on the edge and gets out of the way when the pointer leaves.

Platforms:

- macOS 14 or later
- Windows 10 22H2 or later, and Windows 11

Features:

- Edge hover
- Daily tasks
- Categories
- Subtasks
- Notes
- Local SQLite
- Custom appearance
- Background image
- Resizable panel

PeekMeow is local-first. There is no account, no analytics, and no cloud upload.

macOS is a native Swift / SwiftUI / AppKit app. Windows is a separate native C# / .NET 8 / WPF app. Neither is an Electron, Tauri, or WebView shell.

Supported edges are Left, Right, and Bottom. Top is not a snap target.

## Download

Release candidates are published on [GitHub Releases](https://github.com/ginitur/PeekMeow/releases). `v0.1.0-rc.4` is the newest published pre-release. It is not a stable `v0.1.0`. `v0.1.0-rc.1`, `v0.1.0-rc.2`, and `v0.1.0-rc.3` stay on the releases page. `v0.1.0-rc.2` did not pass device acceptance.

| Platform | Asset | Run |
| --- | --- | --- |
| macOS 14+ on Apple silicon | `PeekMeow-macOS-0.1.0-rc.4.zip` | Unzip and open `PeekMeow.app` |
| Windows x64 | `PeekMeow-Windows-x64-0.1.0-rc.4.zip` | Unzip and double-click `PeekMeow.exe` |

Check `SHA256SUMS.txt` on the release against the downloaded zip.

The Windows build is self-contained for `win-x64`. It does not need a separate .NET 8 install. The Windows UI has automated build and logic tests. It has not been clicked through on a Windows machine yet: device interaction validation is pending.

### macOS Gatekeeper

This release candidate is not notarized.

If macOS intercepts the app, use the confirmation macOS already provides: Finder → Right Click → Open. Do not turn off system security protections.

The app is an accessory: no Dock icon. Quit from the menu-bar note icon.

Opening the `.app` uses the same data as `swift run`:

`~/Library/Application Support/PeekMeow/PeekMeow.sqlite`

Preferences stay in the standard user defaults. The bundle does not create a second database.

## Privacy

PeekMeow does not upload memo contents.

macOS data:

`~/Library/Application Support/PeekMeow/`

Windows data:

`%LOCALAPPDATA%\PeekMeow\`

That folder holds `PeekMeow.sqlite`, `settings.json`, and `Backgrounds\`. A background picture is copied there. The original file is left where it was. Nothing in that folder is included in a release package.

A fresh install creates two categories, Work and Personal, and no tasks or notes.

## Windows startup

Launch at Startup is off until it is turned on in Settings. The switch writes one value named `PeekMeow` under the current user's `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. It does not need an administrator and it does not write `HKLM`. Memo text is not stored in the registry.

A second launch does not open another edge panel. It asks the running instance to show itself.

## Build

macOS, from a checkout:

```sh
swift build --product PeekMeow
swift run PeekMeowCoreTests
./scripts/build-app.sh
```

`scripts/build-app.sh` writes `dist/PeekMeow.app` and `dist/PeekMeow-macOS-<version>.zip`. The release build is ad-hoc signed for local use. It is not a Developer ID signature and it is not notarized. Debug overlays and the debug menu are compiled out of Release.

Windows, from a checkout:

```sh
dotnet test windows/PeekMeow.Windows.sln -c Release
```

`windows/scripts/package.ps1` publishes a self-contained `win-x64` build to `windows/dist/PeekMeow-Windows-x64/` and zips it. There is no MSIX and no Store package.

GitHub Actions runs the macOS tests, a packaged macOS resource check, the Windows tests, and `PeekMeow.exe --smoke` plus `--version` and `--smoke-ui` after publish. Those commands do not prove the category window, quote, or corner mark on a real Windows desktop. The Release workflow runs only when a `v*` tag is pushed. It does not publish a release from every push to `main`.

## Out of scope

Priority, tags, projects, reminders, recurring tasks, calendar sync, cloud, accounts, AI, Markdown, and attachments are not in this version. There is no Inbox, Completed page, or Top edge.

## License

[MIT](LICENSE)
