# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- The title no longer flickers when switching spaces, by any method. The panel joins every Space and is never rebuilt, ordered out, or faded for a space change.
- Space changes update the title immediately, and the outgoing title moves clear of menus that are still changing instead of covering them.
- The title stays up while a new app's menus settle, then changes, instead of blanking and fading in.
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
