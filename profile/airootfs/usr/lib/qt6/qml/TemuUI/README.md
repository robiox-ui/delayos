# TemuUI (QML module, owned by the apps-core stream)

`import TemuUI` — design tokens (`Theme`) + reusable controls for every TEMUOS app and plasmoid.
Controls are built on `QtQuick.Templates`, so they look the same under any Qt Quick Controls style
(apps set `QT_QUICK_CONTROLS_STYLE=Basic` through `temuapp.py`). Do not edit; ask apps-core for changes.

| Type | What | Key properties / signals |
|---|---|---|
| `Theme` (singleton) | colours, radii, fonts, motion (§0.3/0.4) | `dark`, `accent`, `accentSoft`, `windowBg`, `card`, `cardHover`, `card2`, `field`, `text1..3`, `popupBg`, `popupRim`, `hover`, `hoverStrong`, `pressed`, `divider`, `buttonBg`, `iconTile`, `key`, `keyHover`, `dangerText`, `textOnAccent`, `textOnAccentDark`, `scrim`, `rCard`… |
| `TText` | Text with Inter 13 px text-1 defaults | `secondary`, `muted`, `semibold` |
| `TIcon` | 1.5 px line glyph from `icons.js` (Lucide style, ~130 names) | `name`, `size`, `color`, `stroke`, `filled` |
| `TButton` | push button | `variant`: default / accent / ghost / subtle / danger, `iconName`, `chevron`, `checkable`+`checked` (accent-soft), `semibold` |
| `TIconButton` | 32 px icon-only button | `iconName`, `box`, `iconSize`, `tip` (tooltip), `checked`, `danger` (red hover) |
| `TToolTip` | small dark tooltip | standard ToolTip API |
| `TToggle` | 40×20 switch with "켬/끔" label | `checked`, `showState`, `onText`, `offText` |
| `TSlider` | 150 px accent slider | standard Slider API |
| `TField` | text field (`field`, accent focus border) | `iconName`, `iconRight`, `clearable`, `underline`, `placeholderText`, signal `cleared()` |
| `TDropdown` | 163×32 combo box with menu-style list | `model`, `textRole`, `currentIndex`, `flat`, `iconName` |
| `TSegmented` | segmented control | `model` (strings or `{text, iconName}`), `currentIndex`, signal `activated(i)` |
| `TCheckBox` | 18 px accent check box | standard CheckBox API |
| `TProgressBar` | thin accent bar | `value`, `thickness`, `indeterminate` |
| `TScrollBar` | thin overlay scroll bar | `T.ScrollBar.vertical: TScrollBar {}` (import QtQuick.Templates as T) |
| `TMenu` / `TMenuItem` / `TMenuSeparator` | context menus (radius 10, 32 px rows, shortcut hints, submenus) | `TMenuItem { text; iconName; shortcut; danger }`, `menu.popup()` |
| `TToast` | in-window toast, `toast-up` motion | `show(text, icon?)` pill; `showCard(title, body)` 320×60 card with × |
| `TDialog` | modal dialog with scrim | `title`, `text`, `buttons: [..]`, `accentIndex`, signal `buttonClicked(i)`, extra children go under the text |
| `TCard` | `card` surface radius 8 | `hoverable`, `clickable`, `selected`, signals `clicked/rightClicked/doubleClicked(mouse)` |
| `TRow` | Settings row 58 px (icon tile, title, subtitle, control at right) | `iconName`/`iconSource`, `title`, `subtitle`, `chevron`, `expandable`+`expanded`, children = control, `highlight()` |
| `TNavItem` | sidebar item | `text`, `iconName`/`iconSource`/`leading`, `selected`, `style`: "soft" (accent-soft, 32 px) / "settings" (#23242D, 40 px, Semibold), `collapsed`, `badge` |
| `TSectionHeader` | section header (13 px Semibold, or `small` 11.5 px text-3 for sidebars) | `text`, `iconName`, `small` |
| `TPageTitle` | 28 px breadcrumb | `path: [..]`, signal `crumbClicked(i)` |
| `TSidebarLayout` | sidebar + content window layout | `sidebarWidth`, `sidebar: [...]`, `content: [...]`, `divider`, `sidebarVisible` |
| `TWindow` | top-level window (window-bg, centred, built-in `toast`) | `title`, `width/height`, `toast.show(..)` |
| `TTabStrip` | browser-like tabs (Notepad, Files) | `model` (roles `title`, `iconName`/`iconSource`, `dirty`), `currentIndex`, `tabMaxWidth`, signals `activated(i)`, `closeRequested(i)`, `addRequested()`, `moveRequested(from,to)` |

Icon names: see `icons.js` (`search x plus minus check check-circle info chevron-* arrow-* refresh undo redo home folder folder-open file file-text image music video download monitor trash scissors copy clipboard rename share grid table list more panel-right settings menu history clock star archive link pin zoom-in zoom-out pen highlighter eraser crop timer rect lasso window fullscreen save cpu memory activity users user package gauge leaf ban eye run calendar calculator function code drive sliders network gpu terminal backspace sun moon bell power lock globe wifi bluetooth volume mouse keyboard gamepad palette shield smartphone bag battery filter edit …`).

Python apps: `sys.path.insert(0, "/usr/share/temuos/apps/common"); from temuapp import run` — sets the style, Wayland app_id,
Inter font, single-instance (optional) and keeps `Theme.dark/accent` in sync with `~/.config/kdeglobals`
(`[General] ColorScheme` containing "Light" → light, `[General] AccentColor=r,g,b`, or `[TemuOS] Dark=`/`Accent=#rrggbb` overrides).
