# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Smooth app switches: the old title leaves before the new app's menus, and the new title fades in after the menu bar settles.
- Short retries when yabai or the menu bar is still settling, so a temporary miss no longer hides the title until the next poll.
- Custom text and background colors, background opacity, corner radius, and shape height inset. Padding now sets the top, bottom, left, and right space inside the background; link the four sides or set each one separately.

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
- Title shortening at the beginning, middle, or end, a character limit, scrolling, and shrink to fit.
- Optional removal of browser and profile names from window titles.
- Configurable left, middle, and right click actions for the title and the menu bar item.
- Launch at login and Accessibility permission status in settings.
