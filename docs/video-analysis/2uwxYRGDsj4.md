# FlowOS demo, frame-by-frame analysis
Video: "This Isn't Windows (But It Runs Office and Adobe Apps)" (5:26), video id 2uwxYRGDsj4
Source: 37 contact sheets (sheet_000 to sheet_036) at 1 fps, all viewed. Small UI text was checked by cropping and upscaling the sheet cells (the crops are in `scratchpad\crops\`). Quoted text is exact where it was legible. "~" marks text that was only partly legible.

---

## 0. Key findings (TL;DR)

- **Windows apps run through a layer branded "Windows Engine".** No Wine, Proton, Bottles or CrossOver text appears anywhere. The evidence points to a **Windows VM with RemoteApp-style window streaming** (WinApps/WinBoat model: QEMU/dockur-windows + FreeRDP RemoteApp), not Wine:
  - **Genuine Windows 11 Notepad** is shown, with a tabbed UI, a Copilot icon and the status bar "Windows (CRLF)" / "UTF-8". That Notepad is a packaged Store app that does not run on Wine.
  - **Office 365 desktop apps** (Word/Excel/PowerPoint, with "AutoSave Off" and the sensitivity label "General\*") and **Photoshop 2026** run. Neither runs well on Wine today.
  - Character Map (charmap.exe) renders with ClearType, and Paint.NET 5.1.12 runs.
  - Launching shows a small "Windows Engine" window with "Opening Paint.NET..." and a progress bar. That looks like a VM/RDP session spinning up.
  - In search, Windows apps carry the subtitle "Windows app (runs in the Windows Engine)".
  - The installer tip reads ~"Double-click a Windows program [installer] to run it. FlowOS takes care of the rest." So .exe files are launched by double-click.
- **Android uses Waydroid explicitly.** The window title "Waydroid" is visible at 3:27. Apps open in separate windows (Waydroid multi-window mode), and back/home buttons appear in the host title bar. Google apps are present: Play Store in Launchpad and a Google search bar on the Waydroid home screen.
- **Android game key-mapping** is a host-side overlay with an editor toolbar ("Game controls | Tap | Joystick | Mouse aim | Repeat | Swipe | Remove | Cancel | Save"). Its toast reads "Game controls on. Alt frees the mouse, F12 turns them off, Win+Shift+G edits." It has a Settings page at "Apps > Key mapping".
- **Mac apps (captioned "EARLY PREVIEW · NOT FINISHED")** launch by double-clicking a `.dmg` in Files. A toast reads "Mac apps / Opening googlechrome.dmg / This can take a moment the first time." Each Mac window is drawn **inside** a host window and has its own macOS-style chrome: traffic lights, a centred title and an in-window macOS menu bar.
  - Firefox's app menu reads **"MozillaProject"** instead of "Firefox". That suggests a reimplemented AppKit or plist-reading runtime (Darling-like), not real macOS.
  - The runtime name is never shown.
- **The store is "Velotic Store"**, a Flathub front-end. Its sidebar footer reads ~"Free apps from Flathub and their makers, checked and kept in their own sandbox."
- **The installer** is a custom 7-step wizard: Network · Activate · Drive · You · Region · Software · Install. It requires a product key, needs no TPM, offers optional encryption, downloads the OS during install, and has Recommended and Minimal profiles. The Minimal profile is described as having "no see-through glass".
- **The desktop** is KDE-based and themed to look like Windows 11 plus macOS:
  - a thin translucent top bar with the active window title and a clock
  - a floating centred dock that also acts as a taskbar
  - a Win11-style Start menu
  - a full-screen macOS-style Launchpad
  - a tile-based Control Center
  - a "Dynamic Island" notification pill
  - a crimson/rose accent colour and Inter-like typography.

---

## 1. Timeline (mm:ss)

Mapping: sheet N, cell k (0 to 8) = second 9N+k.

### 0:00–0:05 Intro splash
- Dark near-black background with a radial maroon/crimson glow at top centre.
- Logo: a circle split into four quadrants by a cross gap, in two crimson/pink shades (lighter top-left and bottom-right, darker top-right and bottom-left).
- Text: **"Your apps."** (white, bold) **"On FlowOS."** (crimson/pink, bold). The font looks like Inter Bold/ExtraBold.
- 0:05: fades to a darkened waterfall wallpaper, which acts as the boot/login fade. The dock is already faintly visible.

### 0:06–0:13 Meet FlowOS: empty desktop
- Wallpaper: a mossy waterfall over a rocky pool (long exposure).
- Top bar: thin and translucent, picking up the wallpaper's colour. On the left are an orange/coral circle icon and the title **"Desktop"**. On the right are a display/notification icon, a network/volume icon and the clock **"Sun 8 Nov 17:50"**.
- Dock: a floating dark pill centred at the bottom. It holds a coral Start orb, Search (magnifier), Task view (overlapping rectangles), Files (yellow folder), Notepad, Calculator, Task Manager (chart window) and Settings (gear).
- Bottom-right corner: a separate small round **notification bell** button. In later scenes it shows a red badge.

### 0:14–0:21 Launchpad
- A full-screen overlay with the wallpaper heavily blurred (blue/teal smear), a small search pill at the top centre, and two page dots at the bottom (page 1 of 2).
- Grid of 11 columns × 5 rows of icons with small white labels. Page 1 reads row by row:
  1. Alacritty, Android apps, AnyDesk, Bitwig Studio, Brave, Calculator, Canva, Claude, Process Lasso, Proton VPN, REAPER (cut off)
  2. Contacts, Disks, Drivers, Dropbox, Easy Effects, F-Droid, ~fastviewer, Ferdium, Settings, Steam Link, (cut off, orange)
  3. Files, FileZilla, FL Cloud Plugins, FL Studio 2026, Gmail, Google Play Store, Ibus Preferences, Input Method, Vesktop, Video Player, "VN - Vi…"
  4. KDE System Settings, KeePassXC, Kodi, LMMS, LocalSend, MEGAsync, Messages, MetaEditor, Zoom Workplace, Zoom Workplace
  5. MetaTrader 5, "More…", NinjaTrader, "NinjaTrader (Safe…", Notepad, PDF Reader, PDFgear, Photos
- What this shows:
  - Native Linux apps (Alacritty, KDE System Settings, Kodi, LMMS, KeePassXC) are mixed with Windows apps (Process Lasso, FL Studio 2026, MetaTrader 5, MetaEditor, NinjaTrader, PDFgear) and Android apps (Gmail, Messages, Contacts, Google Play Store, F-Droid, Canva, VN).
  - "KDE System Settings" and "Ibus Preferences" confirm a KDE + IBus base.
  - Windows apps use a generic "window" placeholder icon (blue/white app window) when no icon was extracted, for example "fastviewer", "FL Cloud Plugins", "MetaEditor", "More…" and "Zoom Workplace".

### 0:22–0:26 Caption: "THE DESKTOP / Liquid glass"
- Wallpaper changes to a **misty pine forest with sun rays**.
- Caption style (used for every chapter): a lower-left rounded dark translucent card with a thin vertical crimson bar on the left. It has a small all-caps crimson kicker ("THE DESKTOP") above large bold white text ("Liquid glass").
- 0:24: the Start menu opens.

### 0:24–0:35 Start menu
- Win11-style centred panel above the dock, with dark tinted glass that lets the wallpaper show through.
- Search field: "Search apps, files and the web", with a thin crimson focus outline.
- "Pinned" heading with an **"All Apps ›"** pill button on the right.
- Pinned icons, two rows: **Files, Notepad, Calculator, Settings, Task Manager, Android apps** / **Terminal, Drivers, Welcome** (Welcome is a purple sparkle icon).
- "Recommended" heading, with "Files you open will show up here." centred below.
- Footer: a round avatar "T", the name "Test User", and a power icon on the right.
- 0:32: typing "calc" shows "Best matches":
  - **"Calculator"**, subtitle "Standard, scientific and programmer calculator, data calculation and unit converters"
  - **"Search the web for "calc"" / "Search the web"**, highlighted in crimson with an ↵ hint.
- 0:35: back to the Pinned view.

### 0:36–0:38 Forest desktop (idle)

### 0:39–0:51 Control Center (opened from the top-right of the top bar)
- Wallpaper: **turquoise alpine lake with snowy peaks** (Lake Jasna style).
- The panel is anchored under the top bar on the right. It is dark glass, about 230 px wide at 1080p, with rounded tiles. Layout:
  - Large tile pair (left): **Network / Ethernet** (crimson circle icon, active) and **Bluetooth / Not available** (grey).
  - Right column: **Dark Mode / On** (crimson icon) and **Focus / Off**.
  - **Sound** row showing "77%", with a wide white pill slider (speaker icon at left). It is dragged to about 90%, then back.
  - Four square buttons: **Snip**, **Settings**, **Lock**, **Power**.
  - **Desktops** row with chips **1 2 3 4**. The active one (1) is filled crimson.
- 0:46–0:47: Dark Mode is toggled off. The panel turns **light** (white frosted glass, dark text), and the dock and top bar also become light. It is then toggled back on.

### 0:52–0:58 Dynamic Island / notification
- Wallpaper: **purple/green aurora over a starry sky**.
- A wide pill/rounded-rect drops from the top centre. It is dark-purple translucent glass with a bell icon in a round well on the left. Text:
  - "Calendar · now" (small, muted)
  - **"Team sync in 10 minutes"** (bold)
  - "Design review, Room 2"
- The top bar is not visible during this shot. The island either replaces it or is shown fullscreen.

### 0:59–1:13 Files app, snapping, Notepad
- Wallpaper: an alpine lake (Seebensee-like) with a bright blue sky.
- **Files** window (title "Home"). It is a custom Explorer-like app, not standard Dolphin:
  - Light title bar with a folder icon, "Home", and min/max/close on the right. The body is dark.
  - Tab strip ("Home" × +). Back/forward/up/refresh buttons, a breadcrumb ("Home"), and "Search My files".
  - Command bar: "+ New ▾", cut/copy/paste/rename/share/delete icons, "Sort ▾", "View ▾", "…", "Details".
  - Sidebar: Home (selected, crimson-tinted). "Favourites": My files, Desktop, Documents, Downloads, Pictures, Music, Videos. "Drives": This computer, with a crimson usage bar and "19.7 GB free of 63.2 GB" (~). Trash.
  - Home page: **"Good afternoon, Test"**, "Sunday 8 November", "☆ Quick access" with large yellow folders (My files "Your own folder", Desktop, Documents, Downloads, Pictures, Music, Videos, each with the subtitle "My files"). "Recent" shows "Files you open will show up here." A status bar reads "7 items in Quick access".
- 1:01: Pictures shows **Nature** and **Screenshots**. 1:03: Nature shows thumbnails `nature-aurora-peaks.jpg`, `nature-aurora-trees.jpg`, `nature-coast-cliffs.jpg`, `nature-forest-rays.jpg`, `nature-glacial-lake.jpg`, `nature-turquoise-…`, `nature-waterfall.jpg`. These are the bundled wallpapers.
- 1:04: wallpaper changes to **aurora over pine silhouettes**, apparently set from Files.
- 1:05–1:06: the Files window is maximised, then **snapped to the left half**. A "Files" tooltip shows over the dock icon. Files Home also shows a "Drives" section with a circular usage ring for "This computer".
- 1:07–1:13: **Notepad** (FlowOS native, title "Untitled - Notepad", tabbed, File/Edit/View) opens on the right. Files and Notepad end up **tiled 50/50 (snap layout)**. The top bar shows "Notepad", and the Notepad dock icon gets a running indicator.

### 1:14–1:20 Launchpad again
- Coast-cliffs wallpaper (Shark Fin Cove style), then Launchpad (same grid). Fade at 1:20.

### 1:21–1:35 Caption "WINDOWS APPS / Microsoft Office": Word
- Caption: kicker ~"WINDOWS APPS" (blurry), title **"Microsoft Office"**. A brief grey glass variant of the card is shown.
- Microsoft Word (Office 365, light theme) is shown zoomed/cropped. The title row reads "…ocument1 - Word · ⛉ General\*" (sensitivity label) with a "Search" box. Tabs: References, Mailings, Review, View, Help. The styles gallery shows Normal, No Spacing, Heading, Heading 2, Title, Subtitle; then Find/Replace/Select and Dictate.
- Typed: **"Quarterly Plan"** (bold) and **"FlowOS runs Microsoft Word in its own window."**
- A dark strip at the very top is the FlowOS top bar.

### 1:36–1:43 Excel
- The FlowOS top bar (dark when maximised) shows a coral dot and **"Excel"**.
- Excel: "AutoSave Off", "Book3 - Excel · General\*", Home ribbon (Aptos Narrow 11, Wrap Text, Merge & Center, General, Conditional Formatting).
- Data typed: A1 "Month", B1 "Sales"; January 1200, February 1450, March 1800, Total **4450** (sum).

### 1:44–1:51 PowerPoint
- Full desktop visible. The top bar shows "PowerPoint" and the clock "Sun 8 Nov 13:03". The window is maximised with Windows-style min/max/close. The dock shows a PowerPoint running icon (red/orange P).
- Typed slide: **"Meet FlowOS"** / **"Your apps. One beautiful desktop."**

### 1:52–2:07 Caption "ADOBE / Photoshop"
- 1:52: dark fade/transition (a splash-like dim frame).
- **"Adobe Photoshop 2026"** appears in the top bar, with the clock "Sun 8 Nov 12:48". The window is maximised and the dock shows a "Ps" icon.
- File tab: "landscape.jpg @ 66.7% (RGB/8#)" (~). It shows a snowy mountain forest with a cloud inversion. A contextual task bar ("Pr…") floats below the canvas.
- A black brush stroke is drawn across the sky (1:59–2:01). The image is then converted to **grayscale** (2:03–2:05); it toggles colour and grayscale.
- Caption: kicker "ADOBE", title "Photoshop".

### 2:08–2:14 Caption "WINDOWS APPS / Everyday programs"
- Forest wallpaper, then the Start menu opens. Typing "paint" shows Best matches **"Paint.NET"**, subtitle **"Windows app (runs in the Windows Engine)"**, plus "Search the web for "paint"".

### 2:15 Windows Engine launch dialog
- A small floating window titled **"Windows Engine"** (green app icon, light title bar with min/max/close) with a dark body:
  - icon, **"Opening Paint.NET..."**, subtitle "Paint.NET", and a thin crimson progress bar.
- The top bar title reads "Windows Engine". An extra running indicator appears in the dock.

### 2:16–2:22 Paint.NET
- First a grey blank frame (the app is drawing). Then **"\*Untitled - Paint.NET 5.1.12"** in a non-maximised window with Windows 11-style caption buttons. The top bar reads "Paint.NET".
- Green brush strokes and a yellow circle are drawn. The History panel shows "New Image" and "Paintbrush" entries; Colors, Layers ("Background") and the status bar are visible.

### 2:23 Windows Engine: Notepad
- The date jumps to **"Mon 9 Nov 03:02"** (a different recording session). On the lake wallpaper, a Windows Engine window shows **"Opening Notepad..." / "Notepad"**.

### 2:24–2:32 Windows 11 Notepad (genuine)
- Tabbed Windows 11 Notepad: tab "Untitled", then "Weekend packing list"; menu File/Edit/View; Copilot and settings icons at the top right.
- Status bar: "Ln 1, Col 1 | 0 characters … 100% | Windows (CRLF) | UTF-8".
- Typed: "Weekend packing list", "- Water bottle", "- Rain ja…".
- The dock shows a blue Windows-style icon for the running app.

### 2:30–2:38 Character Map (charmap.exe)
- Waterfall wallpaper. A classic Win32 dialog "Character Map", Font: **Arial**, Help, a character grid, "Characters to copy :", Select, Copy, "Advanced view".
- Tooltips: **"U+00A9: Copyright Sign"**, **"U+00BD: Vulgar Fraction One Half"**. The magnified ° glyph is shown.
- Status line: "Keystroke: Alt+0169" / "Alt+0189" / "Alt+0176". The copy field builds up "©½°".

### 2:39–2:47 Caption "ANDROID APPS / In their own windows"
- Lake wallpaper. In the Start menu, "markor" gives the result **"Markor"** (with "↵") and "Search the web for "markor"". No subtitle is legible.

### 2:48–2:52 Markor (Android)
- The window is maximised and the FlowOS top bar becomes the app title bar. It holds the coral icon, **← back arrow**, title **"Markor"**, and on the right the window controls (– ▢ ✕), tray icons and the clock "Sun 8 Nov 18:23".
- Android UI: "QuickNote" with a toolbar (undo, save, view, search, ⋮), a Markdown formatting bar, and bottom navigation (Files, To-Do, QuickNote, More).
- The **Android soft keyboard** (AOSP/Gboard-style) is visible, with word suggestions "breadth | bread | breads".
- Typed: "Ideas for the weekend / hike by the lake / bake fresh bread".
- An Android nav "◀" is at the bottom. The dock shows the Markor icon.

### 2:53–2:58 Material Files (Android)
- The top bar reads "← Material Files". The app shows "Files / 13 folders", "Internal shared storage" (Root, "Add storage…", DCIM, Downloads, Movies, Music, Pictures, Screenshots, FTP server, Settings, About), and folders Alarms, Android, Audiobooks, DCIM, Documents, Download, Movies, Music, Notifications, Pictures.
- It navigates to "Internal shared storage › Documents" and shows the folder **"markor"**, so the Android apps share storage.

### 2:59–3:05 VN - Video Editor (Android)
- The top bar reads "VN - Video Editor". The app is in a light theme: a row of tools (BeatsClips, Text to Image, Enhance Portrait, Create Template, Upscale Image, Overlay, Stories), a big blue gradient **"New Project"** button, "Tutorials" ("Newbie tutorials and usage guides", "Template creation tutorial"), "Instagram Reels" and "Instagram Story Video" template rows.
- The dock icon reads "VN".

### 3:06–3:26 Caption "ANDROID GAMES · KEYBOARD AND MOUSE / Game controls": Subway Surfers
- New wallpaper: **Seebensee-like alpine lake** with a vivid blue sky. The clock reads "Mon 9 Nov 04:29".
- In the Start menu, "subway" gives the result **"Subway Surf"**.
- 3:13: the window titled "← Subway Surf" opens, showing the Subway Surfers splash in a **portrait 9:16 window centred on screen**, with black side fill.
- 3:14–3:26: gameplay, scores 000012 up to 000171. The view zooms in on the game. The side areas show a **blurred, stretched copy of the game** (a "blur fill" letterbox like a phone video in landscape). The dock is still visible at the bottom.

### 3:27–3:42 Waydroid home and key-mapping overlay
- 3:27: the top-bar title is **"Waydroid"** with ← and ⌂ (home) buttons. Shown is the full Android desktop (Waydroid full-UI mode):
  - teal wallpaper, clock widget **"12:07" / "Sun, Nov 8"**, a Google search bar, and icons for Canva and Free Fire MAX
  - a bottom dock with Contacts, Calendar, Photos (Gallery), Music, Assistant-like and Camera icons
  - Android nav buttons ◀ ● ■.
- 3:28: a toast/pill at the top centre reads **"Game controls on. Alt frees the mouse, F12 turns them off, Win+Shift+G edits."** (with a gamepad icon).
- **Overlay controls** appear as semi-transparent dark circles over the game:
  - a large **WASD joystick ring** (W top, A left, S bottom, D right)
  - a big **"Mouse aim"** circle
  - small round key chips: "F", "Right click", "Click", "Space", "Q", "E", "R", "C", "M" (near top-right), "H", and numbered "1" and "2" chips on the dock icons.
- 3:35–3:40: **edit mode**. A toolbar at the top centre reads **"Game controls | Tap | Joystick | Mouse aim | Repeat | Swipe | Remove | Cancel | Save"** (Save is crimson).
  - A new "Tap" button is dropped and the hint reads ~"Press a key, click a mouse button or turn the wheel. Esc cancels."
  - The new chip gets the label "H". The layout is saved and the toast is shown again (3:41–3:42).

### 3:43–3:50 Settings › Apps › Key mapping
- The Settings app is Win11-like: dark, with a crimson accent.
- Header: avatar "T", **"Test User" / "Local account · Administrator"**, and "Find a setting".
- Nav: System, Bluetooth & devices, Network & internet, Personalisation, **Apps** (selected), Accounts, Time & language, **Windows programs & Android**, Update & drivers. Each item has a crimson rounded-square icon.
- Breadcrumb: **"Apps › Key mapping"**
  - **Game controls**: "Play Android games with your keyboard and mouse". On (crimson toggle).
  - **Turn on when a game opens**: "Controls start by themselves for games that have them". On.
  - **Show keys on the game**: "Small labels over the game's buttons while you play". On.
  - **Mouse speed for aiming**: "How far the view turns when you move the mouse". Crimson slider.
  - **How to play**:
    - "Turn controls on or off": "Win+G, or F12 while you play"
    - "Use the mouse in menus": "Alt frees the mouse; press Alt again to aim"
    - "Change a game's controls": "Open the game, then press Win+Shift+G. Drag buttons onto the game and press a key for each."
  - **Games**: "Free Fire MAX" / "FlowOS layout". This is a shipped preset per game.
- The clock reads "Mon 9 Nov 02:40".

### 3:51–3:56 Caption "EARLY PREVIEW · NOT FINISHED / Mac apps and games"
- Forest wallpaper. Files is open at Downloads, which holds `Firefox 158.0.1.dmg` (~), `googlechrome.dmg` and `Maelstrom-4.0.2-macos.dmg`.
- **In this later build, the dock has a Windows-style tray at the right edge**: network and volume icons, a two-line clock "18:26 / 11/8/26", and a red notification badge. It looks like a dock/taskbar mode option.
- The Files title bar is dark in this build.

### 3:57–4:03 Chrome from .dmg
- Double-click on `googlechrome.dmg` raises a bottom-right toast: **"Mac apps" / "Opening googlechrome.dmg" / "This can take a moment the first time."**
- The top bar reads "Welcome to Google Chrome". A dialog "Welcome to Google Chrome" shows two checked options: "Make Google Chrome the default browser" and "Automatically send usage statistics and crash reports to Google". It has a "Learn more" link and an OK button.
- 4:01: the window has the outer host title bar "Google Chrome" (with ⎯ ▢ ✕) and **inside it a macOS-style frame**: red/yellow/green traffic lights, a centred title "Google Chrome", and an in-window **menu bar "Chrome File Edit View History Bookmarks Profiles Tab Window Help"**.
- A blue loading circle, then **"Sign in to Chrome" / "Get additional features"** (All your devices / Stronger security / Back up your stuff; "Stay signed out" / "Sign in").

### 4:04–4:08 Firefox from .dmg
- Coast wallpaper. The outer host title bar reads "Welcome to Firefox"; the inner Mac frame title reads "Mozilla Firefox". The inner menu bar reads **"MozillaProject File Edit View History Bookmarks Tools Window Help"**.
- Dialog: "Welcome to Firefox" / "By continuing, you agree to the Firefox Terms of Use and Privacy Notice…" with a purple "Continue" button.

### 4:09–4:23 Maelstrom (classic Mac/SDL game)
- Double-click on `Maelstrom-4.0.2-macos.dmg` shows the toast "Mac apps / Opening Maelstrom-4.0.2-macos.dmg / This can take a moment the first time."
- The window shows the outer host title "Maelstrom" and an inner Mac frame with traffic lights, title "Maelstrom" and a menu bar with only **"Window"**.
- Sequence: splash ("Loading..."), then the main menu ("by Andrew Welch / Port to SDL by Sam Lantinga / Art by Ian Gilman & Mark Lewis", 4.0.2, "©1992-4 Ambrosia Software, Inc."), then gameplay.

### 4:24–4:36 Rocks'n'Diamonds, then more Maelstrom
- `rocksndiamonds-4.4.2.4…` appears in Downloads. The top bar reads **"Rocks'n'Diamonds 4.4.2.4 (100 %)"**. The same nested Mac frame is used, with only a "Window" menu. The title screen shows "EMERALDS / DIAMONDS / PEARLS / CRYSTALS".
- 4:30–4:36: Maelstrom gameplay (status bar "Score: 50 Shield … Wave 1 Lives 2 Bonus 1870").

### 4:37–4:50 Caption "VELOTIC STORE / Thousands of apps"
- Wallpaper: mossy waterfall and river stones. The top bar reads "Velotic Store".
- Store window:
  - Sidebar: logo "Velotic / Store", **Home** (crimson pill, selected), **Browse**, **Installed**. Footer: ~"Free apps from Flathub and their makers, checked and kept in their own sandbox."
  - "Search apps" bar.
  - Hero card (dark crimson with 3D app tiles): kicker "Apps", **"Apps for everything you do"**, "Free apps from checked sources, kept up to date in one place." Feature bullets: **Checked sources**, **Always up to date**, **One click** ("No installers to find"), **Free**.
  - Category chips: Popular, Trending, Games, Office, Photos and design, Music and video, Internet, Education, Coding, Tools.
  - **"Popular apps"** ("The ones most people install first", "See all ›"): cards for Google Chrome, Discord, Spotify and VLC, each with a crimson "↓ Install" button.
  - **"Essentials (39)"** (~"Five seconds, then install them together"), with list rows such as Google Chrome and Firefox and round install buttons.
- 4:41: search "audacity" gives **"Results for "audacity""**: Audacity, Tenacity, ~MusVisDb, ~Press, audmes, SoundConverter, Soundux, Dalri, MuseAmp, pxtone collab, MediaHarbor, BinauralPlayer. All are Flathub apps.
- Install flow: the Audacity card shows inline "Installing 2%" with a progress line, and a bottom banner reads **"Installing apps. You can keep browsing"**. When done, a green dot appears on the card and the button becomes a grey **"Open"** button.

### 4:51–5:13 Caption "EASY TO INSTALL / No TPM needed": Installer
- Background: abstract **pink/crimson/maroon flowing waves** (macOS-style abstract art). A centred dark rounded card holds the wizard, with a gear icon at the top right.
- A step indicator sits at the top of the card: **Network · Activate · Drive · You · Region · Software · Install**. The current step is a crimson pill; done steps get crimson checks.
1. **Welcome**: logo, **"Welcome to FlowOS"**, "Let's put FlowOS on your computer. You'll need your product key and an internet connection. FlowOS downloads its newest version while it installs. You can keep Windows and all your files". Button **"→ Install FlowOS"**. Bottom-left toggle: **"Advanced mode"** / "Show partitions and technical details".
2. **Drive**: **"Where should FlowOS go?"**, "Pick a drive. Your files stay safe unless you choose to replace everything." Card "Disk 1 · Drive" / "64 GB Drive · empty" with a usage bar. "How should FlowOS use Disk 1 · Drive?" with the radio **"Use this empty drive"** [badge "Recommended"] / "This drive is empty, so FlowOS can use all of it." Buttons Back / **→ Continue**.
3. **Software**: **"How much should FlowOS install?"** / "Either way you can add or remove apps any time later."
   - **Recommended** [badge "Best for most people"]: "Ready to use, like Windows: photos, documents, videos, music, archives and disks open straight away. You choose your web browser, and Windows or Android app support, when you first sign in."
   - **Minimal**: "Just the essentials: the desktop, Files, Settings, Notepad and Calculator, with a lighter look (no see-through glass). Over 1 GB smaller and uses the least memory, for small or older computers."
4. **Ready to install**: "Here's what will happen. Nothing changes until you press Install now."
   - "FlowOS uses all of Disk 1 · Drive (64 GB). It's empty, so nothing is lost."
   - "Recommended FlowOS, ready to use: everyday apps and Velotic Store included."
   - "Windows and Android app support can be added when you first sign in."
   - "Your account "alex" is created."
   - Checkbox **"Encrypt this drive"**: "Keeps your files safe if the computer is lost or stolen. This computer has no security chip, so you type your password each time it starts."
   - Buttons: Back / **"✓ Install now"**.
5. **Progress**: a ring with the percentage in a large thin font.
   - "2%": **"Getting your disk ready"** / "Clearing the disk" / tip box "Tip: Press Super + Space to find any app, do quick maths, or search the web."
   - "54%": **"Downloading FlowOS"** / "3.5 GB of 5.0 GB · about 1 min left" / tip ~"Tip: Double-click a Windows program [you want] to run it. FlowOS takes care of the rest."
6. **Done**: a green circle with a check, **"FlowOS is ready"**, "Restart your computer and remove the USB stick when the screen goes dark." Button **"⟳ Restart now"**.

### 5:14–5:26 End card
- Logo, **"FlowOS"**, "Early access opens this December." Crimson gradient pill button: **"Sign up at flowos.veloticstudios.com"** (with a glow shadow).

---

## 2. Visual design spec (reproduce the feel, not the branding)

### Global
- **Accent:** crimson/rose, about `#E11D48`–`#E5285F`. Lighter pink `#F0476F` is used for gradients. It appears on toggles, selected nav pills, progress, the search focus ring, install buttons, the active desktop chip, caption kickers and badges.
- **Surfaces (dark):** near-black with a slight warm tint. Window body about `#1B1B1F`; cards `#232328`; borders about 1 px `rgba(255,255,255,0.06–0.10)`.
- **Glass:** strong background blur (about 30–60 px) plus a dark tint (about 55–70% opacity) and a faint 1 px light rim. The tint takes on the wallpaper's hue (the Start menu looks brownish over the forest and teal over the lake). The light-mode variant is white glass at about 70%.
- **Corner radius:** about 8–10 px for app windows, 14–18 px for Start menu / Control Center / Dynamic Island / store cards, fully rounded pills for the dock, buttons and chips, and about 10–12 px for Control Center tiles.
- **Typography:** an Inter-like geometric sans throughout (captions, installer, store, Settings). Headings are bold, 600–700. Secondary text is about 60% white. The installer's large percentage numerals are thin, 200–300 weight.
- **Icons:** a colourful Fluent/Win11-like set. Files uses yellow folders, Notepad a blue page, Calculator a grid, Settings a blue gear, Terminal a dark prompt, Drivers a green chip, and Welcome a purple sparkle. App icons are rounded-square or squircle. Settings categories use crimson rounded-square glyph icons.
- **Wallpapers** (nature photography, filenames shown in Files):
  - `nature-waterfall.jpg`: mossy forest waterfall over a rocky pool
  - `nature-forest-rays.jpg`: misty pine forest with god rays
  - `nature-glacial-lake.jpg`: turquoise alpine lake with snowy peaks
  - `nature-turquoise-…`: Seebensee-like lake
  - `nature-aurora-peaks.jpg` and `nature-aurora-trees.jpg`: purple/green aurora
  - `nature-coast-cliffs.jpg`: sea-cliff cove
  - The installer and splash use abstract crimson waves and a dark radial gradient.

### Top bar
- Full width and very thin (about 22–24 px at 1080p). Translucent, so the wallpaper colour bleeds through.
- **Left:** the system logo (a coral/orange circle; replaced by the app icon when an app is focused) and the **active window title** ("Desktop" when nothing is focused).
- **Right:** a notification/display icon, a network/volume icon, the date "Sun 8 Nov" and the time "17:50" (24h).
- **When a window is maximised**, the bar turns opaque dark and acts as that window's title bar. Window controls (– ▢ ✕) sit near the right, before the tray. For Android windows, **← back and ⌂ home** buttons sit next to the title. This is a merged titlebar, like KDE's "borderless maximised windows" plus a window-buttons applet.
- Clicking the top-right opens the Control Center.

### Dock / taskbar
- A floating, centred, dark glass pill with a margin of about 8 px from the bottom edge. Icons are about 20 px at 1080p (small) with tight spacing.
- **Fixed left group:** Start orb (coral circle), Search, Task View, then pinned apps (Files, Notepad, Calculator, Task Manager, Settings).
- **Running apps** are appended (PowerPoint, Ps, Paint.NET, Markor, Material Files, VN, Subway Surf, Store), each with a small underline indicator. A tooltip label appears above an icon on hover (for example "Files").
- **Bottom-right corner:** a separate circular notification-centre button (bell) with a red count badge.
- **Variant seen at 3:51+:** a tray (network, volume) and a two-line clock "18:26 / 11/8/26" next to the bell, which gives a Windows taskbar feel.

### Start menu
- Win11 clone: centred above the dock, about 210×330 px at 640-px scale, which is about 640×1000 px at 1080p.
- Contents: a search field with a crimson outline, "Pinned" with an "All Apps ›" pill, a 6-column icon grid, "Recommended" with an empty state, and a footer with avatar, user name and power button.
- Search results: "Best matches", each row with icon, title and subtitle. The selected row is filled crimson at about 50% and shows ↵. A "Search the web for "…"" row is always last.
- Open with the Start orb or **Super**; the installer tip says **Super + Space** opens search/launcher (apps, quick maths, web).

### Launchpad
- Full-screen. The wallpaper is blurred heavily and darkened slightly. A small search pill sits at the top centre. Icons sit in an 11×5 grid with labels, paginated with dots. No folders were seen.

### Control Center
- Covered in the 0:39–0:51 section: Network, Bluetooth, Dark Mode, Focus, Sound slider (with %), Snip, Settings, Lock, Power, and Desktops 1–4.
- Tiles are dark glass. Active toggles show a crimson circle icon; inactive ones a grey circle.
- It has a full light-mode counterpart.

### Dynamic Island
- A top-centre rounded rectangle (about 290×50 px at 640 scale; it scales to about 860×150 at 1080p, so it is fairly large) in dark purple-tinted glass.
- Layout: a left circular icon well (bell), then a three-line stack: "App · now", a bold title, and a body line.
- Used for notifications such as Calendar reminders. It probably animates down from the top bar (only the static state was seen).

### Windows / decorations
- **Native apps** (Files, Notepad, Settings, Store, Windows Engine dialog): a Win11-like title bar with an icon and title on the left and – ▢ ✕ on the right. It was light in the first build and dark in the later build. App bodies are dark.
- **Windows-Engine apps**: appear as normal top-level windows with their own Windows 11 caption buttons (Paint.NET, Character Map, Notepad). When maximised (Office, Photoshop) they merge with the dark top bar.
- **Android apps**: maximised, with the top bar holding ← back. The Android nav bar (◀) stays visible at the bottom of the app surface. Portrait games are centred with a blurred side fill.
- **Mac apps**: a host frame (dark, with Windows controls) wraps a light macOS-style frame with traffic lights, a centred title and an in-window menu bar.
- **Snap:** a half-screen tile left/right, seen with Files + Notepad.

### Caption/lower-third style (video only, but a good OSD/toast style)
- A dark glass rounded card at the lower left, with a 3 px crimson vertical bar, a small all-caps crimson kicker and a large bold white title.

### Installer look
- A full-bleed abstract crimson wave background, with a centred dark card (about 55% of screen width, radius about 12 px).
- A step pill-progress at the top. Primary buttons are solid crimson with an arrow or check icon; secondary "Back" is ghost.
- Option cards are dark, and the selected card gets a crimson 1 px border and a crimson-tinted radio. Small crimson badges read "Recommended" and "Best for most people".

---

## 3. Feature list with suggested Linux components (for our own Arch-based gaming distro)

| # | FlowOS feature (observed) | Likely / suggested Linux component |
|---|---|---|
| 1 | KDE base ("KDE System Settings" visible in Launchpad) | **KDE Plasma 6 on Wayland, KWin**; Arch base, possibly via an archiso profile |
| 2 | Liquid-glass blur on menus, panels and dock | KWin Blur effect plus **kwin-effects-forceblur / "Better Blur"** for blur on arbitrary windows; a Kvantum or custom Plasma style with translucent SVGs; KWin **"Rounded corners" (KDE-Rounded-Corners)** script |
| 3 | Thin top bar with active title, tray and clock | Plasma panel (top, thin, translucent) + **Window Title applet** (e.g. "Window Title Applet" / "Panel Colorizer") + **Window Buttons applet** for maximised windows; KWin **"Hide titlebars of maximized windows"** (BorderlessMaximizedWindows=true) |
| 4 | Floating centred dock/taskbar with Start orb, Search, Task View, pinned apps, running indicators, bell | Plasma 6 **floating panel** with Icons-only Task Manager, Kickoff replacement button, KRunner/Overview buttons; a separate small panel or notification applet for the bell. A custom QML dock (Latte is unmaintained) is also an option |
| 5 | Win11-style Start menu with search, Pinned, All Apps, Recommended, user, power | Custom plasmoid: forks such as **"Menu 11" / "OnzeMenuKDE" / "Kickoff Grid"**. Search backed by **KRunner/Milou** (apps, calculator "quick maths", web shortcut) |
| 6 | Super + Space launcher (apps, maths, web) | **KRunner** with a custom theme, or Ulauncher; calculator runner plus web-shortcuts runner |
| 7 | Full-screen Launchpad | "**Application Dashboard**" (built in), or the "Launchpad Plasma" plasmoid; a blurred wallpaper backdrop |
| 8 | Control Center (Network, Bluetooth, Dark Mode, Focus, Sound, Snip, Settings, Lock, Power, Desktops 1–4) | Custom QML plasmoid. Data sources: NetworkManager (plasma-nm), BlueDevil, `plasma-apply-colorscheme` / lookandfeeltool for dark mode, Plasma DND for Focus, PipeWire/WirePlumber (plasma-pa), **Spectacle** for Snip, `loginctl lock-session`, ksmserver logout, KWin virtual desktops D-Bus. Projects such as "Control Centre" plasmoids exist to fork |
| 9 | Dynamic Island notifications | Custom KWin/QML notification popup replacing plasmashell notifications: listen on `org.freedesktop.Notifications` or theme the Plasma notification popup position at top centre with pill styling. Options: a layer-shell QML app via **layer-shell-qt** |
| 10 | Light/dark switching across the whole UI | Plasma global themes (light/dark pair) + Kvantum; GTK via `gtk-theme` sync (kde-gtk-config) |
| 11 | Files app (Explorer-like home, Quick access, greeting, drive usage) | **Dolphin** heavily themed (Places panel, a custom "Home" view is hard), or a custom Qt/QML file manager. Simpler: Dolphin + a custom Quick Access KIO view |
| 12 | Native Notepad, Calculator, Task Manager | KWrite/Kate, KCalc/Qalculate, **Plasma System Monitor** (rebranded "Task Manager"); or custom Kirigami apps |
| 13 | Snap layouts (half tiles) | KWin quick tiling / Plasma 6 custom tiling (Meta+T); the **"Krohnkite"/"Polonium"** scripts optional |
| 14 | Windows apps via "Windows Engine" (Office 365, Photoshop 2026, Win11 Notepad, charmap, Paint.NET), seamless per-app windows, "Opening X..." splash, double-click .exe | Best match: **WinBoat** or **WinApps** (Windows 11 in **QEMU/KVM via dockur/windows** or libvirt, apps streamed as **FreeRDP RemoteApp** windows). Plus a launcher that shows a progress popup while the VM resumes. For a *gaming* distro, also ship **Wine/Proton (GE-Proton), umu-launcher, Bottles or Lutris** for .exe games, with binfmt/.exe MIME handler that sends games to Proton and productivity apps to the VM |
| 15 | Windows apps appear in Start/Launchpad with extracted icons and "Windows app (runs in the Windows Engine)" subtitle | Generate `.desktop` files per detected Windows app (WinApps does this) with a custom `Comment=` string; placeholder icon when extraction fails |
| 16 | Android apps in separate windows with back/home in title bar | **Waydroid** (confirmed by window title) in multi-window mode (`persist.waydroid.multi_windows=true`), **GApps** image (Play Store visible), shared storage via `~/.local/share/waydroid/data/media`; desktop entries per Android app (Waydroid generates them). Back/home buttons: custom KWin decoration or title-bar applet sending `waydroid shell input keyevent` |
| 17 | Portrait game window with blurred side fill | Custom compositor effect or wrap via **gamescope** (letterbox) + KWin effect for background blur of the window's own contents (custom KWin effect) |
| 18 | Android game key mapping overlay (joystick, mouse aim, tap, repeat, swipe, labels; F12 toggle, Alt frees mouse, Win+Shift+G edit; per-game presets; Settings page) | **waydroid-helper** (ayasa520/waydroid-helper) has a key-mapping overlay; or **XtMapper** inside Android; or a custom host-side overlay (layer-shell QML) that injects touches via `uinput` or Waydroid's input socket. Pointer lock: Wayland `pointer-constraints` + relative pointer |
| 19 | Mac apps from .dmg (Chrome, Firefox, Maelstrom, Rocks'n'Diamonds) with nested mac-style frame and menu bar; "This can take a moment the first time" | Unknown runtime. Candidates: **Darling** (macOS translation layer; first launch builds a prefix, which fits the "first time" message). Another possibility is a **macOS VM (OSX-KVM/Docker-OSX) streamed per window**. The "MozillaProject" app-menu quirk points to a translation layer rather than real macOS. For our distro: treat as optional/experimental; `.dmg` MIME handler → `darling` + `hdiutil`-style mount. A pragmatic alternative is mapping known .dmg apps to their Linux/Flatpak equivalents |
| 20 | Velotic Store (Flathub apps, one-click install, inline progress, background installs, Open button, categories, Essentials bundle) | Custom front-end over **libflatpak / Flathub API** (AppStream metadata); or theme **GNOME Software / KDE Discover**. "Essentials" = curated batch install. Arch packages via PackageKit optional |
| 21 | Settings app (Win11 layout; categories incl. "Windows programs & Android", "Update & drivers", "Apps › Key mapping") | Custom Kirigami/QML settings shell embedding KCMs (`systemsettings` modules) + custom KCMs for Windows Engine, Waydroid and key mapping, plus drivers (e.g. `nvidia-inst`/mhwd-style), updates (pacman/topgrade/flatpak) |
| 22 | Drivers app | GUI for GPU driver install (NVIDIA/AMD/Intel), like CachyOS/Manjaro hardware detection (`chwd`/`mhwd`) |
| 23 | Welcome app | First-boot welcome (like `cachyos-hello` / `eos-welcome`), where browser and Windows/Android support are chosen ("when you first sign in") |
| 24 | Installer: Network → Activate (product key) → Drive → You → Region → Software (Recommended/Minimal) → Install; Advanced mode; LUKS option; online download of latest OS; "No TPM needed" | **Calamares** with a custom QML theme and modules (netinstall, partition, users, locale, packagechooser for profiles, LUKS), or a custom Qt/QML front-end over **archinstall** (JSON config) / pacstrap. Online install = pacstrap from mirrors. Skip "product key" for us. Tips carousel during install |
| 25 | Boot/brand splash | **Plymouth** theme (dark radial crimson glow + logo); SDDM theme to match |
| 26 | Multiple virtual desktops (1–4) | KWin virtual desktops |
| 27 | Screenshot "Snip" | Spectacle (region mode) bound to a tile and to Win+Shift+S |
| 28 | Notification centre with badge | Plasma notifications applet restyled; badge from notification count |
| 29 | Input method (IBus Preferences / Input Method in Launchpad) | IBus (or Fcitx5) for Android/CJK input |
| 30 | Gaming extras (not shown, but needed for our gaming distro) | Steam + Proton-GE, **gamescope**, **MangoHud**, **GameMode**, Lutris/Heroic, `linux-zen` or CachyOS kernel, `vm.max_map_count` tweak, controller support (Steam Input, `game-devices-udev`) |

---

## 4. Notes and caveats
- No Wine, Proton, Bottles, CrossOver or Darling version string is visible anywhere. The only engine name shown is **"Windows Engine"**. Waydroid is the only third-party runtime named on screen (window title).
- The demo was recorded in several sessions with different builds:
  - clocks "Sun 8 Nov 17:50", "12:48", "13:03", "18:23", "Mon 9 Nov 02:40/03:02/04:29" and "18:26 11/8/26"
  - title bars were light in early clips and dark in later ones
  - a dock variant with a tray clock appears in the Mac section.
- The Office, Photoshop and Subway Surfers shots are zoomed or cropped in post. Some frames therefore hide the top bar and dock.
- Text marked "~" was partly illegible at the source resolution (about 640×360 per frame).
