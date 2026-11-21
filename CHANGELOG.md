# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.6] - 2026-11-21

### Added
- Title bar position setting: next to app menus, left or right of the notch, centered on a display without a notch, or a custom position that can be locked.

### Changed
- Placement and Position settings now share one Position pane.

### Fixed
- The Position picker keeps the selected position instead of snapping back to next to app menus.

## [1.1.5] - 2026-11-20

### Changed
- Title scrolling now runs as a Core Animation transform instead of redrawing the view every frame, so scrolling no longer costs about 11% CPU.
- The app font status and update controls moved from Appearance to General.

## [1.1.4] - 2026-11-20

### Fixed
- The panel keeps the app icon's slot while the icon loads, so the width no longer jumps when the icon arrives.
- A custom position saved on the display the panel was dragged to is now used, instead of jumping back to the menu bar's display.
- The status item title is capped at 40 characters, so a long uncapped title no longer takes most of the menu bar.
- The title and app icon now change together during a space change. The title no longer waits for the menus to settle, and it keeps moving clear as they change.
- A long title no longer covers the next app's menus during a space change. The panel moves clear as soon as the space changes, then tracks the menus frame by frame without re-running the title query until their width holds steady.
- App icons load off the main thread and are cached per app, so a space change never waits for icon data. If no room is left beside the menus, the title hides instead of covering them.
- The title clears as soon as the front app's last window closes, instead of keeping the last window's title. A window that yabai still reports is ignored if it belongs to another app.
- The menu bar query that moves the title clear of menus now runs off the main thread, one query at a time, so an app that stops responding can no longer freeze the title or the settings window.
- A short title now stays visible beside the menus instead of hiding, and a title hidden for lack of room comes back when room returns. Menu tracking also stays alive while the title is hidden.
- Menu tracking now measures each display on its own. A menu opened on a stacked or secondary display hides the title, and Mission Control or Exposé on a smaller display is detected too.
- App icons load only when a native icon is actually shown, so background apps and icon-free styles no longer pay to load them.
- A hidden long title stops scrolling, menu checks share one window-list snapshot, browser names are inspected only when stripping is on, and a wake rebuild cancels any drag in progress.

## [1.1.3] - 2026-11-20

### Fixed
- The title no longer flickers when switching spaces, by any method. The panel joins every Space and is never rebuilt, ordered out, or faded for a space change.
- Space changes update the title immediately, and the outgoing title moves clear of menus that are still changing instead of covering them.
- The title stays up while a new app's menus settle, then changes, instead of blanking and fading in.
- After sleep and wake, the title appears on every Space again, not only the Space that was active at sleep.
- The title no longer appears briefly on another app's full-screen Space before hiding.

## [1.1.2] - 2026-11-16

### Fixed
- The title no longer stays hidden after sleep, wake, or a login screen change. The panel is rebuilt on the active Space when macOS strands it on an old one.
- The title reasserts itself if macOS orders the panel out or leaves it mid-fade, instead of waiting for the title to change.
- A drag interrupted by sleep no longer leaves the title stuck.

## [1.1.1] - 2026-11-16

### Added
- An adjustable scroll speed for long titles, from 10 to 120 points per second.
- Browser and profile name stripping now detects browsers at runtime, matches each app's own title suffix, and accepts a custom comma-separated suffix list.
- The sketchybar app font is no longer assumed to be installed. MenuTitle downloads it on first launch, checks GitHub once a day when automatic updates are on, and has a manual **Check Now** button in Appearance.

## [1.1.0] - 2026-11-16

### Added
- The app now ships and runs as `MenuTitle` everywhere: SwiftPM target, executable, and process name in Activity Monitor.
- The title hides while Mission Control or Exposé is on screen.
- Smooth app switches: the old title leaves before the new app's menus, and the new title fades in after the menu bar settles.
- Short retries when yabai or the menu bar is still settling, so a temporary miss no longer hides the title until the next poll.
- Custom text and background colors, background opacity, corner radius, and shape height inset. Padding now sets the top, bottom, left, and right space inside the background; link the four sides or set each one separately.
- The title hides only for a menu bar menu that overlaps it, so unrelated popup windows no longer hide it.
- Custom position is saved per display.
- MenuTitle checks for yabai at launch and offers to install it instead of starting without window titles.
- An Accessibility alert at launch explains why the title and menu bar item are hidden.
- Press highlight on the floating title for left, middle, and right clicks.
- Hardened app-font parsing and Accessibility type checks against malformed data.

## [1.0.0] - 2026-11-16

### Added
- Sidebar settings window with Appearance, Placement, Clicking, Title, Position, General, and Permissions panes.
- Native font panel picker for family, style, and size, with the size slider kept in sync.
- Instant title updates from Accessibility window notifications, with a slower background poll as fallback.
- Menu bar title for the focused yabai window, placed after the front app's menus.
- Notch and menu bar item clamping, with an optional custom draggable position.
- Optional right-side menu bar item with its own appearance and click actions.
- App icon styles: sketchybar app font glyph, native app icon, or none.
- Liquid glass, solid, transparent, and outline backgrounds.
- Title shortening at the beginning, middle, or end, a character limit, scrolling with an adjustable speed, and shrink to fit.
- Optional removal of browser and profile names from window titles, with browser detection at runtime and custom suffixes.
- Configurable left, middle, and right click actions for the title and the menu bar item.
- Launch at login and Accessibility permission status in settings.
