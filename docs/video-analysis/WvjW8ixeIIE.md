# FlowOS demo video (WvjW8ixeIIE): frame-by-frame breakdown

Source: "FlowOS Is Everything Windows 11 Should Have Been" (7:25). I read all 50 contact sheets (sheet_000 to sheet_049, 1 fps; the last sheet holds 5 frames and ends on black at 7:25).

How to read this report:
- On-screen captions are quoted exactly. Each caption has a small coral/pink uppercase **section label** (for example `START`, `COMMAND BAR`) over a white sentence.
- UI text is tiny in the contact sheets. Text I could not read with confidence is marked "(approx.)" or "(illegible)".

**Presentation format.** Every desktop shot sits inside a floating screen with rounded corners and a drop shadow, over a heavily blurred nature video (green meadow, sky, white flowers, a brick wall). Section title cards use the same blurred nature footage with a large bold white headline and a lighter subtitle. That framing belongs to the video, not the OS.

---

## 1. Timeline

| Time | On screen |
|---|---|
| 0:00 | Empty desktop with the layered-wave wallpaper (navy at the top to aqua/teal at the bottom; this is "FlowOS Tide"). A thin top bar and a small floating dock sit at bottom-center. |
| 0:01–0:02 | Label `FLOWOS`: "This is FlowOS." |
| 0:03–0:05 | "A new operating system for your PC." At 0:04 the Start menu opens as a centered floating panel above the dock (contents at 0:19). |
| 0:06–0:08 | "Your Windows, Android and Linux apps, on one desktop." Plain desktop. |
| 0:09–0:13 | Title card: **"The little things."** / "This video skips the big features. It is about the small things you use every day." |
| 0:14–0:17 | Title card: **"Find anything."** / "Start, the command bar and Settings answer as you type." |
| 0:18–0:20 | `START` "Quick answers, right in Start." The Start menu is a tall, dark, translucent panel with rounded corners and a rounded search field: "Search apps, files and the web". **Pinned** (link "All apps >") shows a 6-column grid. Row 1: Files (pink folder), Notepad (yellow), Calculator (dark), Settings (gear), Task Manager (chart), Android apps (green). Row 2: Terminal, Snip (pink), Drivers (orange), Welcome (peach). **Recommended**: "Files you open will show up here." There is no power or user row in view (a power icon may sit bottom-right; approx.). |
| 0:20 | Typing "5 ft i" gives Best matches: "Search the web for "5 ft i"" / "Search the web" (globe icon, Enter glyph on the right). The highlighted result row has a dark coral-brown tint. |
| 0:21–0:23 | `START` "Units." Query "5 ft in cm" returns "152.4 cm" / "5 ft = · Enter to copy". |
| 0:24–0:27 | `START` "Currency, at today's rate." "40 usd" first gives a web search. "40 usd to eur" returns "36.57 EUR" / "40.00 USD = · rate of 2026-11-23 · Enter to copy". |
| 0:28–0:30 | `START` "Maths." "245" gives a web search. "2450*0.18" returns "441" / "2450*0.18 = · Enter to copy" (calculator icon). |
| 0:31–0:33 | `COMMAND BAR` "Super + Space opens the command bar." A small floating launcher sits in the upper-middle of the screen. Its field reads "Search apps, settings and the web" with an "Esc" chip on the right. Results include Disks ("Manage Drives and Media"), Contacts, Alacritty ("Terminal..."), Calculator ("Standard, scientific and programmer calculator, date calculation and unit converter"), and Android apps ("Run Android apps on FlowOS ... Google Play, install apk files", approx.). Desktop icons sit at the top-left: Ideas.txt, Photo.jpg, Report.txt, Todo.txt. |
| 0:32–0:33 | Typing ">top" gives one result, "top" / "Run in terminal". |
| 0:34–0:39 | `COMMAND BAR` "Type > and a command. It runs in a terminal." A Terminal window opens running `top`. Visible processes include **kwin_wayland**, **konsole**, NetworkManager, kworker and others, which points to KDE Plasma on Wayland. The top bar shows the app name "Terminal". The dock gains a running-app entry. |
| 0:40–0:46 | `SETTINGS` "Settings has search too. Type what you want to change." Settings opens on **Personalisation > Colours**. Typing "mouse" into the sidebar search ("Find a setting") opens a results dropdown: Mouse & touchpad, Key mapping, Bluetooth, Mouse pointer speed, Primary mouse button, Scrolling speed, Reverse scrolling direction, Tap to click, Touchpad scrolling direction, Touchpad cursor speed, Game controls, Mouse speed for aiming. Each result has a breadcrumb subtitle such as "Bluetooth & devices > Mouse & touchpad". Clicking one opens **Bluetooth & devices > Mouse & touchpad**. Under *Mouse*: Primary mouse button [Left ▾], Mouse pointer speed (slider), Scrolling speed (slider), Reverse scrolling direction [Off]. Under *Touchpad*: Tap to click [On, coral switch], Cursor speed (slider), Scrolling direction [Down motion scrolls down ▾], Scrolling speed (slider). A *Related* section follows. The Settings sidebar shows a user avatar and name (blurred), then a search field and: System, Bluetooth & devices, Network & internet, Personalisation, Apps, Accounts, Time & language, App support, Update & drivers. |
| 0:47–0:49 | Title card: **"Typing, sorted."** / "Notepad and the clipboard take care of the boring parts." |
| 0:50–0:53 | `CLIPBOARD` "Copy a few things." FlowOS Notepad is dark, with browser-style tabs ("Untitled", a close dot, "+") and a File / Edit / View menu. A settings gear sits at the right. Text: "meet at 6 / buy milk / flowos.veloticstudios.com". The status bar reads "Ln 2, Col 9 · 8 of 44 characters · 100% · Unix (LF) · UTF-8". Selections are highlighted in coral/red. |
| 0:54–0:57 | `CLIPBOARD` "Win + V shows your clipboard history." A panel slides in at the bottom-right with tabs **Emoji** and **Clipboard** (active, coral). Header "Clipboard history" with a "Clear all" button. Entries are cards: flowos.veloticstudios.com (selected, coral outline), buy milk, meet at 6. Each card has pin and delete icons. |
| 0:58–1:01 | `CLIPBOARD` "Pick an older one and paste it." "meet at 6" is pasted as line 4. |
| 1:02–1:05 | `EMOJI` "Win + period opens emoji." The same panel opens on the Emoji tab: "Search emoji" field, a category icon row (recent, smileys, people, nature, food, travel, objects, symbols, flags), section "Smileys & people", and an 8-column color emoji grid in Noto/Twemoji style. |
| 1:06–1:09 | `EMOJI` "Click one, paste it anywhere." Typing "see you there " and clicking an emoji inserts it. |
| 1:10–1:15 | `NOTEPAD` "Close Notepad without saving." Text: "shopping list: eggs, bread, coffee". The window closes and leaves an empty desktop (no "save?" prompt). |
| 1:16–1:19 | `NOTEPAD` "Open it again. Your text is still there." Notepad reopens with the same text (session restore). |
| 1:20–1:25 | `NOTEPAD` "F5 adds the time and date." A second "Untitled" tab is open. "called the bank " becomes "called the bank 4:06 AM 11/24/26". |
| 1:26–1:30 | `NOTEPAD` "Ctrl + H: find and replace." The tab is "Trip plan.txt": "monday: train at 9 / monday: museum / tuesday: home". An inline find/replace popover has a "Find" field with ↑ ↓ and regex/case toggles plus ×, a "Replace" field, and buttons [Replace] [Replace all]. Matches are highlighted in coral. |
| 1:31–1:35 | `NOTEPAD` "Every match changes at once." Replace "monday" with "friday", then Replace all. |
| 1:36–1:39 | Title card: **"Screenshots."** / "Snip it, mark it up, done." |
| 1:40–1:43 | `SNIP` "Win + Shift + S. Drag over anything." A Files window shows Pictures. A small snip toolbar appears at top-center with mode buttons (rectangle in coral, window, fullscreen, freeform) and ×, plus the hint "Drag to snip an area". While dragging, a white selection rectangle shows a size readout (for example "823 × 1xx"). |
| 1:44–1:47 | `SNIP` "Draw on it." The **Snip** editor window has a toolbar: [+ New] (coral), "Rectangle ▾", "No delay ▾", then pen (active, coral), highlighter, eraser, crop, undo and redo, zoom "100%" with ±, [Copy], [Save], and "...". A toast at the bottom reads "✓ Copied to the clipboard and saved to Pictures > Screenshots". The user draws a red check mark. |
| 1:48–1:50 | `SNIP` "Copied, and saved to Pictures." The toast reads "Copied to the clipboard". |
| 1:51–1:53 | Title card: **"Files."** / "The file manager you already know, with fewer annoyances." |
| 1:54–1:57 | `QUICK LOOK` "Select a file and press Space." Files is open on Pictures: Screenshots (folder), Aurora.jpg, Drift.jpg, Pebble.jpg, Tide.jpg. The selected item has a coral-brown rounded highlight. The Quick Look overlay is a large rounded dark card with header "Pebble.jpg" / "JPEG image · 204 KB · Tuesday 24 November 2026 at 03:18", an [Open] button (coral), and ×. The image is shown big. |
| 1:58–2:00 | `QUICK LOOK` "Space again to close." |
| 2:01–2:06 | `FILES` "Tabs, like a browser." Tabs read Desktop / Documents / Home and "+". Documents holds Projects, Budget.txt, notes.txt, old notes.txt, Trip plan.txt. The **Home** page shows a greeting (blurred, "Good morning, ..."), "Tuesday 24 November", and ☆ **Quick access** cards: My files ("Your own folder"), Desktop, Documents, Downloads, Pictures (each "My files"), Music, Videos. Below is **Recent**: "Files you open will show up here." The status bar reads "7 items in Quick access". |
| 2:07–2:12 | `FILES` "Drag to reorder. Middle-click to close." The Pictures tab is dragged to the first position, then a tab is middle-clicked closed. |
| 2:13–2:16 | `FILES` "Deleted the wrong file?" "old notes.txt" is deleted. |
| 2:17–2:20 | `FILES` "Ctrl + Z puts it back." A toast at the bottom-right reads "Undone" / ""old notes.txt" is back from the Trash" with ×. |
| 2:21–2:27 | `FILES` "Restore anything from the Trash in one click." The Trash view toolbar has "⟲ Put back", "Delete for good", "Empty Trash", Sort, View. The context menu on "draft.txt" offers Put back; Delete for good (red, Shift+Del); Properties (Alt+Enter). The empty state shows a trash icon with "The Trash is empty" / "Things you delete wait here until you empty it." draft.txt is back in Documents. |
| 2:28–2:33 | `FILES` "Zip files from the right-click menu." The multi-select context menu offers: Open 3 items (Enter), Cut (Ctrl+X), Copy (Ctrl+C), Move to Trash (Delete), Compress to ZIP, Copy paths, More actions >, Properties (Alt+Enter). This creates "Archive.zip" (tan zip icon). |
| 2:33–2:37 | `FILES` "Extract them the same way." The context menu on the zip offers: Open (Enter), Open with..., Cut, Copy, Rename (F2), Move to Trash (Delete), Extract here, Compress to ZIP, Copy path, More actions >, Properties (Alt+Enter). An "Archive" folder appears. |
| 2:38–2:42 | `FILES` "Drop a folder on Pinned to keep it close." A new sidebar section "Pinned" appears while dragging, with the dashed drop target "Drop a folder here to pin it". "Projects" lands in Pinned. |
| 2:43–2:49 | `FILES` "Alt + P shows a file's details and first lines." The "Details" toggle at the top-right turns coral and a right-hand details pane opens. For Projects it shows a big folder icon, "Projects" / "Folder", an action icon row (open, share, rename, copy, delete, more), "Contains 0 items", "Modified Today, 04:02", "Created Today, 04:02", "Where My files > Documents". For notes.txt it shows a monospace text preview ("Pick up the parcel before noon. Book the dentist for next week. Water the plants on Sunday. Finish the slides for Thursday."), "notes.txt" / "Text document", Size "124 bytes", Modified, Created, Opened, Where. |
| 2:50–2:56 | `FILES` "Like a photo? Make it your wallpaper from Files." The image context menu offers Open, Open with..., **Set as desktop background**, Cut, Copy, Rename, Move to Trash, Compress to ZIP, Copy path, More actions, Properties. The wallpaper switches to Aurora (pale mint/white). An OSD pill at the top-center (like a dynamic island) reads "Background changed" / "Aurora.jpg". At 2:55 the Files window **minimises with a genie / magic-lamp effect** into its dock icon. |
| 2:57–3:00 | Title card: **"Windows, your way."** / "Shortcuts and touches for the apps you have open." |
| 3:01–3:06 | `WINDOWS APPS` "Copy in a Windows app." Real **Windows 11 Notepad** (light Mica-style, Windows titlebar, a formatting toolbar, status "Windows (CRLF)") runs on the desktop with the text "hello from windows". The top bar's app name reads "Notepad", and a pink Windows-engine indicator appears in the tray area. The dock shows an extra running app at the far right. |
| 3:07–3:11 | `WINDOWS APPS` "Paste in any other app." The text is pasted into the native dark FlowOS Notepad. A tooltip "Notepad" appears over the dock icon. |
| 3:12–3:19 | `MICROSOFT STORE` "The Microsoft Store runs in FlowOS's Windows Engine." The top bar app name reads "**Windows app**". The real Microsoft Store (light theme) searches "paint". Results include Paint, Sib Paint, Paint Universal, Finger Paint (Ape Apps), Picsart Photo Editor, PhotoMind, Sketchbook Pro, Luo Painter and Spectrum Shift Paint Suite, with filters "All departments / Apps / Games". A skeleton loading state shows first. |
| 3:20–3:28 | `MICROSOFT STORE` "Install apps from it, like on Windows." The Paint page shows Microsoft Corporation, a rating, "Built for Copilot+ PC", "Uses AI features", [Get], "Preparing to download / Verifying..." progress, and ESRB "EVERYONE". |
| 3:29–3:37 | `MICROSOFT STORE` "Open, and the app runs on your FlowOS desktop." [Open] is clicked. Microsoft Paint launches with its Windows titlebar ("Untitled - Paint") and full ribbon. |
| 3:38–3:44 | `MICROSOFT STORE` "Microsoft Paint, from the Store, on FlowOS." A red zigzag is drawn. |
| 3:45–3:49 | `WINDOWS` "Keep any window on top." Files is maximised (it reaches the top bar; the dock floats over a teal strip). Right-clicking the Calculator dock icon opens a menu: "Calculator" (header), "Unpin from taskbar", "Uninstall", "**Keep on top**", "Close window". Calculator (Standard mode) shows a coral "=" key and memory row MC MR M+ M- MS. |
| 3:50–3:53 | `WINDOWS` "It stays there while you work behind it." |
| 3:54 | A translucent window-switcher overlay (Alt+Tab-like, heavily blurred). |
| 3:55–4:02 | `SHORTCUTS` "Win + 1, 2, 3 jumps straight to your dock apps." Calculator, Files and Notepad are toggled in turn. |
| 4:03–4:07 | `FULL SCREEN` "Full screen for any app." Files goes full screen; the top bar and dock disappear. |
| 4:08–4:12 | `FULL SCREEN` "Move to the top to exit." Hovering the top edge reveals a **macOS-style title strip**: red/yellow/green traffic lights at the top-left, a green pill button ("Exit Full Screen", approx.), and a centered title "Files". Exiting brings back the top bar and dock. |
| 4:13–4:19 | `SHORTCUTS` "Win + X opens a quick menu of tools." A dark menu next to the dock lists: Installed apps, Power options, System, Drivers, Network connections, Disk management, Terminal, Task Manager, Settings, File Explorer, Search, Turn off or sign out >, Desktop. Choosing Task Manager opens it: a "Type a name or PID to search" field, Processes page, and buttons "Run new task", "End task", "Efficiency mode", "View". |
| 4:20–4:25 | `DESKTOPS` "More desktops when you need more room." A horizontal slide transition moves between virtual desktops (Files on one, empty on the other). |
| 4:26–4:29 | `DESKTOPS` "Task View shows them all." A top strip shows thumbnails "Desktop 1" and "Desktop 2" (active, coral border), a "+" tile and a "Search..." field. The current desktop is scaled down below. |
| 4:30–4:35 | `WINDOWS` "Minimise, with a little magic." Files minimises to the dock again with the genie effect. A "Files" tooltip appears, and a running dot sits under its icon. |
| 4:36–4:43 | `DESKTOP` "Desktop icons stay where you put them." Photo.jpg and Report.txt are dragged as a pair to a free position; the selection uses a coral-brown tint. |
| 4:44–4:50 | `DESKTOP` "F2 to rename." Todo.txt becomes Today.txt through an inline rename field. |
| 4:51–4:57 | `PERSONALISE` "Dock or taskbar. Your choice, switched live." The Settings Personalisation page has "Select a mode to apply" with thumbnails Light / Dark (selected) / Auto (approx.). Rows: *Background* ("FlowOS wallpaper: FlowOS Tide"), *Colours* ("Dark mode, Coral accent"). Under **Dock and taskbar** are two cards, "Dock and top bar" and "Taskbar". Further rows: "Auto-hide the dock" ("It comes back when you point at the bottom of the screen") [Off], and "Taskbar pins" ("Put back the apps the taskbar started with. Your apps stay installed.") [Reset]. Choosing **Taskbar** live-switches to a full-width bottom taskbar: Start logo and app icons on the left/center, system tray and a 2-line clock "04:22 / 11/24/2026" at the right, and no top bar. Switching back restores the floating dock and top bar. |
| 4:58–5:05 | `PERSONALISE` "Or hide it until you need it." Auto-hide the dock is switched [On]; the dock slides away and returns when the pointer reaches the bottom edge. |
| 5:06–5:09 | Title card: **"The one you missed most."** / "Right-click the desktop. It's there." |
| 5:10–5:15 | `DESKTOP` "Refresh. Right where you expect it." The desktop context menu lists: New folder, New text file, Paste, Sort by name, Refresh, (separator), Change wallpaper, Display settings, Personalise. Desktop items: Ideas.md, Report.txt, Shopping list.txt, Sunset.jpg. Refresh updates the Sunset.jpg thumbnail. |
| 5:16–5:21 | `DESKTOP` "And it does exactly what it says." A second Refresh makes a new file, Beach.jpg, appear. |
| 5:22–5:24 | Title card: **"Quiet when you need it."** / "Notifications that wait, and a calendar one click away." |
| 5:25–5:30 | `FOCUS` "Focus mode silences notifications." The **Control Center** drops from the top-right status icons as a dark translucent rounded panel. A 2×2 tile block holds Wi-Fi (On), Bluetooth (On), Dark mode (On), Focus (Off, then On "Do not disturb"); active tiles have coral circular icons. Below: "Display" slider (30%), "Sound" slider (Muted), four round buttons (Snip, Settings, Lock, Power), a "Desktops +" row, and "Battery 100% · fully charged". The top bar right reads "[wifi] [bt] [focus] [battery] 100%  Tue 24 Nov 03:32". |
| 5:31–5:35 | `FOCUS` "They wait for you in Control Center." Control Center now has a **Notifications** section with "Clear all", group "Other notifications" with ×, and the card "Team meeting / Starts in 10 minutes". |
| 5:36 | A notification banner appears at the top-left: "Reminders · now" / "Call Sam" / "About the weekend plans", with a "+2" badge. |
| 5:37–5:41 | `NOTIFICATIONS` "Notifications stack by app." In Control Center, the "Reminders" group shows "Show all 3" and ×. It expands ("Show less") to Call Sam / About the weekend plans and Lunch at 1 / Table for two booked. |
| 5:42–5:46 | `NOTIFICATIONS` "Swipe one away." "Lunch at 1" is swiped off; the group now reads "Show all 2". |
| 5:47–5:56 | `CALENDAR` "Click the clock for the calendar. Today is one click away." A compact calendar popover drops from the clock at the top-right: "Tuesday 24 November 2026", "November 2026" with ‹ › arrows, weeks starting Monday, and today (24) as a filled coral circle. Navigating to December 2026 and January 2027 reveals a "Today" chip, which jumps back. |
| 5:57–6:00 | Title card: **"Make it yours."** / "Change one colour and the whole desktop follows." |
| 6:01–6:05 | `COLOURS` "Hover a colour to preview it." Close-up of **Personalisation > Colours**. Rows: "Choose your mode / Changes the colours of FlowOS and your apps" [Dark ▾]; "Accent colour / Coral. Used for buttons, switches, selection and focus." with a swatch and chevron. Expanded "FlowOS colours" shows 11 swatches. Row 1: crimson, coral (✓ selected), peach/orange, pink, salmon-red, amber/yellow. Row 2: green, teal/mint, blue, violet/lavender, grey. Hover hints read "Peach. Click to use it.", "Teal. Click to use it.", "Violet. Click to use it." A "Preview" mini-desktop thumbnail re-tints live. Below: *Related* > Background. |
| 6:06–6:09 | `COLOURS` "Everything follows." The hint resets to "Coral (current)". |
| 6:10–6:13 | Title card: **"Under the hood."** / "Tools for when you want more control." |
| 6:14–6:15 | `TASK MANAGER` "Task Manager." The sidebar lists Processes, Performance, App history, Startup apps, Users, Details, Services, and Settings at the bottom. Columns: Name, Status, CPU, Memory, Disk (approx.). **Apps (5)**: Calculator, (blurred), Files (3), Notepad, Task Manager (2). **Background processes (69)**: (sd-pam), Accessibility, at-spi-bus-launcher, at-spi2-registryd, bash (2), catatonit, chrome_crashpad_handler, conmon, ... Notably, *catatonit* and *conmon* are Podman container processes. |
| 6:16–6:19 | `TASK MANAGER` "Efficiency mode calms a busy app." With Files selected, clicking "Efficiency mode" sets its Status column to "Efficiency mode". |
| 6:20–6:28 | `TASK MANAGER` "Choose what starts with your PC." The **Startup apps** page has columns Name, Publisher, Status, Startup impact, and buttons Enable / Disable. Rows: (blurred), "Clipboard history" by "Velotic Studios" (Enabled, then Disabled, then Enabled), and "Windows Security notification icon (Windows Engine ...)" by "Microsoft Corporation", Enabled, "13.0 MB". |
| 6:29–6:34 | `CALCULATOR` "Calculator has a programmer mode." Programmer mode, entering 25 then 255: HEX FF, DEC 255, OCT 377, BIN 1111 1111. It has a QWORD selector, "MS", "Bitwise ▾", "Bit shift ▾", and a hex keypad A–F. |
| 6:35–6:42 | `CALCULATOR` "And it counts the days between two dates." **Date calculation** mode, "Difference between dates". From "December 1, 2026" to "November 24, 2026" gives "1 week / 7 days". Changing To through a date-picker popover to "December 25, 2026" gives "3 weeks, 3 days / 24 days". |
| 6:43–6:46 | Title card: **"Office. Photoshop. AutoCAD."** / "Your Windows apps run in FlowOS's built-in Windows Engine." |
| 6:47–6:51 | Title card: **"Canva. VN. YouTube."** / "Your Android apps run in FlowOS's Android layer." |
| 6:52–6:55 | Title card: **"Mac apps, too."** / "macOS apps run on FlowOS as well." |
| 6:56–7:00 | Title card: **"And every Linux app."** / "From Debian, Fedora and more: they run on FlowOS." |
| 7:01–7:03 | Title card: **"No TPM needed."** |
| 7:04–7:07 | **"No ads. No telemetry."** ("No telemetry." in pink) / "FlowOS only contacts our servers for licence and update checks." |
| 7:08–7:10 | **"Anti-cheat games: coming in the January update."** ("January update." in pink) |
| 7:11–7:13 | **"Everything else: coming in December."** ("December." in pink) |
| 7:14–7:16 | Dark crimson radial-gradient card: **"$20 until 30 November."** |
| 7:17–7:24 | Logo (a circle split into four quadrants in crimson/pink shades), then **"FlowOS"** / "Early access opens in December. $20 until 30 November. $25 after that." A pill button reads "flowos.veloticstudios.com" (crimson gradient with glow). |
| 7:25 | Black. |

