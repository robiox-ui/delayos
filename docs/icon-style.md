# DelayOS icon style guide

Every DelayOS icon is original artwork drawn by `assets-src/gen_icons.py` (colour icons) and
`assets-src/icon_glyphs.py` (line glyphs). Do not hand-edit the SVGs under `profile/airootfs`: change the
generator and re-run it. Preview: `docs/reports/icons-preview.html`.

## 1. Families

| Family | Canvas | Where it lives | Used for |
|---|---|---|---|
| App tile | 64 | `icons/DelayOS/scalable/apps`, copy in `icons/hicolor/scalable/apps` | DelayOS apps, game placeholders, generic utilities |
| Object | 64 | `scalable/places`, `scalable/mimetypes`, `scalable/devices` | folders, trash, file types, drives |
| Line glyph | 24 | `symbolic/*`, `delayos/shell/icons`, `syskit/.../glyphs`, `settings/icons` | tray, actions, in-app glyphs |
| Category tile | 64 | `scalable/categories` | `delayos-settings-*` (a line glyph on an ink tile) |

The logo (`delayos-logo`, `start-here*`, `distributor-logo`) is the brand mark and is not part of the set's
tile system: it is never placed on a tile. Its shape is defined in `assets-src/brand_mark.py`; the wordmark,
lockups, exports and usage rules are in `docs/brand.md` (generator: `assets-src/gen_brand.py`).

## 2. Palette

The set is built around `Theme.accent` `#4D6BFE`.

| Token | Hex | Use |
|---|---|---|
| B100 | `#E4E9FF` | |
| B200 | `#C5CEFF` | light details on ink, folded corner |
| B300 | `#A9B8FF` | secondary strokes |
| B400 | `#7C93FF` | glyph gradient start, strokes on ink |
| B500 | `#6480FF` | flat tinted glyphs (Settings sidebar) |
| **B600** | `#4D6BFE` | **accent**, solid strokes on paper |
| B700 | `#3350D8` | glyph gradient end |
| B800 | `#2640B4` | details on light glyphs |
| B900 | `#1F2F94` | |
| Ink | `#141A2E` | dark tile end, cut-outs |
| Edge | `#B4BFEA` | 1-unit hairline around paper-coloured objects |

Semantic accents, used for one small detail at most: green `#3DD68C` (Android, OK), amber `#FFB547` (sun),
coral `#FF6B6B` (PDF), mint LED `#9CF5C8`. No other hues.

Gradients (all linear, object bounding box):

| Id | From → to | Direction | Use |
|---|---|---|---|
| `b` | `#7089FF` → `#3F58E8` | top → bottom | blue tile, blue objects |
| `k` | `#2D3657` → `#141A2E` | top → bottom | ink tile |
| `p` | `#FFFFFF` → `#DDE3F7` | top → bottom | paper tile |
| `g` | B400 → B700 | top-left → bottom-right | blue glyph on paper |
| `l` | `#DCE2FF` → `#8FA3FF` | top-left → bottom-right | light glyph on ink |
| `f` / `r` | `#8199FF` → B600 / `#4862EC` → B800 | top → bottom | folder front / back |
| `s` | `#FFFFFF` → `#E6EAF9` | top → bottom | sheets and paper objects |
| `h` | white 50 % → 0 % at 55 % | top → bottom | 1-unit rim light |

Light comes from the top: fills get lighter towards the top, the rim light sits on the upper edge and the
only shadow is the tile's own (the tile shape again, 1.2 units lower, `#0A1030` at 18 %).

## 3. App tiles

- Canvas 64 × 64. The tile is a 56-unit squircle at 4,4:
  `M4 32C4 9 9 4 32 4s28 5 28 28-5 28-28 28S4 55 4 32Z` (corner about 18 units, 32 % of the tile).
- Layers, bottom to top: shadow, tile fill, 1-unit rim (inset 0.5), glyph.
- Three tiles:
  - **blue** (`b`): white glyph, secondary parts white at 55–70 %.
  - **ink** (`k`): glyph in gradient `l`, strokes in B300/B400, white for the one element that matters.
  - **paper** (`p`, rim `#C9D2F5`): glyph in gradient `g`, strokes in B600.
