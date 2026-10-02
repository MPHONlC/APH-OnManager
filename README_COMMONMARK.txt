# APH-On Manager

*Categories, search, status icons, dependency and management tools for the Add-Ons menu.*

## Dependencies

Requires **LibAPH**.

Compatible with:
- **AddonSelector** (Profile & Keybind Management)
- **PerfectPixel** (Bigger UI)

It works alongside both when they are installed; neither is needed.

## What is this?

Extends the Add-Ons menu. It groups add-ons and libraries into categories you can create, rename and delete, adds a search box that jumps between matching rows, puts colored warning icons on every row, and replaces the row tooltip with one that lists required and optional libraries with their versions. Right-click any row to move it to another category. On PC, the dropdown beside the title opens Filter (the status filters, plus By Author, where you can type a name to narrow the list), Default Categories and, once you have made one, User Categories, with a check beside the one in use. Each category header has its own ON/OFF toggle that enables or disables that category's add-ons (libraries), and disabling a category also switches off libraries nothing else still needs.

What the icons mean:

- ✓ Red: the add-on failed to load, or threw a Lua error this session
- ✓ Yellow: the add-on's declared APIVersion is older than the live one (a declared version equal to or newer than the live API counts as current), or its version differs from the one on ESOUI when this add-on's data was last refreshed (older or newer, the tooltip shows "Version Mismatch" with the live version beside it), and on PC clicking it opens the add-on's ESOUI page
- ✓ Orange: a required dependency is missing, disabled or too old
- ✓ Blue: an optional dependency is installed but switched off
- ✓ Purple: other add-ons depend on this one
- ✓ Green: a patch add-on, depending on another add-on that is not a library

Hover an icon for more details, including which add-on or library it refers to and the versions involved.

## Slash Commands

- `/libcategories`: opens the category manager window.
- `/libcheck`: scans every enabled add-on's declared library dependencies, offers to enable optional libraries an add-on can use but currently has switched off, or to disable any enabled library nothing currently references, then reloads and reports the result in chat.
- `/libraryversioncheck`: lists every installed library's version next to the version recorded in this addon's own table: green for a match, cyan for newer, red for older.
- `/aombugreport`: opens the bug report popup (PC). It also opens by itself when APH-On Manager raises a Lua error, and lists the error, the live API and every enabled add-on and library with its Version, AddOnVersion and API.
- `/aomsavealerts`: toggles the Saved Variable Alerts on PC and reports the new state in chat (console uses the Saved Variable Alerts entry in the settings menu).

## Keeping the library/version tables fresh

The Data tables inside the add-on's DATA folder (library and add-on versions, dependencies and suggested categories, for PC and for console) hold what was published on ESOUI and Bethesda.net when this add-on's data was last refreshed, so they can only ever be as current as the release you installed. Is-Everything-Up-To-Date.sh (Mac/Linux) and Is-Everything-Up-To-Date.ps1 (Windows), included in this addon's own folder, checks all the Data tables against the latest ones, merge in only the entries that changed, and print exactly which ones changed. This doesn't check your other installed add-ons against ESOUI or download updates for them - You have to manually run Minion or manually update your own addons/library.

**Console Testing Notes:** This addon was developed and tested on **PC / Steam Deck** (using Force Console Flow for console testing).

## License

Copyright © 2026 @APHONlC. All rights reserved. See LICENSE.md

This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

For permissions or inquiries, contact @APHONlC on ESOUI.

## Credits

I would like to thank the following, for providing resources and their awesome projects:

- ESOUI Wiki
- MMOUI (Minion) (versions and IDs for the PC tables)
- Bethesda.net (versions and IDs for the console tables)
- @sirinsidiator
- @Flat-Badger-1971
- @sirinsidiator & @Seerah (LibAddonMenu-2.0)
- @Harven & @votan (LibHarvensAddonSettings)
- @SinusPi, @merlight, @Rhyono, @Dolgubon (Zgoo High Isle)
- @Baertram (Mer Torchbug - Fixed and Improved "Variable inspector/Scripts/Events/and more")

Inspired the idea of APH-On Manager:
- Addon Selector (Save & Load AddOn profiles/packs) (@Circonian, @Baertram)
- AddonCategory (@Floliroy)

Things my addon is compatible with:
- Addon Selector (Save & Load AddOn profiles/packs) (@Circonian, @Baertram)
- PerfectPixel (@KL1SK, @Baertram, @Dakjaniels)

Testers & Suggestions:
- @Drakius192
- @phlupp89

Check out my other addons/projects:
- Auto Lua Memory Cleaner
- Permanent Memento
- Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater (Linux, macOS, SteamDeck, & Windows)

## Bug Reports

If you encounter any issues, please submit a report on ESOUI