### Keyboard shortcuts shown
- **Super + Space**: command bar.
- **> command**: run in a terminal from the command bar.
- **Win + V**: clipboard history.
- **Win + . (period)**: emoji picker.
- **F5** in Notepad: insert time and date.
- **Ctrl + H** in Notepad: find and replace.
- **Win + Shift + S**: Snip.
- **Space**: Quick Look in Files.
- **Middle-click**: close a tab.
- **Ctrl + Z** in Files: undo a delete.
- **Shift + Del**: delete for good.
- **Alt + Enter**: Properties.
- **F2**: rename (Files and desktop).
- **Alt + P**: details/preview pane.
- **Win + 1/2/3**: dock apps by position.
- **Win + X**: power-user menu.
- **Delete**: move to Trash.
- **Ctrl + X / Ctrl + C**: cut / copy.
- **Enter**: open; in Start, Enter also copies an answer.
- Implied: Alt+Tab switcher (3:54), and Task View (button in the dock).

---

## 2. Visual design spec

**Overall.** The look is dark by default: Windows 11 layout conventions combined with a macOS-like top bar and dock, and a single warm accent. Surfaces are deep blue-charcoal and translucent with background blur. Corners are generously rounded and spacing is airy and minimal.

**Top bar (in "Dock and top bar" mode).**
- Full width, thin (about 24–28 px at 1080p), dark and semi-transparent (wallpaper faintly visible).
- **Left:** the small FlowOS logo (pink/crimson quadrant circle), then the **active app name** in muted small text ("Desktop", "Terminal", "Settings", "Files", "Notepad", "Snip", "Windows app", "Task Manager", "Calculator"). This is a macOS-style global app label. No global menus appear.
- **Right:** small monochrome status icons (Wi-Fi, Bluetooth, volume, focus/notifications; a pink Windows-engine indicator appears when Windows apps run), battery "100%", then date and time "Tue 24 Nov 04:04".
- Clicking the status icons opens Control Center; clicking the clock opens the calendar.
- In Taskbar mode the top bar disappears.

