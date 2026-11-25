# TEMUOS_LINUX desktop UI specification

This spec rebuilds the FlowOS desktop as it appears in its demo videos, for KDE Plasma 6 on Wayland at a 1920×1080 reference screen. Only the branding changes. Layout, sizes, colours, texts, behaviour, icon style and wallpaper style should match the videos.

---

## 0. Sources, conventions, brand markers

### 0.1 Videos used (newest wins on conflicts)

| Priority | Video id | Upload date | Code in this doc | How the screen appears | Scale to 1080p |
|---|---|---|---|---|---|
| 1 (primary) | WvjW8ixeIIE "FlowOS Is Everything Windows 11 Should Have Been" | 2026-11-24 | **[W mm:ss]** | Real OS, inset at x≈126 y≈26 w≈1026 h≈580 in the 1280×720 frame. Many shots are camera-zoomed about 1.3–1.5×. | frame px × **1.875** (unzoomed shots only) |
| 2 | TrNPd5U-_eM "FlowOS demo" | 2026-11-17 | **[T mm:ss]** | Real OS, inset at x=127 y=27 w=1024 h=575 | frame px × **1.875** |
| 3 | 2uwxYRGDsj4 "This Isn't Windows…" | 2026-11-09 | **[2 mm:ss]** | Real OS, full frame (VMware). An older build: light title bars, crimson accent. | frame px × **1.5** |
| — | 4Tyj6ZfUORk | oldest | — | **Excluded** (older UI, mostly a mock-up) | — |

Rules for reading the source tags:
- An element seen only in an older video is specified from that video and tagged with it.
- When versions differ, the WvjW form is normative. Differences are noted as "older:".
- The marketing captions, title cards, rounded "screen" frames, end cards and blurred nature backgrounds belong to the videos, not the OS. **Do not build them.**

### 0.2 Brand substitution markers

`⟦FlowOS⟧` → **TEMUOS** · `⟦Velotic Store⟧` → **TEMUOS Store** (suggested) · `⟦Velotic⟧` (logo word) → **TEMUOS** · `⟦Velotic Studios⟧` → your publisher name · `⟦flowos.veloticstudios.com⟧` → your URL · `⟦LOGO⟧` → the TEMUOS logo.

FlowOS's own logo is a circle split into 4 quadrants by a thin cross-shaped gap. The top-left and bottom-right quadrants are light pink `#F0506E`, the other two are crimson `#A3173F`. Do **not** copy it. Use a TEMUOS mark of the same size class: a 16–18 px glyph in the top bar, and a 26 px glyph in the dock and Start button.

### 0.3 Global design tokens (dark mode = default)

All colours were sampled from full-res frames. Glass values are the tint that gives the observed result over the wallpaper.

| Token | Value | Evidence |
|---|---|---|
| `accent` (default "Coral") | **#F47D67** (range #EE7E69–#F87F66) | Toggle on #F87F66, slider knob #F6816D, swatch #EE7E69 [W 0:45, 6:01] |
| `accent-soft` (selection fill) | accent at 22% over dark ≈ **#4A2B2E** (coral-brown) | Start answer rows, desktop icon selection, Files selection [W] |
| `accent-border` | accent at 60% ≈ #A9716B | Selected "Dock and top bar" card border [W 4:57] |
| `brand-crimson` (logo, Settings "Dock" thumbnails, Store hero) | #D4194F / gradient #7A0F35→#C21E55 | [T], [W 4:57] |
| `window-bg` | **#0E1018** | Settings body and title bar [W 4:57] |
| `window-sidebar` | #0E1017 (same as body; no contrast) | [W] |
| `card` | **#151821** (hover #1B1F28) | Settings rows [W 0:45] |
| `card-2` / nav selected | #23242D | [W 4:57] |
| `field` | #1E2129, 1 px border rgba(255,255,255,0.08) | Dropdowns [W 0:45] |
| `text-1` | #F2F3F5 | |
| `text-2` (secondary) | #9AA0AA | Subtitles |
| `text-3` (muted / placeholder) | #7C828C | |
| `toggle-off-track` | #6A6D76 knob on #2A2D35 track, 1 px border #6A6D76 | [W 4:57] |
| `slider-track` | #444A52 (3 px) | [W 0:45] |
| `success` | #6CCB7A | Store installed dot, installer done |
| `glass-dark` (Start, Command bar, CC, menus, banners) | rgba(8,16,26,**0.78**) + blur 40 px + saturate 1.3 + 1 px rim rgba(255,255,255,0.10) | Start body #0E2533 over wallpaper #318599 [W 0:04] |
| `glass-dark-light` (dock, top bar) | rgba(6,14,22,**0.45–0.55**) + blur 30 px + 1 px rim rgba(255,255,255,0.12) | Dock #2A5762 over #4E97A8; top bar #0B1A2C over #122740 [W 0:04] |
| `glass-tile` (CC tiles and cards on glass) | rgba(255,255,255,0.07); hover 0.10 | CC tile #1C242C over panel #041524 [W 5:34] |
| `glass-light` (light mode) | rgba(246,247,250,0.78) + blur, text #15171C, tiles rgba(255,255,255,0.65) | [T 4:30], [2 0:46] |
| Shadow (windows and popups) | 0 12 40 rgba(0,0,0,0.45) + 0 2 6 rgba(0,0,0,0.3) | |

**Radii (1080p):**
- Windows 12 px.
- Start / Command bar / Control Center / Quick Look 16 px.
- Notification banner and OSD 18 px.
- Cards and rows 8 px.
- Buttons and fields 6–8 px.
- CC tiles 14 px.
- Dock 14 px.
- Icon squircles 22% of size (superellipse).
- Chips and toggles fully round.

**Typography:** **Inter** for all shell and app UI. The weights used are Regular 400, Medium 500 and Semibold 600, with Light 300 for the installer percentage. Notepad's editor uses a monospace font (closest: JetBrains Mono / Cascadia Mono, 14 px). The sizes at 1080p are:

| Role | Size and weight |
|---|---|
| top-bar text | 13 px Medium |
| body / row title | 13–14 px |
| subtitles | 11.5–12 px |
| section headers | 13–14 px Semibold |
| page title / breadcrumb | 28 px Semibold (parent part `text-2`, the "›" in `text-3`) |
| greetings | 30 px Semibold |

**Accent palette (Settings › Colours, 11 swatches) [W 6:01]:**
- Row 1: Crimson #B41D49, **Coral #EE7E69 (default)**, Peach #DB956A, Pink #D87592, Salmon #E67B84, Amber #E8BC6A.
- Row 2: Green #89CA80, Teal #6DC4A6, Blue #7D9CD0, Violet #AA8CDA, Grey #C0C4C8.

Older builds: [2] used crimson #E52D4F as the accent, and its later footage used orange.

**Icon style.**
- **App icons** are glossy rounded-square squircles: a vertical gradient (lighter at the top), a soft inner top highlight, and a light 1 px inner rim. The glyph is a simple white or cream symbol with a slight drop shadow.
- **System glyphs** (top bar, dock Search and Task View, CC, menus) are thin 1.5 px monochrome line icons in Lucide/Fluent style.
- See §3.3 for each icon.

### 0.4 Motion tokens

| Name | Spec |
|---|---|
| `pop` (Start, command bar, menus, CC, calendar) | opacity 0→1 + scale 0.96→1 + translateY 8→0 px, **120 ms**, ease-out (cubic-bezier(0.2,0.8,0.2,1)). Close: 90 ms fade. [W 0:04 ≈70–100 ms, 0:30.8 ≈100 ms] |
| `island` (notification banner, OSD pill) | from width 0.6 at the final top position, opacity 0, blur 8 px → width 1.0, opacity 1, **220–330 ms**, spring with about 4% width overshoot. No vertical slide. [2 0:52.9, W 2:53, T 4:34.8] |
| `slide-panel` (clipboard/emoji) | from the bottom edge, translateY 40→0 + fade, 160–200 ms ease-out [W 0:54] |
| `genie` (minimise) | KWin Magic Lamp, **400–450 ms** [W 2:55, 4:30] |
| `desktop-switch` | KWin Slide, horizontal, 300 ms ease-in-out. The top bar and dock stay put. [W 4:20] |
| `dock-autohide` | slide down 90 ms; return slide up 100 ms ease-out [W 4:58–5:05] |
| `wallpaper-change` / dark↔light | crossfade **400–500 ms**. The shell surfaces switch in 1 frame. [T 4:29.4, 4:54.5] |
| `toast-up` (in-app toasts) | translateY 30→0 + fade, 100–150 ms [T 4:54.4] |
| Window snap / maximise / dock↔taskbar switch | **instant** (no animation) [T 4:45.8, W 4:51] |
| Colour hover preview | instant (1 frame) [W 6:01] |

---

## 1. Boot, splash, login, lock

**Not shown in any of the 3 videos.** None of them contain a firmware/boot menu, Plymouth splash, SDDM greeter or lock screen.

