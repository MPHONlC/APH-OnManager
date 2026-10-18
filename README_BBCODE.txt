[SIZE="5"][COLOR="SeaGreen"]APH-On Manager[/COLOR][/SIZE]
[COLOR="Gray"][i]Categories, search, status icons, dependency and management tools for the Add-Ons menu.[/i][/COLOR]

[SIZE="3"][COLOR="DarkOrchid"]Dependencies:[/COLOR][/SIZE]

This addon requires:
[LIST]
[*] [url="https://www.esoui.com/downloads/info4917-LibAPH.html"][COLOR="#FF69B4"]LibAPH[/COLOR][/url] [COLOR="Gray"][i](Required Unified helpers shared with my addons)[/i][/COLOR]
[/LIST]

Compatible with:
[LIST]
[*] [url="https://www.esoui.com/downloads/info1161-AddonSelector.html"][COLOR="#FF69B4"]AddonSelector[/COLOR][/url] [COLOR="Gray"][i](Profile & Keybind Management)[/i][/COLOR]
[*] [url="https://www.esoui.com/downloads/info2103-PerfectPixel.html"][COLOR="#FF69B4"]PerfectPixel[/COLOR][/url] [COLOR="Gray"][i](Bigger UI)[/i][/COLOR]
[/LIST]

It works alongside both when they are installed; neither is needed.

[SIZE="3"][COLOR="DarkOrchid"]Demos[/COLOR][/SIZE]

[b]PC[/b]
[SPOILER]
[b]Categories[/b]
[IMG]https://i.postimg.cc/DZmy1350/Ao-M-CATEGORY.gif[/IMG]

[b]Creating and deleting a category, moving add-ons into it[/b]
[IMG]https://i.postimg.cc/XX6jMGW7/Ao-M-CREATE-DELETE-MOVETO-CATEGORY.gif[/IMG]

[b]Filters[/b]
[IMG]https://i.postimg.cc/G2Z82pRM/Ao-M-FILTERS.gif[/IMG]

[b]Author filters[/b]
[IMG]https://i.postimg.cc/L8BXpTnd/Ao-M-AUTHOR-FILTERS.gif[/IMG]

[b]Version filters[/b]
[IMG]https://i.postimg.cc/zXYHY30k/Ao-M-VERSION-FILTERS.gif[/IMG]

[b]Save size[/b]
[IMG]https://i.postimg.cc/9X7wkytW/Ao-M-SAVE-SIZE.gif[/IMG]

[b]ESOUI links[/b]
[IMG]https://i.postimg.cc/vmZ62j3F/Ao-M-ESOUI-LINKS.gif[/IMG]

[b]Error capture and bug report[/b]
[IMG]https://i.postimg.cc/wjHNL3NM/Ao-M-ERROR-CAPTURE-AND-BUG-REPORT.gif[/IMG]
[/SPOILER]

[b]Console[/b]
[SPOILER]
[b]Search and jump between matches[/b]
[IMG]https://i.postimg.cc/VNc3mTKS/AOM-CONSOLE-SEARCH-JUMP.gif[/IMG]

[b]Filters[/b]
[IMG]https://i.postimg.cc/xTXrRLXZ/AOM-CONSOLE-FILTERS.gif[/IMG]

[b]Status icons[/b]
[IMG]https://i.postimg.cc/13FkxPcG/AOM-CONSOLE-ICONS.gif[/IMG]

[b]Disable unused add-ons[/b]
[IMG]https://i.postimg.cc/hj2w8GcS/AOM-DISABLE-UNUSED-CONSOLE.gif[/IMG]

[b]Error capture[/b]
[IMG]https://i.postimg.cc/fygGsRrv/AOM-CONSOLE-ERRORS-SLOW.gif[/IMG]
[/SPOILER]

[SIZE="3"][COLOR="DarkOrchid"]What is this?[/COLOR][/SIZE]

Extends the Add-Ons menu. It groups add-ons and libraries into categories you can create, rename and delete, adds a search box that jumps between matching rows, puts colored warning icons on every row, and replaces the row tooltip with one that lists required and optional libraries with their versions. Right-click any row to move it to another category. On PC, the dropdown beside the title opens Filter [COLOR="Gray"][i](the status filters, plus By Author, where you can type a name to narrow the list)[/i][/COLOR], Default Categories and, once you have made one, User Categories, with a check beside the one in use. Each category header has its own ON/OFF toggle that enables or disables that category's add-ons [COLOR="Gray"][i](libraries)[/i][/COLOR], and disabling a category also switches off libraries nothing else still needs.

What the icons mean:

[LIST]
[*] ✓ Red: the add-on failed to load, or threw a Lua error this session
[*] ✓ Yellow: the add-on's declared APIVersion is older than the live one [COLOR="Gray"][i](a declared version equal to or newer than the live API counts as current)[/i][/COLOR], or its version differs from the one on ESOUI when this add-on's data was last refreshed [COLOR="Gray"][i](older or newer, the tooltip shows "Version Mismatch" with the live version beside it)[/i][/COLOR], and on PC clicking it opens the add-on's ESOUI page
[*] ✓ Orange: a required dependency is missing, disabled or too old, and clicking it switches on the disabled ones
[*] ✓ Blue: an optional dependency is installed but switched off, and clicking it switches those on, or off again once they are all on
[*] ✓ Purple: other add-ons depend on this one, and clicking it switches those on, or off again once they are all on
[*] ✓ Green: a patch add-on, depending on another add-on that is not a library, and clicking it switches on the patched add-ons that are off
[/LIST]

