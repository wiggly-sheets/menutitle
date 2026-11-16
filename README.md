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
- Background styles: liquid glass, solid, transparent, outline.
- Settings for font, font size, padding, letter spacing, word spacing, gap,
  left inset, and maximum width.
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
./build.sh
open build/MenuTitle.app
```

For launch at login, move `MenuTitle.app` to `/Applications` first. The login
item points at the app's current location.

The build script uses an ad-hoc signature, which changes on every rebuild.
macOS may therefore ask for Accessibility access again after rebuilding, and
the login item may need re-approval. For a permanent grant, sign the app with a
stable identity.

## Using it

- Left click the title to open settings.
- Right click the title for Settings, Refresh, and Quit.
- Settings changes apply within a second.

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
draws no background.

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
- The app is an accessory app: it has no Dock icon and no app menu of its own.