- The glyph sits in the 36-unit box 14..50 (it may reach 12..52), centred optically.
- Strokes are 3–3.8 units with round caps and joins; small radii are 2–4 units, never sharp.
- Two tones at most plus one semantic accent. No text except the three letters on the PDF icons, which
  are drawn as strokes.
- Game placeholders (`delayos-winboot-*`) are always ink tiles with a neutral genre glyph (gamepad,
  crosshair, shield and sword, buildings and bolt, parachute). They never copy a game's logo, lettering
  or colours.

## 4. Objects

- Folders: back plate in `r`, front in `f` with the rim light, emblem in white at 92 %, about 16 units,
  centred on 32,38.5, stroke 2.6.
- File types: one sheet (13..51 × 4..60, corner radius 5, folded corner 13 units in B200, Edge hairline)
  with a single content glyph in the box 19..45 × 22..54.
- Devices have no tile, so their silhouette still reads when an app draws them as a mask
  (`Kirigami.Icon { isMask: true }`).

## 5. Line glyphs

- Grid 24 × 24, live area 3..21, stroke **1.5** (1 px at 16 px), round caps and joins, radii 2.5–3.
- Solid parts are allowed for dots, levels and "filled" variants; nothing else is filled.
- "Off" states: the base glyph at 45 % opacity plus a full-opacity slash from 4,4 to 20,20.
- Levels (Wi-Fi, battery while charging): the unlit part stays visible at 30–40 %.
- One master, three wrappers:
  - icon theme: `class="ColorScheme-Text"` and `currentColor`, default `#e8eaee`. Plasma, Kirigami and
    KIconLoader recolour them for dark and light schemes, so there is one file per glyph and no
    separate dark/light variant.
  - `shell/icons` (stroke `#000`) and `syskit/.../glyphs` (stroke `#fff`): loaded by path and tinted by
    the QML (`isMask`).
  - `settings/icons`: stroke B500, drawn as is inside the sidebar tile.
- Names: `delayos-sym-<name>` for our own glyphs; freedesktop/KDE names as `<name>-symbolic.svg`, and
  for actions and status also `<name>.svg` (the tray asks for the plain name).

## 6. SVG rules

- UTF-8 without BOM, LF. No editor metadata, no embedded rasters, no fonts or `<text>`.
- QtSvg must render the file: use paths, basic shapes, linear gradients, `opacity` and `transform` only.
  No filters, masks, clip paths, patterns or CSS apart from the `current-color-scheme` style.
- Never put a gradient on the stroke of a straight line (its bounding box has no area, so the gradient is
  dropped). Strokes are solid colours.
- Gradient ids are single letters from the table above; an icon only carries the ones it uses.
- Typical size: 0.4–0.8 kB per glyph, 1–2 kB per colour icon.
- Aliases are copies, not symlinks (symlinks break on a Windows checkout).

## 7. Adding an icon

1. Line glyph: add it to `G` in `icon_glyphs.py`, then list it in `SYM_NAMES` and/or map a name to it in
   `FDO`, `SHELL` or `SYSKIT`.
2. Colour icon: add it in `app_glyphs()`, `places()`, `mimes()` or `devices()` in `gen_icons.py`, and
   add other names for it in the matching `*_ALIASES` table.
3. Run `python3 assets-src/gen_icons.py profile/airootfs --preview=docs/reports/icons-preview.html`,
   then `QT_QPA_PLATFORM=offscreen python3 assets-src/icon_sheet.py <dir>` (needs PySide6): it renders
   the PNG contact sheets with QtSvg and lists any file the renderer rejects.

The generator empties `icons/DelayOS`, `shell/icons` and the syskit `glyphs` folder before writing, so a
name that is removed from the tables disappears from the image. No icon cache is shipped: Qt and KDE read
the theme directly, and the theme has no `icon-theme.cache`.

## 8. What stays outside the set

Trademarked logos are never redrawn: Chrome, Firefox, Steam, Lutris, Bottles, ProtonUp-Qt, LibreOffice,
GIMP, VLC, NVIDIA and so on keep their own icons. Everything the theme does not define falls back to `Papirus-Dark`, then `breeze-dark`, then
`hicolor`.