- [2 0:00–0:05] opens with a dark splash (near-black #0B0B10 with a dark maroon radial glow at the top centre, the logo about 132 px, and text). This is a video title card. It is useful only as a style reference: after 0:05.0 the text and logo fade to black over 300 ms (linear), then the desktop fades in from black over 250 ms (wallpaper, top bar and dock together).
- The installer's Done page implies a dual-boot menu ("…remove the USB stick when the screen goes dark") without showing one.

**Implementation decision:** build the boot and login in the same language as the rest of this spec.
- **Plymouth:** background #0B0B10 with a radial glow of `brand-crimson` at 18% opacity, centred at 50% / 0%. ⟦LOGO⟧ 132 px centred at y=45%. A 3-dot pulse in accent below it. The handoff to the desktop is the 300 ms fade-to-black plus 250 ms fade-in seen in [2].
- **SDDM / lock screen:** they are not shown, so autologin is acceptable. If a greeter is needed:
  - the current wallpaper blurred 40 px, with a 30% black overlay
  - an 88 px avatar circle (initial letter, `card-2` fill)
  - the name in 20 px Semibold
  - a 280×40 password field (`field`, radius 8, accent focus border)
  - the clock "HH:mm" 72 px Light above it, and the date "dddd d MMMM" 16 px
- The CC **Lock** button (§6) calls `loginctl lock-session`.

---

## 2. Desktop

Reference frames: `WvjW_00m00.5s_desktop_dock_topbar.png`, `WvjW_00m04.5s_start_open_unzoomed.png`.

### 2.1 Wallpapers

**Default in the newest build: "⟦FlowOS⟧ Tide"** [W, all]. It is 5–6 layered smooth horizontal waves in a paper-cut style.
- Each wave band is darker at the top and lighter at the bottom. Colours go from deep navy at the top (#0F2440 → #122740) through steel blue (#2E5E86) to aqua/turquoise at the bottom (#4E97A8 → #8FD0DA).
- Each wave crest has a thin, soft, light rim (1–2 px, white at 25%) and a subtle drop shadow below it.
- Wave crests are gentle (amplitude about 8–12% of screen height), and their phases are offset.
- The light (day) variant is the same shapes in white / pale ice-blue [T 4:29.6].

**Bundled set** (Settings › Personalisation › Background shows **14 thumbnails** [T 4:50]; the caption says "Twelve"). In order, each has a night (dark) and a day (light) version where one exists:
1. pink/crimson mountains (the installer background)
2. green aurora
3. white/ice-blue clouds
4. orange bubbles
5. dark grey glass slabs
6. purple-to-teal horizon gradient with a single soft curve
7. blue concentric arcs
8. green blobs/hills
9. **pink petal / feather fan on plum** (default in [T])
10. dark navy diagonal pills
11. purple/magenta neon ribbons
12. blue-grey light streaks
13. teal/blue layered waves = **Tide** (default in [W])
14. blue-orange gradient with pink "firework/flower" bursts

Image wallpapers in Pictures [W 1:54]: Aurora.jpg (pale mint/white soft gradient), Drift.jpg (pale blue), Pebble.jpg (soft green 3D pebbles), Tide.jpg.

[2] used nature photos (waterfall, forest rays, glacial lake, aurora, coast cliffs). These are superseded; do not ship them as defaults.

**Behaviour:** dark mode uses the night version and light mode the day version, with a 400–500 ms crossfade on change. The UI text is "⟦FlowOS⟧ wallpapers. Dark mode uses the night version where there is one."

### 2.2 Desktop icons [W 4:36–4:50, 5:10–5:21]

- **Grid and icons:** free-placement grid starting at top-left (first icon at about x=40, y=48 px at 1080p), cell about 96×100. Icons are 48 px: file-type document icons (a white sheet with a small coloured badge; images show a thumbnail). Labels are 12 px, white with a text shadow, up to 2 lines, centred.
- **Selection:** a rounded tile (radius 6) in `accent-soft` (#4A2B2E at about 85%) with a 1 px accent-border.
- **Behaviour:**
  - Positions persist ("Desktop icons stay where you put them.").
  - Multi-select drag moves both icons.
  - **F2** opens an inline rename field (dark field, 1 px accent outline, text pre-selected).
- **Right-click menu** (`glass-dark` menu, radius 10, item height 32, 14 px icons, 13 px text, hover row rgba(255,255,255,0.08) radius 6). Items, with `|` marking separators:
  `New folder`, `New text file`, `Paste`, `Sort by name`, `Refresh` | `Change wallpaper`, `Display settings`, `Personalise`.
  Every item has an icon: folder-plus, file-plus, clipboard, sort-arrows, refresh, image, monitor, brush.
- **Refresh** re-reads the folder: new files appear and thumbnails regenerate.

---

## 3. Top bar, dock, taskbar

### 3.1 Top bar ("Dock and top bar" mode)

Reference frames:
- `WvjW_00m04.5s_start_open_unzoomed.png`
- zoom `me_topbar.png`
- [T] `zoom\TrNP_03m05.0s_gaming_pill_x2.png`
- [W] `zoom\WvjW_topbar_windows_engine*.png`

**Geometry and fill**
- Full width (0..1920), **height 28 px**, at the top edge, no margin [W 0:04: frame y 26–40].
- Fill `glass-dark-light`, sampled #0B1A2C over #122740. A 1 px bottom hairline rgba(0,0,0,0.35), plus a 1 px rgba(255,255,255,0.04) below it.
- Light mode: rgba(240,242,246,0.75) with dark glyphs and text #1B1D22.

**Left side**
- ⟦LOGO⟧ 16 px, centre x=27, vertically centred.
- **Active app name** at x=48: 13 px Medium, `text-2` (#B8BEC8).
- When no window is focused it reads **"Desktop"**. Seen values: "Desktop", "Terminal", "Settings", "Files", "Notepad", "Snip", "Task Manager", "Calculator", "Steam", "⟦Velotic Store⟧", "Krita".
- For Windows-Engine apps it shows **"Windows app"** [W 3:12].
- It shows the app name, not the window title (older [2] showed titles such as "Adobe Photoshop 2026").
- Clicking the logo opens Start (assumed; not shown).

**Right side**, right-to-left from 16 px padding, all 13 px Medium `text-1`/`text-2`, glyphs 15 px, gap 14 px:
1. **Time** "03:32" (24 h, `HH:mm`).
2. 12 px gap, then the **date** "Tue 24 Nov" (format `ddd d MMM`, en-GB).
3. **Battery** glyph (outline battery with a charging bolt when on AC) + "100%". Hidden when there is no battery.
4. Volume speaker glyph. When muted it is a speaker with a small "×".
5. Wi-Fi (3 arcs) or wired (monitor glyph) for network.
6. Bluetooth glyph (when on; [W] shows it in the CC-open zoom).
7. Focus bell (only when Focus/DND is on).
8. ⚡ **bolt glyph**, always present in [W] and [T]. Its meaning is not stated; treat it as the power-profile / performance indicator.
9. **Windows Engine indicator** [W 3:04–3:30]: a small pink/accent Windows-style glyph with a count "1", shown while Windows apps run.
10. **"Gaming" pill** [T 1:04, 3:05], see 3.1.1.
11. App tray (StatusNotifier) icons, for example Steam (white Steam logo on a grey circle, 16 px).

**Click targets**
- The cluster (Wi-Fi, speaker, battery) is one button. It opens the **Control Center**, and while the CC is open the cluster gets a lighter pill behind it (rgba(255,255,255,0.12), radius 8, 24 px tall, sampled #364654).
- The date/time is a second button that opens the **Calendar** (§6.3).

**Maximised windows:** the top bar stays and the window starts under it. The dock floats over the window ([W 3:45]: Files maximised reaches the bar, and the dock floats over a strip).

Older [2] behaviour:
- The top bar merges with maximised windows' titles, showing – ▢ ✕ and the Android ← ⌂.
- In [W] maximised windows keep their own title bar under the top bar. Use the [W] behaviour, but keep the Android back/home buttons in the window title bar (§10.2).

#### 3.1.1 Gaming pill [T 1:04, 3:05]

- **Shape:** capsule **77×23 px**, fill **#F07A63** (solid, no glass), radius 11.5.
- **Content:** a gamepad glyph (filled, 14 px, colour #1A0E0C), a 5 px gap, then **"Gaming"** in 13 px Semibold **dark text #1A0E0C**.
- **Spacing:** 8 px from its neighbours.
- **State:** only the ON state was shown. For OFF, use the same pill with fill rgba(255,255,255,0.10) and `text-1` (design decision).
- **Click:** toggles Gaming mode, with no dialog or OSD in the video. Suggested backend: gamemode + power-profiles "performance" + pause Baloo and indexers + disable blur.
- **Visibility:** the pill is shown when Steam is running or Gaming mode is on. It is absent in the desktop footage without Steam [T 4:17+].

#### 3.1.2 Top-bar hover strip in full screen [W 4:08–4:12]

When an app is full screen, the top bar and dock are hidden. Moving the pointer to the top edge reveals a dark strip (28 px, `glass-dark`) with:
- macOS-style traffic lights at the left (12 px circles, #FF5F57 / #FEBC2E / #28C840, gap 8)
- a centred title ("Files")
- a small green pill button to exit full screen (label probably "Exit Full Screen", not legible).

Leaving the strip hides it again.

### 3.2 Dock

Reference frames: `WvjW_00m04.5s_start_open_unzoomed.png`, zoom `me_dock_x4.png`, `WvjW_03m45.5s_dock_context_menu.png`, `WvjW_03m08.0s_dock_tooltip_notepad.png`, `WvjW_04m34.0s_dock_tooltip_files.png`.

**Geometry** [W 0:04, frame 505–775 × 569–594]:
- Floating, horizontally centred. Size = content width; with 9 items it is **506×47 px**.
- Bottom gap **17 px**. Radius 14.
- Fill `glass-dark-light`, sampled #2A5762 over wallpaper #4E97A8. 1 px rim rgba(255,255,255,0.12).
- Windows never cover it.

**Items:**
- Item pitch **50 px**. Icon **28 px** (squircle app icons) or 18 px line glyphs (Search, Task View).
- First item centre 26 px from the dock's left edge.
- No separators between pinned items.

**Order [W]** (newest; also [T] 1:04):

| # | Item | Icon (see §3.3) | Click |
|---|---|---|---|
| 1 | **Start** | ⟦LOGO⟧ 26 px | toggles the Start menu; gets a 40×40 hover/active tile while Start is open |
| 2 | **Search** | white magnifier line glyph | opens the **Command bar** (§5); tooltip "Search" |
| 3 | **Task View** | two stacked rounded rectangles (outline, back one offset up-right) | KWin Overview / Task View (§7); tooltip "Task View" |
| 4 | Files | pink folder squircle | |
| 5 | Notepad | amber notepad squircle | |
| 6 | Calculator | dark keypad squircle | |
| 7 | Task Manager | maroon chart squircle | |
| 8 | Settings | grey gear squircle | |
| 9 | Google Chrome | (third-party icon) | pinned by default in [W] and [T] |
| — | running, unpinned apps | appended after Chrome with an extra 8 px gap | e.g. Windows Notepad (icon with a small blue badge), Snip, Terminal, Paint, Steam |

- In [W] a darker 20×30 px empty rounded slot sits at the dock's right end after Chrome. It reserves space for running apps.
- [T 4:17] showed a shorter pin set (Files, Task Manager, Settings, Notepad). The [W] order above is normative.

**States:**
- Hover: a 40×40 tile rgba(255,255,255,0.10), radius 10, behind the icon, plus a tooltip.
- **Running, unfocused:** a white dot, 4 px, centred, 3 px above the dock's bottom edge.
- **Focused:** a short **accent bar 12×3 px** (radius 1.5) in place of the dot [W 0:45 under Settings, T 4:50].
- Pressed: tile rgba(255,255,255,0.16).

**Tooltip** [W 3:08, 4:34; T 1:09]: a dark rounded label (`glass-dark`, radius 6, padding 6×10, 12 px `text-1`, 1 px rim). It sits 10 px above the dock, centred on the icon, and appears after about 400 ms with a 100 ms fade.

**Right-click menu** [W 3:45.5]:
- Positioned above the icon, about 242×186 px, `glass-dark`, radius 10.
- Items:
  1. Header: app icon (16) + **app name** in Semibold ("Calculator")
  2. `Unpin from taskbar` (pin-off icon); for unpinned apps, `Pin to taskbar`
  3. `Uninstall` (trash icon)
  4. `Keep on top` (no icon; toggles KWin keep-above with a check when on)
  5. `Close window` (× icon)

**Behaviour:**
- **Win+1…9** activates or launches the dock app at that position, counting app items only (Win+1 = Files…; shown with Calculator, Files, Notepad) [W 3:55].
- Minimise animates with a genie effect into the app's icon [W 2:55, 4:30].
- **Launch:** no launch animation was captured. Show the focused bar immediately.
- **Auto-hide** (Settings option): slides down in 90 ms when a window touches it or when hidden. It returns with a 100 ms ease-out slide-up when the pointer reaches the bottom 2 px.

**Notification button (older [2] only):** a separate 34×34 rounded-square glass button at the bottom-right with a bell, plus a red count badge. It is **not present** in [W] (notifications live in the CC), so do not build it.

### 3.3 Icon artwork (draw equivalents)

All are squircles with a vertical gradient (top lighter), a white glyph with a 1 px shadow, a soft top highlight and a 1 px inner rim rgba(255,255,255,0.18). Sizes: 28 px in the dock, 40 px in Start, 60 px in the All-apps grid.

| App (label) | Squircle colours (top→bottom) | Glyph |
|---|---|---|
| Files | magenta-pink #EC5C8E → #B8174D | a lighter pink (#F7A8C4) folder with a tab, filling about 60% |
| Notepad | amber #FBC56A → #E8922E | a cream (#FFF3D6) page with 4 faint horizontal lines and a top binding band |
| Calculator | slate #545A66 → #2C3038 | a white display bar at the top, a 3×3 grid of grey (#8D93A0) keys, and an **orange (#F08A3C) tall key** bottom-right |
| Settings | grey #6B707C → #3E424C | a white 8-tooth gear with a **pink/crimson (#E0245E) centre dot** |
| Task Manager | maroon #8A2545 → #4A2A36 | a white rising zig-zag line chart |
| Android apps | green #4BE08F → #1E9E58 | a dark-green phone outline containing a 2×3 grid of light-green tiles |
| Terminal | charcoal #3A3D45 → #1E2026 | white ">_" prompt (the ">" can be tinted cyan #7DE3E8) |
| Snip | pink #F57AA6 → #D6336C | white corner-bracket viewfinder frame with a lighter pink fill inside |
| Drivers | orange #F9A64B → #D8731E | a cream microchip with pins on all 4 sides |
| Welcome | peach #F9B8A8 → #F08C8C | a sunset: a yellow-orange half sun over 3 pink horizontal wave lines |
| ⟦Velotic Store⟧ | purple #8B5CF6 → #5B21B6 | a shopping bag with a white "V". **Brand: replace** with a bag and a "T" |
| Activity Monitor, Disks, File Roller, Media Player, Network Monitor, PDF Reader, Photos, Ping Monitor, Process Rules [T all-apps] | same squircle style, each with its own hue | pulse line, disk platter, zipper box, play triangle, network graph, document with a red band, photo/mountain, radar arcs, sliders. Glyphs are partly illegible at source; use matching metaphors |

Settings category icons [W 4:57] are 28 px dark rounded squares (#2A2C33, radius 7) with a coloured glyph:

| Category | Glyph and colour |
|---|---|
| System | grey laptop |
| Bluetooth & devices | blue (#4C8DF6) bluetooth rune |
| Network & internet | cyan (#4FC3E8) Wi-Fi |
| Personalisation | pink (#F06292) paint palette |
| Apps | orange (#F5A142) 2×2 rounded squares |
| Accounts | grey-blue person |
| Time & language | green (#3DDC84) clock in a filled circle |
| App support | teal-green (#2BC48A) stacked windows |
| Update & drivers | crimson (#E0245E) circular refresh arrows |

Older [2] build: all nav icons were crimson tiles. The [W] look above is normative.

### 3.4 Taskbar mode [W 4:51–4:57]

Chosen in Settings › Personalisation › "Dock and taskbar" › **Taskbar**. Switching is live and instant.
- The **top bar is removed**.
- A full-width bottom bar appears: **43 px** high, `glass-dark-light`, no margin, no radius, with a 1 px top rim.
- **Centre:** the same items as the dock, in the same order and pitch.
- **Right side**, from the right with 12 px padding: a bell glyph (notifications), then a **two-line clock**, right-aligned in 12 px: "04:20" over "11/24/2026" (`M/d/yyyy`). Before the clock: ⚡, a brightness/monitor glyph, Wi-Fi, speaker and battery, at 14 px with a 14 px gap.
- The left side is empty.
- "Auto-hide the dock" becomes disabled, with the subtitle "Only for the dock look".

---

## 4. Start menu

Reference frames:
- `WvjW_00m04.5s_start_open_unzoomed.png` (geometry)
- `WvjW_00m19.5s_start_pinned.png`
- answers: `WvjW_00m22.0s_start_units.png`, `WvjW_00m26.0s_start_currency.png`, `WvjW_00m30.0s_start_maths_final.png`, `WvjW_00m20.5s_start_websearch.png`
- [T] `TrNP_04m18.5s_start_menu.png`

### 4.1 Panel

- **Size 640×628 px**, centred horizontally (x 640–1280), bottom edge **22 px above the dock top** (y≈374–1002).
- `glass-dark` (sampled #0E2533 over a #318599 wallpaper), radius 16, 1 px rim.
- Opens with the `pop` animation; closes with Esc, a click outside or the Start button.
- Keyboard: **Super** toggles it (assumed). Typing immediately goes to search.

### 4.2 Contents (top → bottom, 28 px side padding)

**Search field**
- **594×43 px**, 16 px from the panel top. Fill rgba(255,255,255,0.08) (#252E39), radius 8.
- **1 px accent border when focused** (it is focused on open). Magnifier glyph 16 px at the left (14 px inset).
- Placeholder **"Search apps, files and the web"** (13 px `text-3`).

**Pinned header row** (y +28 below the field)
- **"Pinned"** in 13 px Semibold.
- At the right, a chip **"All apps ›"**: 84×26, fill rgba(255,255,255,0.12), radius 13, 12 px Medium. It opens the All-apps grid (§7.2).

**Grid**
- 6 columns, column pitch **99 px**, row pitch **97 px**. Icon 40 px, label 12 px `text-1` 8 px below the icon, centred, single line with an ellipsis.
- Order [W] (identical in [T] except the Store):
  - Row 1: **Files, Notepad, Calculator, Settings, Task Manager, Android apps**
  - Row 2: **Terminal, Snip, Drivers, Welcome**
- [T] row 1 was Files, ⟦Velotic Store⟧, Notepad, Settings, Task Manager, Android apps. The newest [W] has no Store pinned.
- Hover: a 72×72 tile rgba(255,255,255,0.08), radius 8. Right-click: Unpin from Start / Pin to taskbar (assumed).

**Recommended**
- **"Recommended"** in 13 px Semibold.
- Empty state, centred: **"Files you open will show up here."** (12 px `text-2`).
- When filled, use rows: file icon 32 + name 13 px + "Today, 09:12"-style 11 px subtitle, in a 2-column list. The filled state is not shown in the newest video.

**Footer**
- 56 px high, separated from the body by a 1 px rgba(255,255,255,0.06) line. The fill is the same glass plus about 3% black.
- Left (28 px in): avatar circle 28 px (initial letter, grey #5A606B fill) + user name 13 px Semibold ("Alex Kim" [T]; "Test User" [2]; blurred in [W]).
- Right (28 px in): power glyph 16 px in a 32×32 hover tile. Click opens the power menu (not shown). Use a `glass-dark` menu with `Lock`, `Sign out`, `Sleep`, `Restart`, `Shut down` (design decision, same as the Win+X "Turn off or sign out ›" submenu).

### 4.3 Search results (typing in Start) [W 0:18–0:30], [2 0:32, 2:13]

- The Pinned and Recommended sections are replaced by **"Best matches"** (13 px Semibold).
- Result rows: 594×56, radius 8, gap 4.
  - Icon tile 36 px: the app icon, or for an answer a dark tile #2A2D35 with an accent glyph.
  - Title: 14 px Semibold.
  - Subtitle: 12 px `text-2`.
  - The **selected row** (the first) is filled `accent-soft` and shows an **↵** glyph at the right (16 px, `text-2`).
- Results update as you type. **Enter** activates; for answers Enter **copies** the value to the clipboard.

**Exact rows:**

| Query | Title | Subtitle | Icon |
|---|---|---|---|
| "5 ft i" | `Search the web for "5 ft i"` | `Search the web` | globe |
| "5 ft in cm" | `152.4 cm` | `5 ft = · Enter to copy` | ⇄ (unit) |
| "40 usd to e" | `Search the web for "40 usd to e"` | `Search the web` | globe |
| "40 usd to eur" | `36.57 EUR` | `40.00 USD = · rate of 2026-11-23 · Enter to copy` | ⇄ / currency |
| "2450*0.18" | `441` | `2450*0.18 = · Enter to copy` | calculator |
| "calc" [2] | `Calculator` | `Standard, scientific and programmer calculator, date calculation and unit converters` | app icon |
| "paint" [2] | `Paint.NET` | `Windows app (runs in the Windows Engine)` | app icon |
| any [2] | `Search the web for "calc"` | `Search the web` | globe (always the last row) |

Backends: KRunner runners for apps, calculator (Qalculate), unit converter and currency (ECB rate date shown), plus web shortcuts.

---

## 5. Command bar (Super+Space)

Reference frames: `WvjW_00m31.5s_cmdbar.png`, `WvjW_00m33.0s_cmdbar_top.png`, `zoom\WvjW_cmdbar_montage*.png`.

- **Panel:** **644 px wide**, top edge at y≈225, centred horizontally. Height fits the content (about 497 px with 8 rows). `glass-dark`, radius 16. Opens with `pop`; Esc closes.
- **Field** (full width minus 12 px, 48 px high):
  - magnifier icon
  - placeholder **"Search apps, settings and the web"** (14 px)
  - a **key chip "Enter"** at the right: 11 px text, rgba(255,255,255,0.10) fill, radius 5, padding 2×6.
- **Result rows** (52 px): icon 32, title 14 px Semibold, subtitle 12 px `text-2`. The selected row is `accent-soft`. With no query, the rows show suggested apps. Exact strings seen:
  - `Disks` / `Manage Drives and Media`
  - `Contacts`
  - `Alacritty` / `Terminal (on ⟦flowos⟧-debian)`. This is a distrobox-exported app; the container name contains the brand.
  - `Calculator` / `Standard, scientific and programmer calculator, date calculation and unit converters`
  - `Android apps` / `Run Android apps on ⟦FlowOS⟧: set up Android, Google Play, install .apk files`
- **">" prefix = run command:** typing `>top` shows a single row: accent `</>` icon tile, `top` / `Run in terminal`, ↵. Enter opens Terminal running the command [W 0:34–0:39].
- Searches settings too (Settings pages are results).

---

## 6. Control Center, calendar, notifications, OSD

### 6.1 Control Center (Super+A)

Reference frames: `WvjW_05m26.0s_control_center.png`, `WvjW_05m28.0s_control_center_focus_on.png`, `WvjW_05m34.0s_control_center_notifications.png`, `WvjW_05m42.6s_cc_group_expanded_showless.png`; light: [T] `TrNP_04m30.6s_control_center_light_full.png`. [W] is zoomed 1.5×; the values below are converted.

**Panel**
- **344 px wide**, anchored top-right: 10 px under the top bar (y=38), 12 px from the right edge (x 1564–1908).
- Height fits the content (about 540 px without notifications, growing to the screen height minus margins, then scrolling).
- `glass-dark` (sampled #041524), radius 16, padding 12, gap 11 between blocks.
- Opens from the top-bar status cluster with `pop`. Click outside or Esc closes.

**Contents, in order:**

1. **Toggle block** (2 columns, 155 px each, gap 11):
   - **Left tall tile** (155×150, `glass-tile`, radius 14) holds two stacked toggles:
     - **Wi-Fi** / SSID (or "Ethernet" when wired; older: "Network")
     - **Bluetooth** / "On" (or "Not available": grey circle with a slashed BT glyph)
   - **Right column**, two tiles (155×70 each):
     - **Dark mode** / "On"|"Off" (half-filled-circle glyph)
     - **Focus** / "Off"|"Do not disturb" (bell glyph)
   - Each toggle: a **34 px circle** (ON = accent fill #F47D67 with a dark glyph #2A0F0A; OFF = rgba(255,255,255,0.14) with a white glyph), then a 10 px gap, then the title (13 px Semibold) and the status (11.5 px `text-2`).
   - Clicking the circle toggles. Clicking the label opens details (assumed).
2. **Display card** (322×75, `glass-tile`, radius 14):
   - "Display" (13 px Semibold) at the left, value "30%" at the right (12 px `text-2`).
   - Slider: track 300×28, rgba(255,255,255,0.10), fully rounded. The fill is **white #ECEBEE** with a **sun glyph** inside the fill's left end (dark grey). There is no separate knob; drag anywhere.
   - Hidden when there is no backlight.
3. **Sound card**: same layout. The value is "52%" or **"Muted"**. The speaker glyph sits inside the fill (a speaker with × when muted).
4. **Button row**: 4 square buttons, 72×69, gap 11, `glass-tile`, radius 14. Each has an 18 px glyph above a 12 px label:
   - **Snip** (dashed/viewfinder frame) → Snip overlay
   - **Settings** (gear)
   - **Lock** (padlock)
   - **Power** (power) → power menu
5. **Desktops card** (322×57): "Desktops" at the left. At the right a "+" adds a virtual desktop.
   - [W] shows only "+" with one desktop. Older [2] showed numbered chips **1 2 3 4** (23×21 → 34×30, radius 6, active = accent fill).
   - Build: number chips for the existing desktops followed by "+".
6. **Notifications section** (only when there are any):
   - Header "Notifications" (14 px Semibold) and **"Clear all"** (13 px, `text-1`, right).
   - Group header in 12 px `text-2` (e.g. "Other notifications", "Reminders") with "Show all 3" / "Show less" and a "×" at the right. Grouped by app.
   - Cards: 322×56, rgba(255,255,255,0.08), radius 10, with an icon tile 28 and title 13 px Semibold over body 12 px `text-2`. Hover shows a "×" at the top-right.
   - Collapsed groups show the newest card plus a peeking stacked card edge.
   - **Swipe right** (drag) dismisses: the card follows the pointer, then slides out and fades over 400 ms, and the group count updates.
   - Examples: "Team meeting / Starts in 10 minutes"; "Call Sam / About the weekend plans"; "Lunch at 1 / Table for two booked"; [T] "Calendar / Team sync in 10 minutes".
7. **Battery card** (322×50): battery glyph + "Battery" (13 px Semibold) at the left; at the right "100% · fully charged" (12 px `text-2`). Only on battery devices.

**Focus on** silences banners; notifications collect in the CC, and a bell appears in the top bar.

**Dark mode toggle** switches the global look (top bar, dock, panels, apps and wallpaper day/night) at once. Shell surfaces switch in 1 frame and the wallpaper crossfades over 450 ms [T 4:29.4].

**Light variant** [T 4:30]:
- Panel rgba(246,247,250,0.80); tiles white at 70%; text #15171C, secondary #5D636E.
- OFF circles #D9DCE1; slider fill white with a grey track #C9CDD3.

### 6.2 Notification banner ("island")

Reference frames: `WvjW_05m36.8s_notification_banner.png`, [T] `TrNP_04m35.5s_notification.png`, [2] `2uwx_00m54.5s_island.png`.

**Geometry**
- **437×80 px**, horizontally centred, top at **y=6**: it overlaps the top bar.
- `glass-dark` with a slight indigo tint (rgba(14,18,36,0.80)), radius 18, 1 px rim rgba(255,255,255,0.14).

**Content** (padding 14)
- Left: an icon tile 36×36 (radius 10, rgba(255,255,255,0.10)) holding the app icon or a bell glyph.
- Text column, 12 px left of the tile:
  - line 1: "Reminders · now" (11.5 px `text-2`, app name · relative time)
  - line 2: **"Call Sam"** (14 px Semibold)
  - line 3: "About the weekend plans" (12.5 px `text-2`)
- Stack badge at the top-right: **"+2"** (11 px Semibold, pill rgba(255,255,255,0.16), 22×16).

**Motion**
- Enters with `island` (expands horizontally from the centre, 0.6→1.0 width, fade and blur-clear, about 4% overshoot, about 300 ms).
- Auto-dismisses after about 5 s with a reverse 200 ms shrink and fade.
- Click opens the app. Hover pauses the timeout.

Other strings seen:
- "Calendar · now / Calendar / Team sync in 10 minutes" [T]
- "Calendar · now / Team sync in 10 minutes / Design review, Room 2" [2]
- "⟦Velotic Store⟧ · now / Spotify is ready / Installed in 42 seconds" (older)

### 6.3 OSD pill (system feedback) [W 2:53]

- Same component as the banner, compact: about **450×65 px**, top-centre, overlapping the top bar.
- Icon tile (image glyph) + title "Background changed" (14 px Semibold) + subtitle "Aurora.jpg" (12 px `text-2`).
- `island` motion (from about 0.6 scale, about 200 ms ease-out). Auto-hides after 2.5 s.

Also used for the Android game-controls toast (§10.3).

### 6.4 Calendar popover (click the date/time) [W 5:47–5:56]

Reference frames: `WvjW_05m47.5s_calendar_popover.png`, `WvjW_05m51.0s_calendar_december_today.png`.

- **Panel:** **295×309 px**, top-right under the clock (right margin 12, top 38). `glass-dark`, radius 16, padding 14. Opens with `pop`.
- **Header:** **"Tuesday 24 November 2026"** (15 px Semibold, `dddd d MMMM yyyy`).
- **Month row:** "November 2026" (13 px Semibold) with **up/down chevrons** ^ ˅ at the right (not ‹ ›).
  - When you navigate away from the current month, a **"Today"** text button appears between the label and the arrows; it jumps back.
- **Weekday row:** **"Su Mo Tu We Th Fr Sa"** (11 px `text-3`). The week starts on **Sunday** as shown; follow the locale.
- **Day grid:** 7×6 with 36 px cells, 12.5 px numbers. Days outside the month are dimmed to 35%. **Today = filled accent circle 28 px with dark text.** Hover is a 28 px circle at rgba(255,255,255,0.10).

### 6.5 Clipboard history and emoji panel (Win+V / Win+.) [W 0:54–1:09]

Reference frames: `WvjW_00m58.0s_clipboard_panel_full.png`, `WvjW_01m04.0s_emoji_panel.png`.

**Panel:** about 360×460 px, flush bottom-right, 12 px from the right and bottom (above the dock level). `glass-dark`, radius 16. Slides in from the bottom (`slide-panel`).

**Tabs:** a segmented control at the top with **"Emoji"** (smiley icon) and **"Clipboard"** (clipboard icon). The active tab is a lighter pill (rgba(255,255,255,0.10)) with an **accent underline bar** 16×2.

**Clipboard tab**
- Header **"Clipboard history"** (14 px Semibold) and a **"Clear all"** chip.
- Item cards: full width, radius 10, rgba(255,255,255,0.07), padding 12, text 13 px. **Pin** and **delete** icons sit at the right of each card.
- The **selected/keyboard-focused** card has a 1.5 px accent outline.
- Clicking pastes into the focused app.
- Footer hint (partly cut off): "Click to copy, then paste with Ctrl+V" (?).

**Emoji tab**
- **"Search emoji"** field with an accent underline when focused.
- Category icon row: recent, smileys, animals, food, travel, activity, objects, symbols, flags. The active category is accent.
- Section title "Smileys & people".
- **8-column** Noto Color Emoji grid, 36 px cells. Click inserts the emoji.

---

## 7. Task View, virtual desktops, All-apps grid, Win+X

### 7.1 Task View [W 4:26–4:29]

Reference frame: `WvjW_04m27.5s_task_view.png`.

- Opened from the dock **Task View** button.
- The backdrop is the wallpaper, blurred and darkened 40%. The current desktop scales to about 80% (frame 222–1061 × 125–596 → 1572×884 at 1080p, centred, slightly low). The top bar and dock are hidden.
- **Top strip:** desktop thumbnails, about 200×112 each, radius 10, labelled below in 12 px: "Desktop 1", "Desktop 2". The active one has a **2 px accent border**. A "+" tile of the same size adds a desktop.
- A **"Search…"** field (240×32) sits centred under the strip.
- Enter animation: scale-down and strip fade, about 200 ms ease-out.
- This maps to KWin Overview with its desktop bar.

**Desktop switching:** Ctrl+Super+←/→ (assumed). A horizontal slide over 300 ms; the top bar and dock stay [W 4:20].

### 7.2 All-apps grid ("Every app, in one view") [T 4:39–4:44]

Reference frames: [T] `TrNP_04m41.5s_allapps_grid.png`, `zoom\TrNP_04m41.5s_allapps_x3.png`.

- **Full-screen** overlay, opened from Start's "All apps ›" (or a Launchpad shortcut).
- **Background:** near-black #0F1318 with a soft vignette (or the blurred wallpaper at 30% brightness). **The top bar and dock are hidden.**
- **Search pill:** top-centre, **281×32 px**, top y≈73. rgba(255,255,255,0.08), radius 16, placeholder **"Search"**, centred magnifier. Typing filters the grid live.
- **Grid:** **7 columns**. Icon **60 px**, label 12.5 px white, centred, 10 px below the icon. Column pitch **149 px**, row pitch **137 px**. First row top y≈160, grid horizontally centred. Alphabetical. No page dots (paging appears only when needed).
- **Apps in the Recommended install [T]**:
  - Row 1: Activity Monitor, Android apps, Calculator, Disks, Drivers, File Roller, Files
  - Row 2: Media Player, Network Monitor, Notepad, PDF Reader, Photos, Ping Monitor, Process Rules
  - Row 3: Settings, Snip, Task Manager, Terminal, ⟦Velotic Store⟧, Welcome
- **Open:** blurred crossfade, about 150 ms. Esc or a click on empty space closes.
- Older [2]: an 11×5 Launchpad over the blurred wallpaper with a crimson-outlined search pill, page dots (6 px white active / grey) and 48 px icons. It is superseded by the layout above.

### 7.3 Win+X quick menu [W 4:13–4:19]

Reference frame: `WvjW_04m14.0s_winx_menu.png`.

- **Panel:** **252×513 px**, centred horizontally just above the dock. `glass-dark`, radius 12, item height 32, 13 px text, no icons, hover row rgba(255,255,255,0.08).
- **Items**, with `|` marking separators:
  `Installed apps`, `Power options`, `System`, `Drivers`, `Network connections`, `Disk management`, `Terminal` | `Task Manager`, `Settings`, `File Explorer`, `Search` | `Turn off or sign out ›` | `Desktop`.
- "Desktop" shows the desktop (minimise all).

---

## 8. Settings app

Reference frames: `WvjW_00m45.0s_settings_mouse_touchpad.png`, `WvjW_00m42.0s_settings_search_results.png`, `WvjW_04m57.0s_personalisation_dock_mode.png`, `WvjW_04m52.0s_personalisation_taskbar_mode.png`, `WvjW_06m01.0s_colours_peach_hover.png`, `WvjW_06m09.0s_colours_coral_current.png`; [T] `TrNP_04m50.5s_files_settings_snap.png`, `TrNP_04m56.0s_settings_toast.png`; [2] `2uwx_03m45.5s_settings-keymapping.png`.

### 8.1 Window

**Size and chrome**
- Default **1091×759 px**, centred.
- Window chrome as in §9.1: title "Settings" with a small grey shield/gear icon.
- Background `window-bg` #0E1018; the sidebar has the same colour (no divider).

**Sidebar** (311 px wide, padding 12)
- **User block:** avatar circle 56 px, name 15 px Semibold, and "Local account · Administrator" (12 px `text-2`). The name is blurred in [W]; [T] shows "Alex Kim".
- **Search field "Find a setting"** (278×30, `field`, radius 6, magnifier at the right). Focused: 1 px accent border.
- **Nav list:** item height 40, radius 6. Icon tile 28 (see §3.3), label 13 px.
  - Selected: fill #23242D, a **3×16 px accent bar** at the left edge, label Semibold.
  - Hover: rgba(255,255,255,0.05).
- **Nav items [W]:** `System`, `Bluetooth & devices`, `Network & internet`, `Personalisation`, `Apps`, `Accounts`, `Time & language`, `App support`, `Update & drivers`.
  - Older [2] named "App support" as "Windows programs & Android".

**Content area**
- Left padding 32, top 24.
- Page title: **breadcrumb** at 28 px Semibold, e.g. "Bluetooth & devices › Mouse & touchpad" (parent `text-2`, "›" `text-3`, current `text-1`), or a single word ("Personalisation").
- Section headers: 13 px Semibold, 16 px above their group.
- **Setting row:** full width, **58 px**, `card` #151821, radius 8, 4 px gap between rows.
  - Inside: icon tile 30 (#22252D, radius 6, grey glyph), title 13 px, subtitle 11.5 px `text-2`.
  - The control sits at the right with 16 px padding.
  - Rows with a "›" chevron are navigation rows. Hover #1B1F28.
- **Controls:**
  - **Toggle:** 40×20 track with a 14 px knob. ON = accent track #F87F66 with a white knob. OFF = transparent track with a 1 px #6A6D76 border and a #9AA0AA knob. A 12 px label "On"/"Off" sits to the toggle's left.
  - **Slider:** 150 px track, 3 px #444A52, accent fill, 12 px accent knob with a 2 px darker ring.
  - **Dropdown:** 163×32, `field`, radius 6, 12.5 px text and a ˅ chevron.
  - **Button:** "Reset" 60×28, rgba(255,255,255,0.08), radius 6.
- **Search** ("mouse"): a dropdown under the field, as wide as the sidebar field plus about 40%. Each result row (44 px) has an icon, a title with the **matched characters in accent**, and a breadcrumb subtitle (11.5 px `text-2`). Enter or click opens the page and highlights the row.
  - Results for "mouse", in order: Mouse & touchpad (Bluetooth & devices › Mouse & touchpad); Key mapping (Apps › Key mapping); Bluetooth (Bluetooth & devices); Mouse pointer speed; Primary mouse button; Scrolling speed; Reverse scrolling direction; Tap to click; Touchpad scrolling direction; Touchpad cursor speed (all Bluetooth & devices › Mouse & touchpad); Game controls (Apps › Key mapping); Mouse speed for aiming (Apps › Key mapping).

### 8.2 Pages shown

**Bluetooth & devices › Mouse & touchpad** [W 0:45]

| Section | Row title | Subtitle | Control |
|---|---|---|---|
| Mouse | Primary mouse button | The button that selects and opens things | dropdown `Left` |
| Mouse | Mouse pointer speed | — | slider |
| Mouse | Scrolling speed | How far the mouse wheel scrolls | slider |
| Mouse | Reverse scrolling direction | The page moves the way the wheel turns, like on a touchpad | toggle Off |
| Touchpad | Tap to click | Tap with one finger to click, two fingers to right-click | toggle **On** |
| Touchpad | Cursor speed | — | slider |
| Touchpad | Scrolling direction | Scroll with two fingers | dropdown `Down motion scrolls down` |
| Touchpad | Scrolling speed | — | slider |
| Related | (links) | | |

**Personalisation** [W 4:51–4:57]
- **Top area:** a live preview thumbnail (220×134, radius 8) showing the wallpaper with a mini window and a mini dock. To its right, "**Select a mode to apply**" (13 px Semibold) with 3 thumbnails, 120×74 each:
  - **Light**
  - **Dark** (selected: 2 px accent border, label Semibold)
  - **Auto (sunset)**
- **Rows:**
  - `Background` / `⟦FlowOS⟧ wallpaper: ⟦FlowOS⟧ Tide` ›
  - `Colours` / `Dark mode, Coral accent` ›
- **"Dock and taskbar"** section:
  - Two picture cards, 172×128, radius 8. The thumbnail is a crimson gradient (#7A0F35→#C21E55) with a white window mock and a pink dock (or full-width taskbar dots). The label sits below in 12 px.
  - Cards: **"Dock and top bar"** and **"Taskbar"**. Selected = 1.5 px accent-border plus a lighter fill.
- **More rows:**
  - `Auto-hide the dock` / `It comes back when you point at the bottom of the screen`, toggle Off. In Taskbar mode it is disabled with the subtitle `Only for the dock look`.
  - `Taskbar pins` / `Put back the apps the taskbar started with. Your apps stay installed.`, button `Reset`.

**Personalisation › Colours** [W 0:42, 6:01–6:09]
- `Choose your mode` / `Changes the colours of ⟦FlowOS⟧ and your apps`, dropdown `Dark` (Light / Dark / Auto (sunset)).
- `Accent colour` / `Coral. Used for buttons, switches, selection and focus.`, a 20 px swatch chip and ^ (expanded).
- The expanded area is titled **"⟦FlowOS⟧ colours"**: swatches in a 6 + 5 layout, 40 px rounded squares (radius 10), gap 12. The current one has a 2 px white ring and a ✓.
  - Under the swatches a hint reads **"Coral (current)"**. Hovering another swatch changes it to "Peach. Click to use it." / "Teal. Click to use it." / "Violet. Click to use it."
  - **Hovering live-previews** the accent in the header chip and the preview thumbnail; clicking applies it system-wide.
- Then a **"Preview"** thumbnail, and "Related": `Background` / `Wallpaper for your desktop`, `Night light` / `Warmer screen colours in the evening`.

**Personalisation › Background** [T 4:50–5:00]
- Preview thumbnail.
- Expandable card: image icon, **"Choose a picture"** / **"⟦FlowOS⟧ wallpapers. Dark mode uses the night version where there is one."** with ^.
- Grid of **14** thumbnails, 3 or 4 columns, 16:9, radius 8, gap 10. Selected = 2 px accent border.
- Clicking crossfades the wallpaper (400 ms) and shows an in-window toast at the bottom-centre: a dark pill 203×39, green check-circle glyph + **"Background changed"**, `toast-up` motion, 2 s.

**Apps › Key mapping** [2 3:43–3:50] (older build, but the only source)
- Rows:
  - `Game controls` / `Play Android games with your keyboard and mouse` (On)
  - `Turn on when a game opens` / `Controls start by themselves for games that have them` (On)
  - `Show keys on the game` / `Small labels over the game's buttons while you play` (On)
  - `Mouse speed for aiming` / `How far the view turns when you move the mouse` (slider)
- Section **"How to play"**:
  - `Turn controls on or off` / `Win+G, or F12 while you play`
  - `Use the mouse in menus` / `Alt frees the mouse; press Alt again to aim`
  - `Change a game's controls` / `Open the game, then press Win+Shift+G. Drag buttons onto the game and press a key for each.`
- Section **"Games"**: `Free Fire MAX` / `⟦FlowOS⟧ layout`.

**System** (only in excluded 4Tyj; build to the same pattern): device thumbnail + name + "Rename" link; "Update & drivers / Not checked yet"; rows Display, Sound, Notifications, Power & battery, Storage, About.

Pages not shown (Network, Accounts, Time & language, App support, Update & drivers): build with the same row components.

---

## 9. Window chrome and built-in apps

### 9.1 Window decoration (all native apps) [W]

**Title bar**
- **28 px**, the **same colour as the window body** (#0D1019), no contrast band.
- Left: app icon 14 px at x=10, then the title 12 px `text-2` ("Settings", "Untitled - Notepad", "Terminal", "Home").
- Right: **one grouped pill** holding **– ▢ ×**.
  - Pill: **94×22 px** at 8 px from the right, fill #22252D, radius 6, with thin dividers rgba(255,255,255,0.06).
  - Glyphs: 10 px, 1.2 px stroke, `text-2`. The maximise glyph is a rounded square.
  - Hover: segment rgba(255,255,255,0.08); close hover #C42B1C with white glyph.
- Double-click maximises.

**Window body**
- Radius 12; shadow as in §0.3.
- Inactive window: title text `text-3`.

**Snapping**
- Drag to an edge for half-screen. Super+←/→ (Windows-style).
- Snapping is **instant** (no animation) [T 4:45.8].
- Maximised windows sit under the top bar and keep the dock floating on top.

**Light mode:** body #F7F7F9, title bar same, pill #E6E7EB.

Older [2]: light title bars #F5F3EF on dark bodies. Superseded.

Windows-Engine apps keep their own Windows 11 caption buttons (no host decoration). Mac apps: §10.4.

### 9.2 Files [W 1:54–2:56], [T 4:45]

Reference frames: `WvjW_02m03.0s_files_home.png`, `WvjW_01m56.5s_quicklook.png`, `WvjW_02m19.0s_files_undo_toast.png`, `WvjW_02m22.5s_trash_context_menu.png`, `WvjW_02m24.5s_trash_empty.png`, `WvjW_02m28.6s_files_multiselect_menu.png`, `WvjW_02m33.6s_zip_context_menu.png`, `WvjW_02m40.0s_pinned_drop_target.png`, `WvjW_02m44.5s_details_folder.png`, `WvjW_02m47.0s_details_notes.png`, `WvjW_02m51.5s_image_context_menu.png`; [T] `TrNP_04m47.5s_files_snapped.png`.

- **Default size** 1178×768.
- **Tab strip** (36 px, under the 28 px title bar):
  - Tabs 160 px wide max, radius 8 at the top. Each has a folder/house icon, a name and a ×.
  - The active tab is lighter (#1B1F28). A "+" button follows.
  - Tabs can be dragged to reorder; middle-click closes.
- **Navigation row** (40 px):
  - ← → ↑ ⟳ (32 px icon buttons)
  - Address/breadcrumb box (radius 6, `field`): "⌂ Home" or "My files › Documents"
  - Search box 240 px at the right: "Search My files" / "Search Documents" / "Search the Trash"
- **Command bar** (40 px):
  - **"+ New ˅"** (the "+" in accent)
  - Icon buttons: cut, copy, paste, rename, share, delete
  - Divider
  - "⇅ Sort ˅", "View ˅", "···"
  - At the far right, a **"Details"** toggle with a panel icon. When on, its fill is `accent-soft` and its text accent.
  - In the Trash: "⟲ Put back", "Delete for good", "Empty Trash", Sort, View.
- **Sidebar** (220 px):
  - "Home" (house icon)
  - **"Pinned"** section. It appears when you drag a folder over the sidebar; the drop target is a dashed accent-tinted box reading **"Drop a folder here to pin it"**.
  - **"Favourites"**: My files, Desktop, Documents, Downloads, Pictures, Music, Videos, with **pink folder icons** (Files icon style, 16 px).
  - **"Drives"**: "This computer" with a 4 px accent usage bar under it and "196 GB free of 476 GB" (11 px `text-2`).
  - **Trash**
  - Items: height 32, 13 px. **Selected = `accent-soft` fill + 3 px accent left bar**, radius 6.
  - Section headers: 11.5 px `text-3`.
- **Home page:**
  - Greeting **"Good morning, Alex"** (30 px Semibold; morning, afternoon or evening by time of day), with the date **"Tuesday 24 November"** under it (13 px `text-2`).
  - **"☆ Quick access"**: 7 cards, 4 per row, about 180×70, radius 8, `card`. Each has a 36 px pink folder icon with a white glyph, the name (13 px Semibold) and the subtitle "My files" (My files itself shows "Your own folder").
  - **"◷ Recent"**: a card containing "Files you open will show up here." (empty state).
  - **"Drives"**: a card with a 56 px **donut ring** (accent arc = used %), drive glyph, "This computer", "40.2 GB free of 63.0 GB", "36% used".
- **Status bar** (28 px, 12 px `text-2`):
  - Left: "7 items in Quick access" / "1 of 6 items selected · 202 bytes".
  - Right: "196 GB free of 476 GB" + an 80×4 accent mini-bar, then list/grid toggles (the active one accent-tinted).
- **File grid:** 96 px tiles, selected = `accent-soft` rounded tile. Folder icons are pink.
- **Context menus** (`glass-dark`, radius 10, row 32, icons 16, shortcut hints right-aligned 12 px `text-3`):
  - Multi-select: `Open 3 items` Enter · `Cut` Ctrl+X · `Copy` Ctrl+C · `Move to Trash` Delete · `Compress to ZIP` · `Copy paths` · `More actions ›` · `Properties` Alt+Enter
  - Zip: `Open` Enter · `Open with...` · `Cut` · `Copy` · `Rename` F2 · `Move to Trash` · `Extract here` · `Compress to ZIP` · `Copy path` · `More actions ›` · `Properties`
  - Image: `Open` · `Open with...` · **`Set as desktop background`** · `Cut` · `Copy` · `Rename` · `Move to Trash` · `Compress to ZIP` · `Copy path` · `More actions ›` · `Properties`. Setting a background shows the OSD pill "Background changed / Aurora.jpg".
  - Trash item: `Put back` · `Delete for good` (red #FF6B6B, Shift+Del) · `Properties` (Alt+Enter)
- **Trash empty state** (centred): trash icon 64 px, "The Trash is empty" (16 px Semibold), "Things you delete wait here until you empty it." (13 px `text-2`).
- **Undo toast** (bottom-right of the window, 320×60, `glass-dark`, radius 10): **"Undone"** (Semibold) / **"“old notes.txt” is back from the Trash"** with ×. Triggered by Ctrl+Z after a delete.
- **Details pane** (Alt+P, right, 300 px):
  - Large preview (a folder icon, or a monospace first-lines preview for text).
  - Name (16 px Semibold) and kind ("Folder" / "Text document").
  - Action icon row: open, share, rename, copy, delete, more.
  - Key/value list (12 px):
    - Folder: Contains "0 items", Modified "Today, 04:02", Created "Today, 04:02", Where "My files › Documents"
    - File: Size "124 bytes", Modified, Created, Opened, Where
- **Quick Look** (Space toggles):
  - A dark scrim (rgba(0,0,0,0.45)) with a centred card of about 1376×964 px, `glass-dark`, radius 16.
  - Header: **"Pebble.jpg"** (15 px Semibold) and **"JPEG image · 204 KB · Tuesday 24 November 2026 at 03:18"** (12 px `text-2`). At the right, an accent **[Open]** button (64×30) and ×.
  - The image is fitted below.
  - Open: a ghost file icon fades in at the centre, then the card scales from 0.96 with a fade, about 140 ms. Close: 100 ms fade.

### 9.3 Notepad [W 0:50–1:35]

Reference frames: `WvjW_00m51.0s_notepad_selection.png`, `WvjW_01m21.5s_notepad_f5_tabs.png`, `WvjW_01m28.0s_notepad_find_replace.png`.

- **Title bar:** "Untitled - Notepad" / "Trip plan.txt - Notepad".
- **Tab strip:** tabs 180 px max. The active tab is lighter with ×; inactive tabs have grey text and show a **●** (unsaved) instead of ×. A "+" follows.
- **Menu row:** `File` `Edit` `View` (13 px), with a gear icon at the right.
- **Editor:** monospace 14 px, `text-1` on `window-bg`, padding 16. **Selection = solid accent fill with dark text.**
- **Status bar** (26 px, 12 px `text-2`, thin vertical rules between fields):
  - Left: "Ln 2, Col 9 | 8 of 44 characters"
  - Right: "100% | Unix (LF) | UTF-8"
- **Behaviour:**
  - Closing never prompts; the text and tabs are restored on the next launch.
  - **F5** inserts the time and date as "4:06 AM 11/24/26" (`h:mm AP M/d/yy`).
  - **Ctrl+H** opens find/replace.
- **Find/replace card:** floating at the top-right of the editor, 360×84, `glass-dark`, radius 10.
  - Row 1: ^ collapse, a "Find" field (accent underline when focused), ↑, ↓, an options icon (sliders: regex / match case), ×.
  - Row 2: a "Replace" field, then text buttons **"Replace"** and **"Replace all"** (no fill; hover grey).
  - Matches are highlighted; the current match has an accent fill.

### 9.4 Calculator [W 3:45–4:02, 6:29–6:42]

Reference frames: `WvjW_06m32.0s_calc_programmer.png`, `WvjW_06m35.0s_calc_nav_drawer.png`, `WvjW_06m41.0s_calc_date_24days.png`, `WvjW_03m58.0s_win123_calculator.png`.

- **Window** 328×570 (the Windows 11 Calculator clone).
- **Header:** ☰ hamburger, mode title ("Standard" / "Programmer" / "Date calculation"), history icon.
- **Nav drawer** (☰): Standard, Scientific, Programmer, Date calculation, and converters (assumed from "unit converters").
- **Standard:**
  - Expression line 13 px `text-2`; result 44 px Semibold, right-aligned.
  - Memory row: MC MR M+ M- MS.
  - Keys (gap 3, radius 6, #1E2129, hover #262A33):
    - `%` `CE` `C` `⌫`
    - `⅟x` `x²` `²√x` `÷`
    - `7` `8` `9` `×`
    - `4` `5` `6` `−`
    - `1` `2` `3` `+`
    - `+/-` `0` `.` **`=`**
  - `=` is filled accent with dark text.
- **Programmer:**
  - Rows HEX FF / DEC 255 / OCT 377 / BIN 1111 1111. The active base has an accent left bar and accent text.
  - Controls: QWORD, MS, M˅, "Bitwise ˅", "Bit shift ˅".
  - Keypad adds A–F, «, », (, ).
- **Date calculation:**
  - "Difference between dates ˅".
  - From "December 1, 2026" and To "December 25, 2026" (fields with calendar icons; clicking opens a date-picker popover).
  - "Difference": **"3 weeks, 3 days"** (20 px Semibold) / "24 days".

### 9.5 Task Manager (Ctrl+Shift+Esc) [W 6:14–6:28]

Reference frames: `WvjW_06m16.0s_taskmanager_processes.png`, `WvjW_06m19.0s_taskmanager_efficiency.png`, `WvjW_06m23.0s_taskmanager_startup.png`.

- **Window** 1180×768. The title-bar area holds a centred search field: **"Type a name or PID to search"** (360×30).
- **Left rail** (48 px collapsed / 200 px expanded):
  - ☰, Processes, Performance, App history, Startup apps, Users, Details, Services; Settings at the bottom.
  - Selected = `accent-soft` + accent bar.
- **Toolbar** (right-aligned): `Run new task`, `End task`, `Efficiency mode`, `View ˅`.
  - Pressed or active toggle = `accent-soft` fill.
  - Disabled = 40% opacity.
- **Processes:**
  - Columns: Name, Status, "1.5%" over "CPU", "10%" over "Memory", "4%" over "Disk" (the total sits above each label).
  - Groups: "Apps (5)" and "Background processes (68)", each a collapsible header.
  - Rows 32 px with an app icon. Usage cells are heat-tinted: accent at 0–35% alpha by value.
  - Selecting a row and pressing Efficiency mode sets Status to **"Efficiency mode"** (renice / cgroup cpu.weight).
- **Startup apps:**
  - Buttons Enable / Disable.
  - Columns: Name ^, Publisher, Status, Startup impact.
  - Rows: "Clipboard history" / "⟦Velotic Studios⟧" / Enabled; "Windows Security notification icon (Windows Engine …)" / Microsoft Corporation / Enabled / 13.0 MB.
- **Performance** (older/excluded source): left list with sparklines (CPU, Memory, Disk, Ethernet, GPU) and a right graph with accent fill. Build it in the same style.

### 9.6 Snip (Win+Shift+S, CC "Snip") [W 1:40–1:50]

Reference frames: `WvjW_01m42.0s_snip_toolbar.png`, `WvjW_01m43.0s_snip_drag.png`, `WvjW_01m45.0s_snip_editor_toast.png`, `WvjW_01m50.0s_snip_copied_toast.png`.

**Overlay**
- The screen is dimmed with rgba(0,0,0,0.35).
- **Toolbar** at top-centre, 16 px under the top bar: **229×45 px**, `glass-dark`, radius 12.
  - Mode buttons 36×32, in this order: **rectangle** (selected: accent-filled tile), **freeform** (lasso), **window**, **fullscreen**, then a divider and ×.
  - Hint under the toolbar: **"Drag to snip an area"** (12 px, white with a shadow).
- **Dragging:** a 1 px white rectangle (inside undimmed), an accent crosshair, and a dark size label "823 × 140" under the top-left corner.

**Editor window** (after capture)
- Toolbar:
  - ←
  - **[+ New]** (accent)
  - "Rectangle ˅", "No delay ˅" (stopwatch)
  - divider
  - pen (active tile with an accent colour bar under it), highlighter (yellow bar), eraser, crop
  - undo, redo (disabled)
  - zoom − "100%" +
  - **[Copy]**, **[Save]**, ···
- The image sits centred on a dark canvas. The pen draws in accent by default.
- **Toast** (bottom-centre of the editor, dark pill): **"✓ Copied to the clipboard and saved to Pictures › Screenshots"**, later "Copied to the clipboard".

**Empty state**
- [W] does not show it; the source is excluded 4Tyj: pink icon, "Snip anything on your screen", "+ New snip". Include it.
- Auto-save target: ~/Pictures/Screenshots.

### 9.7 Terminal [W 0:34–0:39]

- Window 1056×623, title "Terminal". The standard chrome and pill.
- Dark #0E1018 background, monospace 13 px, accent cursor.
- Konsole underneath (themed); the running command was `top`.

### 9.8 ⟦Velotic Store⟧ [T 3:50–4:07] (layout extras from [2] 4:37–4:50)

Reference frames: [T] `TrNP_03m52.0s_store_home.png`, `TrNP_04m02.8s_store_installing_bar.png`, `TrNP_04m03.5s_store_installing.png`, `TrNP_04m05.0s_store_krita_open.png`; [2] `2uwx_04m40.5s_store-home.png`, `2uwx_04m43.5s_store-results.png`, `2uwx_04m44.5s_store-installing.png`, `2uwx_04m47.5s_store-open.png`.

- **Window** 1180×810. The title bar shows "⟦Velotic Store⟧".
- **Sidebar** (230 px):
  - Logo: a purple bag squircle 36 px + **"⟦Velotic⟧"** (15 px Semibold) over **"Store"** (12 px `text-2`).
  - Nav pills (202×40, radius 20): **Home** (selected: crimson→accent gradient fill, white text), **Browse**, **Installed**.
  - Footer card at the bottom (radius 10, `card`): **"Apps from Flathub and their makers."**. Older [2]: "Free apps from Flathub and their makers, checked and kept in their own sandbox."
- **Search bar** (full width, 36 px, radius 8): "Search apps", magnifier at the right. With text it gets a 1 px accent border and a × clear button.
- **Hero** (full width × 232 px, radius 12):
  - Background: a dark maroon gradient (#3A0A1C → #7A1238) with floating 3D crimson/dark rounded app tiles on the right third.
  - Kicker **"Apps"** (12 px accent-pink, Semibold), title **"Apps for everything you do"** (28 px Semibold), body **"Apps from Flathub and their makers, updated in one place."** (13 px `text-2`).
  - 4 feature items in a row, each an icon + title (13 px Semibold) + sub (12 px):
    - "Trusted sources" / "Flathub and the makers"
    - "Updates in one place" / "Update all at once"
    - "One click" / "No installers to find"
    - "One place" / "Browse, install, remove"
- **Category chips** (32 px, radius 16, `card`, each with an icon): Popular, Trending, Games, Office, Photos and design, Music and video, Internet, Education, Coding, Tools.
- **"Essentials"** section:
  - Header: "Essentials" (17 px Semibold), "The 12 apps most people install first. One click each." (12 px `text-2`), and an accent "See all ›" at the right.
  - Cards in a 4-column grid, about 215×188, `card`, radius 10. Each has an app icon 48, name 14 px Semibold, a one-line description 12 px, and a full-width accent button **"⤓ Install"** (32 px, radius 8). Hover lightens the card.
  - Cards: Google Chrome "Google's web browser" · Firefox "Fast, private web browser" · Discord "Voice, video and text chat" · Steam "Buy and play games" · VLC "Plays any video or music file" · Spotify "Music and podcasts" · LibreOffice "Office suite" · OBS Studio "Record and stream your screen".
- **Search results:** heading **"Results for “krita”"**, then a "Loading…" state and the same cards (e.g. "Krita" / "by Krita Foundation" / "Digital Painting, Creative Freedom" / "⤓ Install").
- **Install states:**
  1. "⤓ Install"
  2. The button is replaced by **"Installing 34%"** (12 px `text-2`) with a 2 px accent progress line, and the card gets a 1 px accent border.
  3. A bottom banner strip across the content (36 px, `glass-dark`, radius 8) reads **"Installing apps. You can keep browsing."**
  4. When done: a **green dot** (#6CCB7A, 8 px) at the card's top-right, and the button becomes a grey **"↗ Open"** (rgba(255,255,255,0.10)).
- **App page** (excluded 4Tyj, same style): "← Back", icon, name, publisher in accent, Open (accent) / Uninstall (grey), screenshots, description.

### 9.9 Welcome and Drivers apps

**Not shown open in any of the 3 videos.** Only their icons and launcher entries appear (Welcome = peach sunset, Drivers = orange chip).

From the installer text, Welcome runs at first sign-in and lets the user "choose your web browser, and Windows or Android app support". Build:
- **Welcome:** a 3-page wizard in the installer card style (§11): Browser → App support (Windows apps / Android apps checkboxes) → Done.
- **Drivers:** a Settings-style row list, one row per detected device, with the current driver and an accent "Install" button.

---

## 10. Windows apps and Android apps

### 10.1 Windows Engine [W 3:01–3:44], [2 2:08–2:38]

Reference frames: `WvjW_03m04.0s_win_notepad.png`, `WvjW_03m17.0s_msstore_results.png`, `WvjW_03m21.0s_msstore_paint_page.png`, `WvjW_03m28.0s_msstore_downloading.png`, `WvjW_03m32.0s_paint.png`; [2] `2uwx_02m15.3s_winengine-dialog.png`, `2uwx_02m23.5s_winengine-notepad.png`.

- Windows apps (VM RemoteApp windows) appear as normal windows with **their own Windows 11 title bars and caption buttons**. Genuine Win11 Notepad, Microsoft Store and Paint were shown.
- The top-bar app name reads **"Windows app"** (for the Store). A **Windows-engine indicator with a count** appears in the top-bar tray while apps run.
- Clipboard is shared both ways: copy in Windows Notepad, paste in native Notepad.
- In the dock, Windows apps use their own icon with a small blue badge.

**Launch dialog** [2 2:15]:
- A small window **400×150 px** titled **"Windows Engine"** (green rounded-square icon with a white ring). It uses the standard chrome; the old build had a light title bar.
- Body:
  - a dark 40 px tile with an accent window-stack glyph
  - **"Opening Paint.NET..."** (16 px Semibold)
  - "Paint.NET" (12 px `text-2`)
  - an **indeterminate** 3 px accent progress bar, 285 px wide
- It appears about 0.8 s after launch, with no entry animation, and closes when the app window maps.
- The dock adds a generic window placeholder icon while it is loading.

**Search subtitle for Windows apps:** "Windows app (runs in the Windows Engine)".

**Startup item:** "Windows Security notification icon (Windows Engine …)".

### 10.2 Android apps [2 2:39–3:42] (only source; the older build)

- **"Android apps"** launcher (green phone icon) / command bar: "Run Android apps on ⟦FlowOS⟧: set up Android, Google Play, install .apk files".
- Android apps open in their own windows. The title bar has **← back** (and **⌂ home** for the full Waydroid UI) left of the title.
  - In [2] the window was maximised, so these were in the top bar.
  - Build: put them in the window title bar left of the title, as 28×22 icon buttons.
- **Portrait games:** a 9:16 window centred on screen; the side areas are filled with a **blurred, stretched copy of the game** (blur 40 px, 60% brightness).

### 10.3 Android game controls (key mapping)

Reference frames: [2] `2uwx_03m28.5s_gamecontrols-toast.png`, `2uwx_03m36.5s_gamecontrols-edit.png`, `2uwx_03m38.5s_gamecontrols-hint.png`, `2uwx_03m41.5s_gamecontrols-toast2.png`.

- **Toast** (OSD pill, top-centre under the top bar, 528×33 px):
  - gamepad glyph + **"Game controls on. Alt frees the mouse, F12 turns them off, Win+Shift+G edits."** (13 px)
- **Overlay chips** over the game:
  - Dark translucent circles: 42 px, rgba(0,0,0,0.45), 1 px rgba(255,255,255,0.35) border, white 13 px label.
  - Chip labels: "F", "G", "R", "C", "M", "Space", "Click", "1", "2". "Right click" is a pill.
  - A **WASD joystick ring** (radius 135 px) with W/A/S/D square chips at N/W/S/E.
  - A **"Mouse aim"** ring (radius 243 px) with its label.
- **Edit mode (Win+Shift+G):**
  - Toolbar at top-centre, 930×39, `glass-dark`, radius 10:
    - **"Game controls"** (Semibold)
    - | ✋ **Tap** | 🎮 **Joystick** | ◎ **Mouse aim** | ⟳ **Repeat** | **Swipe** | 🗑 **Remove**
    - **"Cancel"** (dark pill), **"Save"** (accent pill)
  - The game surface gets a 1 px accent outline. A newly placed chip has an accent ring.
  - Bottom hint: **"Press a key, click a mouse button or turn the wheel. Esc cancels."**
  - Saving shows the toast again.

### 10.4 Mac apps (marked "EARLY PREVIEW · NOT FINISHED" in [2]; low priority)

- Double-clicking a `.dmg` raises a **bottom-right toast** (378×84, `glass-dark`, radius 10, 40 px icon area):
  - **"Mac apps"** (12 px `text-2`)
  - **"Opening googlechrome.dmg"** (14 px Semibold)
  - "This can take a moment the first time." (12 px `text-2`)
- The window is a normal host frame. Inside it is a light macOS-style strip with traffic lights, a centred title and an in-window menu bar.

---

## 11. Installer (live session)

Reference frames: [T] `TrNP_05m05.5s_installer_welcome.png`, `TrNP_05m10.0s_installer_software.png`, `TrNP_05m19.2s_installer_checking_spinner.png`, `TrNP_05m20.6s_installer_ready_summary.png`, `TrNP_05m22.0s_installer_progress.png`, `TrNP_05m25.0s_installer_progress_tip2.png`, `TrNP_05m27.5s_installer_done.png`; [2] `2uwx_04m54.5s_installer-drive.png`, `2uwx_05m11.5s_installer-progress54.png`.

### 11.1 Layout

**Background**
- Full-bleed wallpaper #1, pink/crimson mountains or abstract crimson waves. No top bar, no dock.

**Window**
- A centred card, **1035×714 px**, fill **#0E0F13**, radius 14, shadow.
- Top-right corner: a small **power** glyph button (16 px, `text-2`) to shut down or quit.

**Stepper** (top-centre, 28 px from the top; only on the Drive, Software and Ready pages; not on Welcome, Progress or Done)
- Steps: **Network · Activate · Drive · You · Region · Software · Install**.
- Each step is a dot + label pair, 12 px, with a 14 px gap.
  - Done: dim-accent dot (accent at 45%) + `text-2` label.
  - **Current: an accent pill 30×9 + a bold white label.**
  - Upcoming: grey dot (#4A4D55) + `text-3` label.
- The **Activate** step (product key) does not apply to TEMUOS; drop it or keep it as a no-op.

**Page body**
- Content column 640 px wide, centred.
- Title 28 px Semibold, centred; subtitle 14 px `text-2`.

**Buttons** (bottom-right, 32 px from the edges)
- **Primary:** accent fill, dark text 14 px Semibold, 40 px high, radius 8, with a leading icon.
- **"Back":** ghost (rgba(255,255,255,0.06)).

**Advanced mode** (bottom-left, Welcome and Drive pages only)
- A toggle + **"Advanced mode"** (13 px Semibold) / "Show partitions and technical details" (12 px `text-2`).

### 11.2 Pages (exact strings)

**1. Welcome**
- ⟦LOGO⟧ 84 px, then **"Welcome to ⟦FlowOS⟧"**.
- Body: "Let's put ⟦FlowOS⟧ on your computer. You'll need your product key and an internet connection: ⟦FlowOS⟧ downloads its newest version while it installs. You can keep Windows and all your files." Drop the product-key clause for TEMUOS.
- Primary button **"→ Install ⟦FlowOS⟧"** (centred, 147×46).

**2. Network, 3. Activate, 5. You, 6. Region:** not shown. Build them with the same components:
- Network: a Wi-Fi list.
- You: name, username and password.
- Region: language, timezone, keyboard.

**4. Drive** [2]
- Title **"Where should ⟦FlowOS⟧ go?"** / "Pick a drive. Your files stay safe unless you choose to replace everything."
- Disk card (full column width, 105 px, 1 px accent border when selected): "Disk 1 · Drive" / "64 GB Drive · empty", with a usage bar.
- Prompt: "How should ⟦FlowOS⟧ use Disk 1 · Drive?"
- Option card: radio + folder icon + **"Use this empty drive"** + badge **"Recommended"** (accent-tinted pill, 11 px) / "This drive is empty, so ⟦FlowOS⟧ can use all of it."
- Buttons: Back / **"→ Continue"**.
- For dual boot, use the excluded video's strings (same layout): "Install next to Windows" with a draggable split bar and "Replace everything on this disk".

**7. Software**
- Title **"How much should ⟦FlowOS⟧ install?"** / "Either way you can add or remove apps any time later."
- Two radio cards (full width, about 120 px, radius 10, `card`). The selected card has a 1.5 px accent border and a filled accent radio.
  - **"Recommended"** (4-squares glyph) + badge **"Best for most people"**: "Ready to use, like Windows: photos, documents, videos, music, archives and disks open straight away. You choose your web browser, and Windows or Android app support, when you first sign in."
  - **"Minimal"** (pink **leaf** glyph): "Just the essentials: the desktop, Files, Settings, Notepad and Calculator, with a lighter look (no see-through glass). Over 1 GB smaller and uses the least memory, for small or older computers."
- Buttons: Back / **"→ Continue"**.

**8. Ready to install**
- Title **"Ready to install"** / "Here's what will happen. Nothing changes until you press Install now."
- First, for about 1 s: a centred accent ring spinner (32 px) + **"Checking your choices…"**.
- Then a checklist (rows with 22 px accent-tinted check circles, 14 px text):
  - "⟦FlowOS⟧ uses all of Disk 1 · Drive (64 GB). It's empty, so nothing is lost."
  - "Recommended ⟦FlowOS⟧, ready to use: everyday apps and ⟦Velotic Store⟧ included."
  - "Windows and Android app support can be added when you first sign in."
  - "Your account "alex" is created."
- Checkbox card (accent lock icon): **"Encrypt this drive"** / "Keeps your files safe if the computer is lost or stolen. This computer has no security chip, so you type your password each time it starts."
- Buttons: Back / **"✓ Install now"**.

**9. Progress**
- A ring 104 px in diameter, 6 px accent arc on a #2A2D35 track, with the **percentage inside in 36 px Inter Light**.
- Under it, a title (18 px Semibold) and detail (13 px `text-2`):
  - "Getting your disk ready" / "Clearing the disk" (2%)
  - **"Downloading ⟦FlowOS⟧"** / first "Connecting to ⟦Velotic Studios⟧", then "1 MB of 2.2 GB" … "3.5 GB of 5.0 GB · about 1 min left"
- Tip box (560×44, #16181E, radius 10, 13 px `text-2`) rotating every about 6 s:
  - "Tip: Press Super + Space to find any app, do quick maths, or search the web."
  - "Tip: Double-click a Windows program (.exe) to run it. ⟦FlowOS⟧ takes care of the rest."

**10. Done**
- A green circle 96 px (#6CCB7A) with a white check.
- **"⟦FlowOS⟧ is ready"**, then "Restart your computer and remove the USB stick when the screen goes dark."
- Primary button **"⟳ Restart now"**.

---

## 12. Light mode

**Sources:**
- [T 4:28–4:33]: the whole shell switches with the CC Dark-mode tile.
- [2 0:46]: the CC goes light, and the dock and top bar too.
- [W] shows Light / Dark / Auto (sunset) thumbnails only.

| Surface | Light value |
|---|---|
| Top bar | rgba(240,242,246,0.75) + blur, text and glyphs #1B1D22 |
| Dock / taskbar | rgba(250,250,252,0.62) + blur, rim rgba(0,0,0,0.08); dot #1B1D22 |
| Start / CC / menus / banners | rgba(246,247,250,0.80) + blur, rim rgba(0,0,0,0.06), text #15171C / #5D636E |
| CC tiles | rgba(255,255,255,0.70); OFF circles #D9DCE1; ON circles stay accent |
| Windows | body #F7F7F9, cards #FFFFFF with border #E6E7EB, sidebar selected #ECEDF1 |
| Wallpaper | the day variant of the current wallpaper (Tide day = white and pale ice-blue waves) |

**Switch:** the shell switches in 1 frame and the wallpaper crossfades over 450 ms.

**Auto (sunset):** follows local sunset and sunrise.

---

## 13. Keyboard shortcuts (all shown in [W] unless noted)

| Shortcut | Action |
|---|---|
| Super | Start |
| Super+Space | Command bar |
| Super+A | Control Center (from the installer tip in the older video) |
| Super+V | Clipboard history |
| Super+. | Emoji |
| Super+Shift+S, Print | Snip |
| Super+X | Quick menu |
| Super+1…9 | Dock app N |
| Ctrl+Shift+Esc | Task Manager |
| Super+←/→ | Snap |
| Space (in Files) | Quick Look |
| Alt+P (in Files) | Details pane |
| F2 | Rename |
| Ctrl+Z (in Files) | Undo a delete |
| Shift+Del | Delete for good |
| Alt+Enter | Properties |
| Middle-click on a tab | Close the tab |
| F5 (in Notepad) | Insert time/date |
| Ctrl+H (in Notepad) | Find/replace |
| Super+G / F12 [2] | Android game controls on/off |
| Super+Shift+G [2] | Edit game controls |
| Alt [2] | Free the mouse (game controls) |

---

## 14. KDE / Plasma 6 implementation map (short)

| Element | Build as |
|---|---|
| Top bar | Plasma top panel 28 px, "floating" off, custom translucent Plasma SVG (or a custom QML layer-shell bar). Logo button + Window-title applet showing the **app name**. Custom tray applet: Gaming pill, ⚡, network/sound/battery cluster button → CC, and a clock applet (`ddd d MMM` + `HH:mm`) → calendar. |
| Dock | Plasma bottom panel in "Fit content" floating mode, or a custom QML dock (preferred, for the exact indicators and slot). Icons-only Task Manager fork with the white dot and accent bar, custom context menu (Keep on top = KWin keepAbove), Magic Lamp effect, auto-hide. |
| Taskbar mode | Second panel layout applied live with `evaluateScript`; remove the top panel. |
| Start | Custom plasmoid (Kickoff fork) with the §4 layout. Search via KRunner `Milou` models (apps, calculator, unitconverter + currency, webshortcuts). Enter copies answers. |
| Command bar | KRunner restyled (Plasma 6 floating) or a custom QML window; ">" prefix via the shell runner → `konsole -e`. |
| All apps | Custom full-screen QML (or Application Dashboard fork) with 7 columns and hidden panels. |
| Control Center | Custom plasmoid (plasma-nm, BluezQt, PowerDevil brightness, plasma-pa, DND, `plasma-apply-colorscheme` / look-and-feel + wallpaper day/night, KWin virtual desktops, notification model). Shortcut Meta+A. |
| Banner / OSD | Replace the plasmashell notification popup QML: top-centre 437×80, `island` animation; OSD via the same component. |
| Calendar | Digital Clock popup restyled (295×309). |
| Clipboard / emoji | Custom panel over the Klipper D-Bus history + the plasma-emojier data. |
| Task View | KWin Overview with the desktop bar; Slide effect for desktop switches. |
| Win+X | Small QML popup plasmoid bound to Meta+X. |
| Settings | Kirigami shell with the custom IA embedding KCMs (kcm_mouse, kcm_touchpad, colours, wallpapers…) and custom pages (Dock and taskbar, Key mapping, App support, Update & drivers). |
| Files | Custom Qt/QML file manager (Home dashboard, tabs, Details, Quick Look, Pinned), or a deeply patched Dolphin. |
| Notepad / Calculator / Task Manager / Snip | Custom Kirigami apps matching §9 (Snip may wrap Spectacle capture). |
| Decorations | Custom KDecoration (Klassy-based) with a 28 px title bar matching the body colour, a grouped – ▢ × pill, 12 px rounded corners. |
| Installer | Custom QML front-end (Calamares modules or archinstall back-end) matching §11. |

---

## 15. Reference frames

Saved in `C:\Users\asdf\AppData\Local\Temp\claude\faac1ebfcdbfa908\8ecb1a70-57dd-4709-906b-003f361f46b5\scratchpad\spec-frames\`, with zooms in `zoom\` and animation sequences in `anim\`. All frames are 1280×720.

The most important frames:

| Element | File |
|---|---|
| Desktop, top bar, dock (Tide) | WvjW_00m00.5s_desktop_dock_topbar.png |
| Start menu (geometry) | WvjW_00m04.5s_start_open_unzoomed.png |
| Start answers | WvjW_00m22.0s_start_units.png, WvjW_00m26.0s_start_currency.png, WvjW_00m30.0s_start_maths_final.png |
| Command bar | WvjW_00m31.5s_cmdbar.png, WvjW_00m33.0s_cmdbar_top.png |
| Settings search / Mouse & touchpad | WvjW_00m42.0s_settings_search_results.png, WvjW_00m45.0s_settings_mouse_touchpad.png |
| Notepad | WvjW_01m21.5s_notepad_f5_tabs.png, WvjW_01m28.0s_notepad_find_replace.png |
| Clipboard / emoji | WvjW_00m58.0s_clipboard_panel_full.png, WvjW_01m04.0s_emoji_panel.png |
| Snip | WvjW_01m42.0s_snip_toolbar.png, WvjW_01m45.0s_snip_editor_toast.png |
| Files | WvjW_02m03.0s_files_home.png, WvjW_01m56.5s_quicklook.png, WvjW_02m28.6s_files_multiselect_menu.png, WvjW_02m47.0s_details_notes.png, WvjW_02m19.0s_files_undo_toast.png, WvjW_02m24.5s_trash_empty.png |
| OSD pill | WvjW_02m53.0s_osd_pill.png |
| Windows Engine | WvjW_03m04.0s_win_notepad.png, WvjW_03m17.0s_msstore_results.png, 2uwx_02m15.3s_winengine-dialog.png |
| Dock menu / tooltip | WvjW_03m45.5s_dock_context_menu.png, WvjW_04m34.0s_dock_tooltip_files.png |
| Full-screen strip, Win+X | WvjW_04m09.5s_fullscreen_hover_strip.png, WvjW_04m14.0s_winx_menu.png |
| Task View | WvjW_04m27.5s_task_view.png |
| Desktop icons / menu | WvjW_04m46.0s_desktop_rename_field.png, WvjW_05m11.6s_desktop_context_menu.png |
| Personalisation (dock / taskbar) | WvjW_04m57.0s_personalisation_dock_mode.png, WvjW_04m52.0s_personalisation_taskbar_mode.png |
| Control Center | WvjW_05m26.0s_control_center.png, WvjW_05m34.0s_control_center_notifications.png, WvjW_05m42.6s_cc_group_expanded_showless.png |
| Notification banner | WvjW_05m36.8s_notification_banner.png |
| Calendar | WvjW_05m47.5s_calendar_popover.png, WvjW_05m51.0s_calendar_december_today.png |
| Colours | WvjW_06m01.0s_colours_peach_hover.png, WvjW_06m09.0s_colours_coral_current.png |
| Task Manager | WvjW_06m16.0s_taskmanager_processes.png, WvjW_06m23.0s_taskmanager_startup.png |
| Calculator | WvjW_06m32.0s_calc_programmer.png, WvjW_06m41.0s_calc_date_24days.png |
| Gaming pill | zoom\TrNP_03m05.0s_gaming_pill_x2.png, TrNP_01m04.5s_steam_launch_dialog.png |
| CC light | TrNP_04m30.6s_control_center_light_full.png |
| All apps grid | TrNP_04m41.5s_allapps_grid.png |
| Background page + toast | TrNP_04m50.5s_files_settings_snap.png, TrNP_04m56.0s_settings_toast.png |
| Store | TrNP_03m52.0s_store_home.png, TrNP_04m03.5s_store_installing.png, TrNP_04m05.0s_store_krita_open.png |
| Installer | TrNP_05m05.5s_installer_welcome.png, TrNP_05m10.0s_installer_software.png, TrNP_05m20.6s_installer_ready_summary.png, TrNP_05m22.0s_installer_progress.png, TrNP_05m27.5s_installer_done.png, 2uwx_04m54.5s_installer-drive.png |
| Key mapping / game controls | 2uwx_03m45.5s_settings-keymapping.png, 2uwx_03m36.5s_gamecontrols-edit.png, 2uwx_03m28.5s_gamecontrols-toast.png |
| Icon zooms | zoom\me_dock_x4.png, zoom\me_start_icons_x4.png, zoom\me_settings_nav_x4.png |

**Animation sequences** (10 fps) are in `anim\`:
- [W]: WvjW_start_open_*, WvjW_cmdbar_open_*, WvjW_clipboard_slidein_*, WvjW_quicklook_open_*, WvjW_osd_pill_*, WvjW_genie_minimise_*, WvjW_desktop_slide_*, WvjW_task_view_*, WvjW_autohide_slide_*, WvjW_notification_banner_*, WvjW_swipe_dismiss_*, WvjW_accent_hover_*
- [T]: TrNP_darklight_*, TrNP_notification_slidein_*, TrNP_allapps_open_*, TrNP_wallpaper_toast_*, TrNP_store_install_*
- [2]: 2uwx_island-drop_*

---

## 16. Open points (not visible in any used video)

- Boot splash, login and lock screens.
- Power menu contents.
- Welcome and Drivers app windows.
- Network, Activate, You and Region installer pages.
- Settings pages other than those listed.
- Taskbar-mode Start position (assumed to be the same centred menu).
- The meaning of the ⚡ top-bar glyph.
- Gaming pill OFF look.

These are marked as design decisions above.
