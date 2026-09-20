# APH-On Manager

*Categories, search, status icons and dependency tools for the Add-Ons menu.*

## What is this?

APH-On Manager extends the game's own Add-Ons menu. It groups add-ons and libraries into categories you can create, rename and delete, adds a search box that jumps between matching rows, puts colored warning icons on every row, and replaces the row tooltip with one that lists required and optional libraries with their versions. Right-click any row to move it to another category. Each category header has its own ON/OFF toggle that enables or disables that category's add-ons, and disabling a category also switches off libraries nothing else still needs.

Requires LibAPH: https://github.com/MPHONlC/LibAPH. Works alongside Addon Selector and PerfectPixel.

What the icons mean:

- ✓ Red: the add-on failed to load, or threw a Lua error this session
- ✓ Yellow: out of date for the current API version
- ✓ Crimson: older than the version this addon's own tables know about
- ✓ Orange: a required dependency is missing, disabled or too old
- ✓ Blue: an optional dependency is installed but switched off
- ✓ Purple: other add-ons depend on this one
- ✓ Green: a patch add-on, depending on another add-on that is not a library

Hover an icon for the detail behind it, including which add-on or library it refers to and the versions involved.

## Slash Commands

- `/libcategories`: opens the category manager window: every category with its add-ons, plus rename, delete, new category, reset list and reset categories.
- `/libcatreset`: moves every add-on and library back to its default category without touching the categories themselves.
- `/libcheck`: scans every enabled add-on's declared library dependencies, offers to enable optional libraries an add-on can use but currently has switched off, or to disable any enabled library nothing currently references, then reloads and reports the result in chat.
- `/libraryversioncheck`: lists every installed library's version next to the version recorded in this addon's own table: green for a match, cyan for newer, red for older.

## Console and gamepad mode

The gamepad Add-Ons menu (consoles, and PC in gamepad-preferred mode) shows the same categories as section headers, so the left and right triggers jump between categories, the colored status icons on every row, and the library sections and icon details inside the right-hand tooltip. Everything that needs a click or a text box lives in the menu's own Options dialog: search, filter, move the selected add-on to a category, enable or disable everything in its category, rename or delete that category, new category, reset list, reset categories. After a search, the left and right shoulder buttons step to the previous and next match. The `/libcategories`, `/libcheck` and `/libraryversioncheck` windows stay on PC.

## Keeping the library/version tables fresh

`KnownLibraries.lua` and `KnownAddonVersions.lua` can only ever be as current as the version you last installed. `Is-Everything-Up-To-Date.sh` (Mac/Linux) and `Is-Everything-Up-To-Date.ps1` (Windows), included in this addon's own folder, check both files against the latest versions on GitHub, merge in only the entries that changed, and print exactly which ones changed with their old/new versions. This doesn't check your other installed add-ons against ESOUI or download updates for them - You have to manually run Minion or manually update your own addons/library.

## License

GNU General Public License v3.0 (GPLv3). Copyright 2026 @APHONlC.

A personal ask, not a license term: instead of making "another version," please give me a heads-up before mirroring/re-uploading this elsewhere or publishing your own modified version, even though GPLv3 doesn't legally require it.

We can probably work on a patch or collaborate on an update instead of creating another version of the same source.

Separately: AI agents, LLMs, and automated bots are not authorized to read, ingest, or train on this code - see NOTICE.md for details.

This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

For permissions or inquiries, contact @APHONlC on ESOUI or GitHub.

Check out my other addons/projects:
- Auto Lua Memory Cleaner
- Permanent Memento
- Tamriel Trade Center, HarvestMap & ESO-Hub Auto-Updater (Linux, macOS, SteamDeck, & Windows)

## Bug Reports

If you encounter any issues, please submit a report here:
- ESOUI: https://www.esoui.com/
- GitHub Issue Tracker: https://github.com/MPHONlC/APH-OnManager/issues