**Dock.**
- Floating, centered at the bottom with a small gap above the screen edge. It is compact: icons about 22–28 px with small padding, which is smaller than a macOS dock.
- Shape: a rounded rectangle/pill with a dark translucent background, a subtle border and blur. When a window is maximised the dock still floats over the wallpaper strip.
- Items, left to right (approx.): FlowOS Start logo (pink), Search (magnifier), Task View (overlapping squares), Files (pink folder), Notepad (yellow), Calculator, Task Manager, Settings (gear, often hidden), Store or Android (approx.), and Google Chrome (multicolor).
- Running apps that are not pinned are appended at the right after a gap (Windows Notepad, Snip, Paint).
- Running indicator: a small dot or short bar under the icon. Hover shows a dark tooltip with the app name.
- The right-click menu has a header (app name), "Unpin from taskbar", "Uninstall", "Keep on top" and "Close window".
- Auto-hide is optional. Minimising uses a **genie/magic-lamp** animation into the icon.

**Taskbar mode (alternative).** A full-width bottom bar in the same dark translucent style. Start and app icons start toward the left/center, and the tray plus a 2-line time/date sit at the right ("04:22 / 11/24/2026"). It is a Windows 11-style taskbar.

**Start menu.**
- A centered floating panel above the dock, tall (about 60% of screen height) and about 330–420 px wide. Dark translucent with rounded corners of about 12–16 px.
- Top: a rounded search field with a magnifier icon ("Search apps, files and the web") and an accent-colored focus ring.
- "Pinned" header with a pill button "All apps >". Pinned apps sit in a 6-column grid with labels.
- "Recommended" header with the empty state "Files you open will show up here."
- While typing, the grid becomes "Best matches" cards: an icon tile, a bold title, a subtitle with the hint "Enter to copy", and an Enter glyph at the right. The selected card is tinted coral-brown.

