[SIZE="5"][COLOR="SeaGreen"]APH-On Manager[/COLOR][/SIZE]
[COLOR="Gray"][i]Categories, search, status icons and dependency tools for the Add-Ons menu.[/i][/COLOR]

[SIZE="3"][COLOR="DarkOrchid"]What is this?[/COLOR][/SIZE]

APH-On Manager extends the game's own Add-Ons menu. It groups add-ons and libraries into categories you can create, rename and delete, adds a search box that jumps between matching rows, puts colored warning icons on every row, and replaces the row tooltip with one that lists required and optional libraries with their versions. Right-click any row to move it to another category. Each category header has its own ON/OFF toggle that enables or disables that category's add-ons, and disabling a category also switches off libraries nothing else still needs.

Requires [url="https://github.com/MPHONlC/LibAPH"]LibAPH[/url]. Works alongside Addon Selector and PerfectPixel.

What the icons mean:

[LIST]
[*] ✓ Red: the add-on failed to load, or threw a Lua error this session
[*] ✓ Yellow: the add-on's declared APIVersion is older than the live one (a declared version equal to or newer than the live API counts as current), or a newer version was on ESOUI when this add-on's data was last refreshed; the tooltip says which, and on PC clicking it opens the add-on's ESOUI page
[*] ✓ Orange: a required dependency is missing, disabled or too old
[*] ✓ Blue: an optional dependency is installed but switched off
[*] ✓ Purple: other add-ons depend on this one
[*] ✓ Green: a patch add-on, depending on another add-on that is not a library
[/LIST]

Hover an icon for the detail behind it, including which add-on or library it refers to and the versions involved.

[SIZE="3"][COLOR="DarkOrchid"]Slash Commands[/COLOR][/SIZE]

[LIST]
[*] [color=#00FFFF]/libcategories[/color]: opens the category manager window: every category with its add-ons, plus rename, delete, new category, reset list and reset categories.
[*] [color=#00FFFF]/libcatreset[/color]: moves every add-on and library back to its default category without touching the categories themselves.
[*] [color=#00FFFF]/libcheck[/color]: scans every enabled add-on's declared library dependencies, offers to enable optional libraries an add-on can use but currently has switched off, or to disable any enabled library nothing currently references, then reloads and reports the result in chat.
[*] [color=#00FFFF]/libraryversioncheck[/color]: lists every installed library's version next to the version recorded in this addon's own table: green for a match, cyan for newer, red for older.
[/LIST]

[SIZE="3"][COLOR="DarkOrchid"]Console and gamepad mode[/COLOR][/SIZE]

The gamepad Add-Ons menu (consoles, and PC in gamepad-preferred mode) shows the same categories as section headers, so the left and right triggers jump between categories, the colored status icons on every row, and the library sections and icon details inside the right-hand tooltip. Everything that needs a click or a text box lives in the menu's own Options dialog: search, filter, move the selected add-on to a category, enable or disable everything in its category, rename or delete that category, new category, reset list, reset categories. After a search, the left and right shoulder buttons step to the previous and next match. The [color=#00FFFF]/libcategories[/color], [color=#00FFFF]/libcheck[/color] and [color=#00FFFF]/libraryversioncheck[/color] windows stay on PC.

[SIZE="3"][COLOR="DarkOrchid"]Keeping the library/version tables fresh[/COLOR][/SIZE]

[color=#00FFFF]KnownLibraries.lua[/color] and [color=#00FFFF]KnownAddonVersions.lua[/color] hold the versions published on ESOUI when this add-on's data was last refreshed, so they can only ever be as current as the release you installed. [color=#00FFFF]Is-Everything-Up-To-Date.sh[/color] (Mac/Linux) and [color=#00FFFF]Is-Everything-Up-To-Date.ps1[/color] (Windows), included in this addon's own folder, check both files against the latest versions on GitHub, merge in only the entries that changed, and print exactly which ones changed with their old/new versions. This doesn't check your other installed add-ons against ESOUI or download updates for them - You have to manually run Minion or manually update your own addons/library.

[center]
[SIZE="5"][COLOR="Red"]LICENSE & USAGE[/COLOR][/SIZE]

Copyright (c) 2026 [COLOR="#FF69B4"]@APHONlC[/COLOR].

Licensed under the [b]GNU General Public License v3.0 (GPLv3)[/b] [COLOR="Gray"][i](see LICENSE.md and NOTICE.md in the source)[/i][/COLOR].

[COLOR="Gray"][i](A personal ask, not a license term: Instead of making "another version" please give me a heads-up before mirroring/re-uploading this elsewhere or publishing your own modified version, even though GPLv3 doesn't legally require it.)[/i][/COLOR]

[COLOR="Gray"][i](We can probably work on a patch or collaborate on an update instead of creating another version of the same source.)[/i][/COLOR]

[COLOR="Gray"][i](Separately: AI agents, LLMs, and automated bots are not authorized to read, ingest, or train on this code - see NOTICE.md for details.)[/i][/COLOR]

[COLOR="Gray"][i](For permissions or inquiries, contact [COLOR="#FF69B4"]@APHONlC[/COLOR] on ESOUI or GitHub.)[/i][/COLOR]

[b][color=#9CD04C]Check out my other addons/projects:[/color][/b]

[LIST]
[*] [url="https://www.esoui.com/downloads/fileinfo.php?id=4388#info"][color=#fa9c1b]Auto Lua Memory Cleaner[/color][/url]
[*] [url="https://www.esoui.com/downloads/fileinfo.php?id=4116#info"][color=#fa9c1b]Permanent Memento[/color][/url]
[*] [url="https://www.esoui.com/downloads/fileinfo.php?id=3249#info"][color=#fa9c1b]Tamriel Trade Center, HarvestMap & ESO-Hub Auto-Updater[/color][/url] [COLOR="Gray"][i](Linux, macOS, SteamDeck, & Windows)[/i][/COLOR]
[/LIST]

[b][color=#ff3300][SIZE="4"]BUG REPORTS[/SIZE][/color][/b]
If you encounter any issues, please submit a report here:
[url="https://www.esoui.com/"]ESOUI[/url] | [url="https://github.com/MPHONlC/APH-OnManager/issues"]GitHub Issue Tracker[/url]
[/center]