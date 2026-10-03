<div align="center">

# APH-On Manager

*Categories, search, status icons, dependency and management tools for the Add-Ons menu.*

![Version](https://img.shields.io/badge/version-2026.10.03.06.12-9CD04C?style=flat-square)
![ESO API](https://img.shields.io/badge/ESO%20API-101051%20%7C%20101052-00FFFF?style=flat-square)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-fa9c1b?style=flat-square)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Xbox%20%7C%20PlayStation-FF69B4?style=flat-square)

</div>

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

<details>
<summary>Show all commands</summary>

- `/libcategories`: opens the category manager window.
- `/libcheck`: scans every enabled add-on's declared library dependencies, offers to enable optional libraries an add-on can use but currently has switched off, or to disable any enabled library nothing currently references, then reloads and reports the result in chat.
- `/libraryversioncheck`: lists every installed library's version next to the version recorded in this addon's own table: green for a match, cyan for newer, red for older.
- `/aombugreport`: opens the bug report popup (PC). It also opens by itself when APH-On Manager raises a Lua error, and lists the error, the live API and every enabled add-on and library with its Version, AddOnVersion and API.
- `/aomsavealerts`: toggles the Saved Variable Alerts on PC and reports the new state in chat (console uses the Saved Variable Alerts entry in the settings menu).

</details>

## Keeping the library/version tables fresh

<details>
<summary>How the data tables stay current</summary>

The Data tables inside the add-on's DATA folder (library and add-on versions, dependencies and suggested categories, for PC and for console) hold what was published on ESOUI and Bethesda.net when this add-on's data was last refreshed, so they can only ever be as current as the release you installed. `Is-Everything-Up-To-Date.sh` (Mac/Linux) and `Is-Everything-Up-To-Date.ps1` (Windows), included in this addon's own folder, checks all the Data tables against the latest ones, merge in only the entries that changed, and print exactly which ones changed. This doesn't check your other installed add-ons against ESOUI or download updates for them - You have to manually run Minion or manually update your own addons/library.

</details>

> [!WARNING]
> **Console Testing Notes:** This addon was developed and tested on **PC / Steam Deck** *(using Force Console Flow for console testing)*.

## License

Copyright © 2026 @APHONlC. All rights reserved. See LICENSE.md

> [!NOTE]
> This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

For permissions or inquiries, contact @APHONlC on ESOUI.

## Credits

I would like to thank the following, for providing resources and their awesome projects:

- [ESOUI Wiki](https://wiki.esoui.com/Main_Page)
- [MMOUI (Minion)](https://minion.mmoui.com/) <sub>*(versions and IDs for the PC tables)*</sub>
- [Bethesda.net](https://mods.bethesda.net/) <sub>*(versions and IDs for the console tables)*</sub>
- [@sirinsidiator](https://github.com/esoui/esoui)
- [@Flat-Badger-1971](https://github.com/Flat-Badger-1971/eso-api)
- [@sirinsidiator & @Seerah](https://www.esoui.com/downloads/info7.html) <sub>*(LibAddonMenu-2.0)*</sub>
- [@Harven & @votan](https://www.esoui.com/downloads/info584.html) <sub>*(LibHarvensAddonSettings)*</sub>
- [@SinusPi, @merlight, @Rhyono, @Dolgubon](https://www.esoui.com/downloads/info1624.html) <sub>*(Zgoo High Isle)*</sub>
- [@Baertram](https://www.esoui.com/downloads/info2601.html) <sub>*(Mer Torchbug - Fixed and Improved "Variable inspector/Scripts/Events/and more")*</sub>

**Inspired the idea of APH-On Manager:**

- [Addon Selector (Save & Load AddOn profiles/packs)](https://www.esoui.com/downloads/info1161.html) <sub>*(@Circonian, @Baertram)*</sub>
- [AddonCategory](https://www.esoui.com/downloads/info3427-AddonCategory.html) <sub>*(@Floliroy)*</sub>

**Things my addon is compatible with:**

- [Addon Selector (Save & Load AddOn profiles/packs)](https://www.esoui.com/downloads/info1161.html) <sub>*(@Circonian, @Baertram)*</sub>
- [PerfectPixel](https://www.esoui.com/downloads/info2103.html) <sub>*(@KL1SK, @Baertram, @Dakjaniels)*</sub>

**Testers & Suggestions:**

<!-- TESTERS:START -->
- @Drakius192
- @phlupp89
<!-- TESTERS:END -->

**Check out my other addons/projects:**

- [Auto Lua Memory Cleaner](https://www.esoui.com/downloads/fileinfo.php?id=4388#info)
- [Permanent Memento](https://www.esoui.com/downloads/fileinfo.php?id=4116#info)
- [Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater](https://www.esoui.com/downloads/fileinfo.php?id=3249#info) <sub>*(Linux, macOS, SteamDeck, & Windows)*</sub>

If you like the addon and are considering donating, here's a link. Thank you!

[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/aph0nlc)

### Bug Reports

If you encounter any issues, please submit a report here