**Command bar.** A smaller floating launcher (about 400 px wide) in the upper-middle of the screen, in a style matching Start. It has a search field with an "Esc" chip and a list of results with icon, title and subtitle. A ">" prefix switches it into run-command mode.

**Control Center.**
- Drops from the top-right, about 300 px wide, dark translucent, rounded about 12 px.
- 2×2 toggle tiles (Wi-Fi, Bluetooth, Dark mode, Focus) with a round coral icon and a title over a status line.
- Display and Sound pill sliders with value labels at the right ("30%", "Muted").
- A row of 4 round icon buttons: Snip, Settings, Lock, Power.
- A "Desktops" row with "+".
- An inline "Notifications" section with "Clear all", app groups with "Show all N / Show less" and ×, and swipe-to-dismiss cards.
- Footer: "Battery 100% · fully charged".

**Notifications.** A rounded dark banner card at the top-left with an app icon, "App · now", a bold title, a body line, and a "+N" stack badge. Notifications are grouped by app.

**OSD / "island".** A small rounded dark pill at the **top-center**, under the top bar, used for system feedback ("Background changed / Aurora.jpg"). The video shows no physical notch or dynamic island beyond this pill.

**Calendar.** A compact popover at the top-right: a header with the full date, month and ‹ › arrows, a Monday-first grid, today as a filled coral circle, and a "Today" chip when navigated away.