Hover an icon for more details, including which add-on or library it refers to and the versions involved. With a controller, move to an icon and press the right stick to do what a click does.

[SIZE="3"][COLOR="DarkOrchid"]Slash Commands[/COLOR][/SIZE]
[spoiler]
[LIST]
[*] [color=#00FFFF]/libcategories[/color]: opens the category manager window.
[*] [color=#00FFFF]/libcheck[/color]: scans every enabled add-on's declared library dependencies, offers to enable optional libraries an add-on can use but currently has switched off, or to disable any enabled library nothing currently references, then reloads and reports the result in chat.
[*] [color=#00FFFF]/libraryversioncheck[/color]: lists every installed library's version next to the version recorded in this addon's own table: green for a match, cyan for newer, red for older.
[*] [color=#00FFFF]/aombugreport[/color]: opens the bug report popup [COLOR="Gray"][i](PC)[/i][/COLOR]. It also opens by itself when APH-On Manager raises a Lua error, and lists the error, the live API and every enabled add-on and library with its Version, AddOnVersion and API.
[*] [color=#00FFFF]/aomsavealerts[/color]: toggles the Saved Variable Alerts on PC and reports the new state in chat [COLOR="Gray"][i](console uses the Saved Variable Alerts entry in the settings menu)[/i][/COLOR].
[/LIST]
[/spoiler]

[center]
[b][COLOR="Orange"]⚠️ CONSOLE TESTING NOTES ⚠️[/COLOR][/b]
This addon was developed and tested on [b][COLOR="#FF69B4"]PC / Steam Deck[/COLOR][/b] [COLOR="Gray"][i](using Force Console Flow for console testing)[/i][/COLOR].

[SIZE="5"][COLOR="Red"]LICENSE & USAGE[/COLOR][/SIZE]

Copyright © 2026 [COLOR="#FF69B4"]@APHONlC[/COLOR]. All rights reserved. See LICENSE.md

[COLOR="Gray"][i](For permissions or inquiries, contact [COLOR="#FF69B4"]@APHONlC[/COLOR] on ESOUI.)[/i][/COLOR]

[SIZE="5"][COLOR="Red"]Credits[/COLOR][/SIZE]
[b][COLOR="Orange"]I would like to thank the following:[/COLOR][/b]
[COLOR="Gray"][i](For providing resources and their awesome projects)[/i][/COLOR]
[url="https://wiki.esoui.com/Main_Page"][color=#fa9c1b]ESOUI Wiki[/color][/url]
[url="https://minion.mmoui.com/"][color=#fa9c1b]MMOUI (Minion)[/color][/url][COLOR="Gray"][i](versions and IDs for the PC tables)[/i][/COLOR]
[url="https://mods.bethesda.net/"][color=#fa9c1b]Bethesda.net[/color][/url][COLOR="Gray"][i](versions and IDs for the console tables)[/i][/COLOR]
[url="https://github.com/esoui/esoui"][color=#fa9c1b]@sirinsidiator[/color][/url]
[url="https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html"][color=#fa9c1b]@Flat-Badger-1971[/color][/url]
[url="https://www.esoui.com/downloads/info7.html"][color=#fa9c1b]@sirinsidiator & @Seerah[/color][/url][COLOR="Gray"][i](LibAddonMenu-2.0)[/i][/COLOR]
[url="https://www.esoui.com/downloads/info584.html"][color=#fa9c1b]@Harven & @votan[/color][/url][COLOR="Gray"][i](LibHarvensAddonSettings)[/i][/COLOR]
[url="https://www.esoui.com/downloads/info1624.html"][color=#fa9c1b]@SinusPi, @merlight, @Rhyono, @Dolgubon[/color][/url][COLOR="Gray"][i](Zgoo High Isle)[/i][/COLOR]
[url="https://www.esoui.com/downloads/info2601.html"][color=#fa9c1b]@Baertram[/color][/url][COLOR="Gray"][i](Mer Torchbug - Fixed and Improved "Variable inspector/Scripts/Events/and more")[/i][/COLOR]

[b][COLOR="Orange"]Inspired the idea of APH-On Manager:[/COLOR][/b]
[url="https://www.esoui.com/downloads/info1161.html"][color=#fa9c1b]Addon Selector (Save & Load AddOn profiles/packs)[/color][/url][COLOR="Gray"][i](@Circonian, @Baertram)[/i][/COLOR]
[url="https://www.esoui.com/downloads/info3427-AddonCategory.html"][color=#fa9c1b]AddonCategory[/color][/url][COLOR="Gray"][i](@Floliroy)[/i][/COLOR]

[b][COLOR="Orange"]Testers & Suggestions:[/COLOR][/b]
[color="#FF69B4"]@Drakius192[/color]
[color="#FF69B4"]@phlupp89[/color]

[b][color=#9CD04C]Check out my other addons/projects:[/color][/b]

[url="https://www.esoui.com/downloads/fileinfo.php?id=4388#info"][color=#fa9c1b]Auto Lua Memory Cleaner[/color][/url]
[url="https://www.esoui.com/downloads/fileinfo.php?id=4116#info"][color=#fa9c1b]Permanent Memento[/color][/url]
[url="https://www.esoui.com/downloads/fileinfo.php?id=3249#info"][color=#fa9c1b]Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater[/color][/url] [COLOR="Gray"][i](Linux, macOS, SteamDeck, & Windows)[/i][/COLOR]

[b][color=#ff3300][SIZE="4"]BUG REPORTS[/SIZE][/color][/b]
If you encounter any issues, please submit a report here
[/center]