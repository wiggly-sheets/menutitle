# MenuTitle

Native menu bar window title for macOS. Reads the focused window from
[yabai](https://github.com/koekeishiya/yabai) and draws the title in the left
part of the menu bar, after the front app's menus.

## Features

- Follows the focused window's title and app.
- Moves as the front app's menus change width, so the title stays clear of the
  native menus.
- Stops at the notch on MacBook displays and at other menu bar items.
- Optionally hides while a menu bar menu is open, then returns and keeps the
  front app focused.
- Shortens long titles at the beginning, middle, or end, with a character
  limit, by shrinking the text, or by scrolling it.
- Can remove browser and profile names that browsers append to window titles.
- Optional app icon: sketchybar app font glyph, native app icon, or none.
- Background styles: liquid glass, solid, transparent, outline, with custom
  colors, opacity, corner radius, shape height, and padding on all four sides.
- Configurable left, middle, and right click actions: open settings, show the
  app menu, focus, hide, minimize, or quit the shown app.
- Optional custom position: drag the title anywhere on screen and lock it. The
  position is remembered.
- Optional menu bar item on the right side that shows the same title. It can
  mirror the title's appearance and click actions, or use its own. Both can be
  shown at once.
- Settings for font, font size, padding, letter spacing, word spacing, gap,
  left inset, and maximum width.
- Native font panel picker for family, style, and size, plus sidebar settings
  panes for each group.
- Instant title updates from Accessibility window notifications, with low
  background work while idle.
- Launch at login.
- Hides in native fullscreen spaces and when no titled window has focus.

## Requirements

- macOS 14 or later.
- yabai running with window titles queryable.
- Accessibility access for MenuTitle (System Settings > Privacy & Security >
  Accessibility). The app asks on first launch and shows the permission status
  in its settings window.

The title position is measured through the Accessibility API. Without access,
the title stays hidden rather than guessing a position.

## Build and run

```sh
make run
```

`make` prints every target. `make test` runs the changelog check and the test
suite. `make app` builds `dist/MenuTitle.app`, and `make verify` checks its
architecture, SDK, version, and signature.

For launch at login, move `MenuTitle.app` to `/Applications` first. The login
item points at the app's current location.

The build uses an ad-hoc signature, which changes on every rebuild. macOS may
therefore ask for Accessibility access again after rebuilding, and the login
item may need re-approval. For a permanent grant, sign the app with a stable
identity.

## Release

```sh
make release VERSION=1.0.0
git push origin main
git push origin v1.0.0
```

`make release` moves `[Unreleased]` in `CHANGELOG.md` to the version, runs the
tests, builds the DMG and its checksum, verifies the bundle, commits the bump,
and creates the tag. It never pushes. Pushing the tag starts the release
workflow, which publishes `MenuTitle-<version>.dmg` and its `.sha256` file.
The Homebrew tap picks up that release.

## Using it

- Left click defaults to opening settings. Middle and right clicks can be set
  to different actions in the `Clicking` settings section.
- Enable `Use custom position` to drag the title anywhere on screen. Turn on
  `Lock position` to keep clicks from moving it.
- In `Placement`, choose `Title bar`, `Menu bar item`, or `Both`.
- The menu bar item can mirror the title's appearance and click actions, or use
  its own icon, font, size, and actions.
- Pick fonts with `Choose…` in `Appearance` to open the system font panel. It
  sets family, style, and size; the size slider stays in sync.
- Settings changes apply immediately.

## Icons

`Sketchybar app font` uses `sketchybar-app-font.ttf` from `~/Library/Fonts` or
`/Library/Fonts`. The app reads the font's built-in app name map, so the glyph
matches the running app.

`Native app icon` uses the icon the app shows in the Dock.

## Backgrounds

`Liquid glass` uses Apple's public `NSGlassEffectView` when built with the
macOS 26 or later SDK and running on macOS 26 or later. On older systems the app
falls back to a standard `NSVisualEffectView` blur.

`Solid` fills the title area, `Outline` draws a border, and `Transparent`
draws no background. `Appearance` adds an optional custom text color and
background color, a background opacity slider, a corner radius slider, and a
shape height inset. The `Padding` slider sets the space on all four sides of
the background, so the background moves closer to the text vertically as well
as horizontally. The shape height inset trims that vertical padding further.
Background colors also tint liquid glass.

## Title shortening

The title is shortened only when it does not fit in the space between the app
menus and the notch or the next menu bar item. `Shrink text to fit` reduces the
font size before shortening. `Max length` also caps the character count; set it
to Off to use only the available width. Scrolling replaces shortening: the
title moves left in a loop when it is too wide.

## Sketchybar

This app draws its own menu bar window. If sketchybar still shows its
`window_title` (or `front_app`) item in the same area, the two will overlap.
Either remove that item from the sketchybar config, or use the `Left inset`
setting to push the native title past the sketchybar items.

## Notes

- The focused window is polled once per second. App switches also trigger an
  immediate refresh.
- Only yabai's focused window is shown. Spaces without a focused window have no
  title.
- The custom position is a single saved point, not one per display.
- The menu bar item is hidden when the front app is MenuTitle itself or when
  Accessibility access is missing.
- The app is an accessory app: it has no Dock icon and no app menu of its own.