**Window decorations.**
- **Windows-style** controls at the **top-right**: minimise (–), maximise (□) and close (×) as small, flat, monochrome square-ish buttons.
- Title text sits at the top-left with a small app icon, in the format "Untitled - Notepad".
- Apps use **client-side tab strips** (Files, Notepad) directly under or merged with the titlebar.
- Windows have a thin 1 px light border and a soft shadow, with corner radius about 8–10 px.
- In full screen, a macOS-like strip with **traffic lights** appears on hover at the top edge.
- Windows-engine apps keep their native Win11 titlebars.

**Blur and transparency.** Shell surfaces (top bar, dock, Start, command bar, Control Center, menus, clipboard/emoji panel, notifications) are dark with about 70–85% opacity plus a strong background blur. Context menus are dark, rounded about 8 px, with icons, right-aligned shortcut hints, and separators.

**Corner radius.**
- Windows: about 8–10 px.
- Popups and panels: about 12–16 px.
- Buttons, inputs and selection highlights: about 6–8 px.
- Pills (dock, OSD, end-card button): fully rounded.

**Colors.**
- Window and app background: about #161B22 / #1A1F27 (dark blue-charcoal). Sidebars are slightly darker; cards slightly lighter (about #232934).
- Text: off-white about #E6E8EB. Secondary text: grey about #8B93A1.
- **Accent "Coral"**: about #F2735F / #F0705A. It is used for switches, primary buttons ([+ New], [Open], "="), the selected sidebar item tint, focus rings, the today circle, the active tab underline and find-match highlights.
- Selection fill: coral at low alpha over dark, which reads as a brownish-maroon (about #4A2B2E).
- Brand crimson/pink about #E0245E to #F43F6E: logo, end card, folder icons (folders are pink/magenta gradient icons).
- Accent palette (11): Crimson, Coral (default), Peach, Pink, Salmon/Red, Amber, Green, Teal, Blue, Violet, Grey.

**Typography.**
- Shell and app UI: a clean neo-grotesk sans (Inter or Segoe UI-like) at small sizes, with bold section headers (for example "Personalisation > Colours" breadcrumb, large semibold).
- Notepad editor: a monospace face.
- Marketing captions: a geometric rounded sans (Urbanist or Outfit style).

**Icon style.**
- Colorful, glossy, rounded-square "squircle" app icons with soft gradients: pink Files folder, yellow Notepad pad, dark Calculator, grey gear, pink Snip, green Android, orange Drivers, peach Welcome.
- Folder icons are pink/magenta. Document icons are white sheets with a small colored badge.
- Toolbar and sidebar glyphs are thin monochrome line icons (Fluent/Lucide-like).

**Wallpapers.**
- Default "FlowOS Tide": 5–6 layered smooth waves running from deep navy at the top to aqua/turquoise at the bottom, with faint light rims on each wave edge (paper-cut style).
- Others in Pictures: Aurora (pale mint/white soft gradient), Drift (pale blue), Pebble (soft green 3D pebbles), Tide.
- Wallpaper can be set from the Files context menu, the desktop context menu ("Change wallpaper"), or Settings > Background.

**Light/dark.** Dark mode is shown throughout, but the mode picker has Light / Dark / Auto, and the Control Center has a Dark mode tile. Windows-engine apps render in their own light Win11 theme.

**Motion.**
- Genie minimise.
- Horizontal slide between desktops.
- Fade and scale for popups.
- Live accent preview on hover.
- The dock slides in and out when auto-hidden.

---

## 3. Features and how to build them on Arch/KDE Plasma 6 (Wayland)

Evidence that FlowOS itself is built on KDE: the `top` output shows **kwin_wayland** and **konsole**, the command bar lists **Alacritty**, Task Manager shows **conmon/catatonit** (Podman, so likely distrobox for Debian/Fedora apps) and **chrome_crashpad_handler**. The "Clipboard history" startup item's publisher is "Velotic Studios", which suggests a custom clipboard daemon or front-end.

| # | Feature (as shown) | Linux/KDE implementation |
|---|---|---|
| 1 | Floating top bar with logo, active app name, tray, battery, date/time | Plasma top panel (floating, translucent). Kickoff or a custom logo button. The "Window Title" applet (e.g. `plasma6-applets-window-title`) for the app name. System Tray and Digital Clock with the custom format "ddd d MMM HH:mm". |
| 2 | Floating centered dock with running indicators, tooltips, pin/unpin, genie minimise | A Plasma floating bottom panel with the Icons-only Task Manager, centered with spacers, and "Fit content" width. Alternatively Latte-dock successor forks, or the **Plasma "Dock" panel mode** in Plasma 6. Genie effect: a KWin effect (e.g. `kwin-effects-magic-lamp`, built in as "Magic Lamp"). |
| 3 | Dock or Taskbar mode, switched live, plus Taskbar pins reset | Two saved panel layouts applied with Plasma **Global Themes / Look-and-Feel layout scripts** (`plasma-apply-lookandfeel`, or a `qdbus org.kde.plasmashell /PlasmaShell evaluateScript` layout JS). Expose them as a custom KCM page. |
| 4 | Auto-hide dock | Panel visibility "Auto Hide" or "Dodge Windows" (panel config, scriptable). |
| 5 | Start menu with search, Pinned grid, All apps, Recommended, inline answers | A customised **Kickoff** or a QML plasmoid (forks such as "Menu 11" or "Tiled Menu"). The search backend is **KRunner/Milou** runners: Applications, Recent Documents/Baloo, Web Shortcuts, **Unit Converter**, **Calculator (Qalculate)**, and a Currency runner. Recommended = KActivities recent files. |
| 6 | Unit, currency ("rate of 2026-11-23") and math answers with "Enter to copy" | KRunner Unit Converter runner (KUnitConversion includes currency via ECB rates) and the Calculator runner (libqalculate). Enter copies the result to the clipboard (default KRunner behaviour for these runners). |
| 7 | Command bar (Super+Space) with apps, settings and web | **KRunner** with a custom theme and a Meta+Space shortcut (set in kglobalshortcuts). Plasma 6 KRunner already floats in mid-screen. Alternatives: Ulauncher, Albert, or a custom QML launcher. |
| 8 | ">" prefix runs a command in a terminal | KRunner **Command Line / Shell runner** (prefix configurable; a "Run in Terminal" action exists). Or a small custom runner (KRunner D-Bus runner in Python) mapping `>cmd` to `konsole -e cmd`. |
| 9 | Settings app with sidebar, search box and search results with breadcrumbs | **KDE System Settings** (KCMs, with built-in search and keyword matching), restyled. For a Win11-like IA, use a custom Kirigami settings shell embedding KCMs (`kcmshell6`) under custom categories: System, Bluetooth & devices, Network & internet, Personalisation, Apps, Accounts, Time & language, App support, Update & drivers. |
| 10 | Mouse & touchpad page (primary button, pointer speed, scroll speed, reverse scrolling, tap to click, scroll direction) | `kcm_mouse` and `kcm_touchpad` (libinput via KWin). "Game controls" and "Mouse speed for aiming" suggest a gaming/controller page (Steam Input, `game-devices-udev`, `kcm_gamecontroller`, or custom). |
| 11 | Notepad: tabs, session restore without a save prompt, F5 time/date, Ctrl+H find/replace, status bar (Ln/Col, chars, zoom, LF, UTF-8) | **KWrite/Kate** (tabs, session restore and an inline search/replace bar exist; "Insert Date/Time" can be bound to F5 through a snippet or script). Lighter options: a custom Qt/Kirigami notepad, or **gnome-text-editor** (autosaves unsaved buffers natively). For the Win11 feel, a small custom QML app is easiest. |
| 12 | Clipboard history (Win+V) with pin, delete, Clear all | **Klipper** (Plasma 6 clipboard history popup on Meta+V, with pin "keep" and remove). Restyle it, or write a custom panel combining Klipper's D-Bus/history with an emoji tab. |
| 13 | Emoji picker (Win+.) with search and categories | **Plasma Emoji Selector** (`plasma-emojier`, default Meta+. shortcut), with **Noto Color Emoji** fonts. Merge it with the clipboard into one tabbed panel to match the video. |
| 14 | Snip (Win+Shift+S): area/window/full/freeform, delay, annotate, copy and auto-save to Pictures/Screenshots | **Spectacle** (Plasma 6 has rectangular region, annotation, auto-copy and auto-save, with the save location set to ~/Pictures/Screenshots). Bind Meta+Shift+S to `spectacle -r`. Alternatives: Flameshot or Satty. |
| 15 | Files: tabs (drag to reorder, middle-click close), Home page with Quick access and Recent, breadcrumbs, New menu, Sort, View, Details pane, storage bar | **Dolphin** (tabs, middle-click close, information panel F11, places panel, free-space bar in the status bar). The Home dashboard with greeting and Quick access needs a custom view or a Dolphin fork. A custom Qt file manager is possible but costly. |
| 16 | Quick Look on Space | Dolphin has no Space preview built in. Use **Kiview** or a "quick look" service menu (e.g. `kiview`, `sushi`-like) bound to Space through a Dolphin plugin, or a custom previewer using KIO + KImageFormats + Okular parts. |
| 17 | Ctrl+Z undo of delete with an "Undone" toast | Dolphin/KIO **FileUndoManager** supports Ctrl+Z undo of a trash move. The toast needs a custom in-app message (Dolphin shows an inline message bar). |
| 18 | Trash view with Put back, Delete for good and Empty Trash, plus an empty state | KIO `trash:/` in Dolphin (Restore, Delete, Empty Trash actions exist). Relabel the actions. |
| 19 | Compress to ZIP and Extract here in the context menu | **Ark** Dolphin service menus (`ark` "Compress > Here (as ZIP)", "Extract > Extract archive here"). |
| 20 | Pinned section by dropping a folder into the sidebar | Dolphin Places panel (drag a folder to add it). Rename the section to "Pinned". |
| 21 | Alt+P details pane with the first lines of a text file | Dolphin **Information Panel** (F11) with previews enabled (text thumbnails via `kdegraphics-thumbnailers` / `ffmpegthumbs`). Rebind it to Alt+P. |
| 22 | "Set as desktop background" from Files with an OSD confirmation | A Dolphin service menu calling `plasma-apply-wallpaperimage %f`, plus an OSD through `qdbus org.kde.plasmashell /org/kde/osdService` or `notify-send`. |
| 23 | Windows apps (Win11 Notepad, Microsoft Store, Paint) with clipboard sharing; a "Windows Engine" | This video almost certainly shows a **Windows VM integrated as seamless windows**, which is a **WinApps/WinBoat-style** approach: a Windows VM in KVM/QEMU or Docker with RemoteApp over FreeRDP (`xfreerdp /app`), shared clipboard and per-app windows. Evidence: genuine Store, Copilot+ badges, and a "Windows Security notification icon (Windows Engine...)" startup item. For gaming and simple apps: **Wine/Proton** via **Bottles**, **Lutris**, Steam Proton or `umu-launcher`. Recommended: Proton/Wine for games and WinBoat/WinApps for Office/Adobe/Store apps. |
| 24 | Android apps ("Android apps" in Start, `.apk` install) | **Waydroid** (LXC Android on Wayland; multi-window mode; GApps or microG optional). Add an "Android apps" launcher plus an APK install handler (`waydroid app install`). |
| 25 | Mac apps | No practical native method. Darling is experimental and supports CLI tools only; macOS in a VM (OSX-KVM/Docker-OSX) carries licensing problems. Best omitted or marketed carefully. |
| 26 | Every Linux app "from Debian, Fedora and more" | **Distrobox** with **Podman** (matches conmon/catatonit in Task Manager), with app export to the menu (`distrobox-export`). Also Flatpak/Flathub and the AUR. |
| 27 | Keep window on top from the dock menu | KWin "Keep Above Others" (window rule or action). Add it to the Task Manager applet context menu through a fork or a KWin script; it is natively in the Alt+F3 window menu. |
| 28 | Win+1/2/3 to launch or focus dock apps | Plasma Task Manager supports Meta+1..9 natively ("Activate Task Manager Entry N"). |
| 29 | Win+X quick tools menu | A custom menu, e.g. a KRunner-like QML popup or `kdialog --menu`. Simpler: a small QML plasmoid bound to Meta+X listing Installed apps (Discover), Power options (kcm_powerdevilprofilesconfig), System (kinfocenter), Drivers (custom driver manager, e.g. `mhwd`/`nvidia` helper), Network connections, Disk management (**KDE Partition Manager**), Terminal (Konsole), Task Manager, Settings, File Explorer (Dolphin), Search (KRunner), Shut down/Sign out (ksmserver logout), Desktop (Peek at Desktop / Show Desktop). |
| 30 | Alt+Tab switcher | KWin Task Switcher (e.g. "Thumbnail Grid" or a custom QML switcher). |
| 31 | Full screen for any app with a hover top strip (traffic lights, Exit Full Screen) | KWin fullscreen (bind a key or the window menu). The hover reveal strip needs a custom KWin script/effect or a decoration that shows on hover. Optional. |
| 32 | Virtual desktops with slide transition; Task View with desktop thumbnails, "+" and search | KWin Virtual Desktops plus the **Slide** effect. **Overview** effect (Meta+W / Meta+Tab) has a desktop bar with "+" and search; enable "Show desktop bar". The Task View dock button triggers Overview. |
| 33 | Desktop icons with free placement and persistence; F2 rename | Plasma **Folder View** desktop containment (free arrangement with locked positions, inline F2 rename). |
| 34 | Desktop right-click: New folder, New text file, Paste, Sort by name, Refresh, Change wallpaper, Display settings, Personalise | Folder View context menu: Create New, Paste, Sort by, **Refresh**, Configure Desktop and Wallpaper, plus extra actions. Trim and rename the entries through a custom desktop containment config or by patching the Folder View QML. |
| 35 | Control Center: Wi-Fi, Bluetooth, Dark mode, Focus tiles, brightness and volume sliders, Snip/Settings/Lock/Power buttons, Desktops, Battery, embedded notifications | Plasma System Tray already provides Network, Bluetooth, Brightness, Audio, Battery and Notifications applets separately. To combine them, use a custom plasmoid, e.g. **"KDE Control Centre" / "Control Centre" plasmoids** (store.kde.org), or write one with Plasma's QML data sources (NetworkManagerQt, BluezQt, PowerDevil, PulseAudioQt, notification model). Dark mode toggle: `plasma-apply-colorscheme` / `plasma-apply-lookandfeel`. |
| 36 | Focus mode (Do not disturb) that holds notifications | Plasma Notifications **Do Not Disturb** (notifications are kept in history). |
| 37 | Notification banners, per-app grouping with Show all/Show less, swipe to dismiss, Clear all | Plasma notification server (`plasmashell`) groups by app and has "Clear all". Banner position is configurable (top-left as shown, or top-center). Swipe to dismiss works natively on touch; mouse drag needs QML customization. |
| 38 | Clock-click calendar with month navigation and Today | Digital Clock applet calendar popup (Monday-first by locale, with a "Today" button). Restyle it compactly. |
| 39 | Accent colour picker (11 swatches) with hover preview and global follow | Plasma colour schemes with the **accent colour** option (Plasma 6 supports a custom accent applied to Breeze/Kvantum). Build a custom KCM page with a preset palette that calls `plasma-apply-colorscheme --accent-color #hex`. Hover preview needs a custom KCM. |
| 40 | Light / Dark / Auto mode | Look-and-feel switching. Plasma 6.x supports **automatic day/night theme switching**; alternatively use **Koi**. |
| 41 | Night light | KWin Night Light (`kcm_nightlight`). |
| 42 | Task Manager: Processes with Apps/Background groups, Performance, App history, Startup apps (Enable/Disable, impact), Users, Details, Services, Run new task, End task, **Efficiency mode** | **Plasma System Monitor** covers Processes, Performance and History, and is customizable. Startup apps: `kcm_autostart` / systemd user units. Services: systemd (`systemctl`); use a custom page or `systemdgenie`. Efficiency mode: `renice` + `ionice`, or systemd `CPUWeight=` / `cgroup` cpu.max on the app scope (Plasma launches apps in their own `app-*.scope`, so `systemctl --user set-property app-xyz.scope CPUWeight=20`). Users: `loginctl`. For a Win11 look, a custom Kirigami frontend is more faithful. |
| 43 | Calculator: Standard, Programmer (HEX/DEC/OCT/BIN, QWORD, bitwise, bit shift) and Date calculation | **KCalc** (has a numeral-system/programmer mode, but no date difference). **Qalculate!** (`qalculate-qt`) handles programmer mode, units and currencies, and dates; GNOME Calculator also has a programmer mode. A custom Win11-style calculator is required for the exact UI with date calculation; the "Calculator" description in the command bar mentions a unit converter too. |
| 44 | Terminal | **Konsole** (seen in `top`) and/or Alacritty (listed in the command bar). |
| 45 | Drivers app (pinned "Drivers") and "Update & drivers" settings | A custom driver manager (NVIDIA/AMD/Intel detection; Manjaro's `mhwd` or CachyOS's `chwd` are good references), plus **Discover**, `pacman`/`paru`, or a custom update KCM. |
| 46 | Welcome app | A first-run welcome app (examples: `cachyos-hello`, `garuda-welcome`, `eos-welcome`); write your own. |
| 47 | "Installed apps", "Uninstall" from the dock, and "App support" settings | Discover / Flatpak / `pacman` frontends, with a Plasma Task Manager context action calling the uninstaller. "App support" is likely the Windows/Android/Linux compatibility layers' settings page (custom). |
| 48 | Window decorations (Win-style buttons on the right, rounded corners) | Breeze decoration or **Klassy** (button shapes, rounded corners), plus a **KWin rounded-corners effect** (`kwin-effect-rounded-corners` / "ShapeCorners"). |
| 49 | Shell blur and translucency | KWin **Blur** effect with a Plasma theme with translucent backgrounds (custom Plasma Style SVG), and Kvantum for app transparency if desired. Plasma 6 floating panels. |
| 50 | Session restore / remembered state | Plasma session management ("Restore last session"); per-app (Kate sessions). |
| 51 | No TPM requirement, no telemetry ("only licence and update checks") | Arch has no TPM requirement. Disable KDE **KUserFeedback** by default, ship no telemetry, and limit network calls to the update mirrors. |
| 52 | Anti-cheat games (promised for January) | Proton supports Easy Anti-Cheat and BattlEye when developers enable them. Kernel-level anti-cheat (Vanguard, etc.) will not work; set expectations accordingly. Gaming stack: Steam + Proton-GE, Lutris, Heroic, GameMode, MangoHud, Gamescope, `linux-zen` or the CachyOS kernel, Mesa/NVIDIA drivers, `game-devices-udev`. |
| 53 | Branding and boot | Plymouth theme, SDDM theme (matching dark/coral), GRUB/systemd-boot theme, Calamares installer with matching branding. Use your own logo; do not reuse FlowOS branding. |

### Default app roster to recreate (from Start "Pinned" and the dock)
Files (Dolphin), Notepad (KWrite or custom), Calculator (custom or Qalculate), Settings (System Settings), Task Manager (Plasma System Monitor or custom), Android apps (Waydroid launcher), Terminal (Konsole), Snip (Spectacle), Drivers (custom), Welcome (custom). The dock also holds Search (KRunner), Task View (Overview) and Google Chrome (or Firefox/Chromium).

### Notes for the gaming distro
- Keep the coral-accent dark theme, but rename the accent palette and use your own logo and wallpapers. The layered-wave "Tide"-style wallpaper is easy to recreate as an SVG.
- Ship the "Dock and top bar" / "Taskbar" toggle as a first-boot choice in the Welcome app.
- Fit gaming into the same Settings IA: "Game controls" and "Mouse speed for aiming" already appear in FlowOS settings search. Add Steam/Proton, GameMode toggles, MangoHud overlay and controller pages under "Bluetooth & devices" and "Apps".
