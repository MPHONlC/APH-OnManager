import argparse
import json
import os
import re
import subprocess

FILELIST_URL = "https://api.mmoui.com/v4/game/ESO/filelist.json"
CATEGORYLIST_URL = "https://api.mmoui.com/v4/game/ESO/categorylist.json"
TABLE_FILES = ("KnownLibraries.lua", "KnownAddonVersions.lua", "SuggestedCategories.lua", "KnownAddonDependencies.lua")

HEADER = '''-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore

'''


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fetch_json(url):
    result = subprocess.run(["curl", "-sS", "-f", "--max-time", "120", url], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def max_api(listing):
    highest = 0
    for addon in listing.get("addons") or []:
        for token in str(addon.get("apiVersion") or "").split():
            if token.isdigit():
                highest = max(highest, int(token))
    return highest


def read_catalog(min_api, filelist_path, categorylist_path):
    filelist = json.load(open(filelist_path, encoding="utf-8")) if filelist_path else fetch_json(FILELIST_URL)
    categories = json.load(open(categorylist_path, encoding="utf-8")) if categorylist_path else fetch_json(CATEGORYLIST_URL)
    category_names = {int(c["id"]): c["title"] for c in categories}
    rows = {}
    kept = 0
    for listing in filelist:
        api = max_api(listing)
        if api >= min_api:
            kept += 1
        category = category_names.get(int(listing.get("categoryId") or 0))
        for addon in listing.get("addons") or []:
            name = str(addon.get("path") or "").rsplit("/", 1)[-1].strip()
            if not name:
                continue
            raw_version = str(addon.get("addOnVersion") or "").strip()
            rows.setdefault(name, []).append({
                "name": name,
                "title": listing.get("title") or name,
                "esoui_id": int(listing["id"]),
                "category": category,
                "library": bool(addon.get("library")) or bool(listing.get("library")),
                "addon_version": int(raw_version) if raw_version.isdigit() else 0,
                "version": str(listing.get("version") or ""),
                "optional": sorted(set(addon.get("optionalDependencies") or [])),
                "bundle_size": len(listing.get("addons") or []),
                "api": api,
                "api_versions": " ".join(t for t in str(addon.get("apiVersion") or "").split() if t.isdigit()),
            })
    return rows, kept, len(filelist)


def pick_candidate(name, candidates, minion_rows):
    installed = minion_rows.get(name)
    if installed and installed.get("esoui_id"):
        for c in candidates:
            if c["esoui_id"] == installed["esoui_id"]:
                return c
    return sorted(candidates, key=lambda c: (c["bundle_size"] == 1, c["title"].lower() == name.lower(), c["addon_version"]), reverse=True)[0]


def read_minion(path):
    if not os.path.exists(path):
        return {}
    data = json.load(open(path, encoding="utf-8"))
    bundles = data["installedGames"][0]["installedBundles"]
    rows = {}
    for key, bundle in bundles.items():
        esoui_id = int(key.split(":")[1]) if key.startswith("esoui:") else None
        for addon_key, addon in bundle["addOns"].items():
            name = addon.get("name") or addon_key.rsplit("/", 1)[-1]
            rows[name] = {
                "name": name,
                "title": addon.get("title") or bundle.get("title") or name,
                "esoui_id": esoui_id,
                "category": None,
                "library": bool(addon.get("library")) or bool(bundle.get("library")),
                "addon_version": int(addon.get("addOnVersion") or 0),
                "version": addon.get("version") or bundle.get("version") or "",
                "optional": sorted(d["name"] for d in (addon.get("dependencies") or {}).values() if d.get("type") == "OPTIONAL"),
                "api_versions": " ".join(t for t in str(addon.get("apiVersion") or "").split() if t.isdigit()),
            }
    return rows


def read_local_manifests(root):
    if not root or not os.path.isdir(root):
        return {}
    rows = {}
    for dirpath, _, files in os.walk(root):
        name = os.path.basename(dirpath)
        manifest = next((name + ext for ext in (".addon", ".txt") if name + ext in files), None)
        if not manifest or name in rows:
            continue
        fields = {}
        for line in open(os.path.join(dirpath, manifest), encoding="utf-8", errors="replace"):
            m = re.match(r"^##\s*([A-Za-z]+)\s*:\s*(.*?)\s*$", line.lstrip("\ufeff"))
            if m:
                fields[m.group(1)] = m.group(2)
        raw_version = re.match(r"\d+", fields.get("AddOnVersion", ""))
        rows[name] = {
            "name": name,
            "title": re.sub(r"\|c[0-9A-Fa-f]{6}|\|r", "", fields.get("Title", "")) or name,
            "esoui_id": None,
            "category": None,
            "library": fields.get("IsLibrary", "").lower() == "true",
            "addon_version": int(raw_version.group()) if raw_version else 0,
            "version": fields.get("Version", ""),
            "optional": sorted({d.split(">=")[0] for d in fields.get("OptionalDependsOn", "").split()}),
            "api_versions": " ".join(t for t in fields.get("APIVersion", "").split() if t.isdigit()),
        }
    return rows


def merge(catalog_rows, minion_rows, min_api, local_rows=None):
    rows = {}
    for name, candidates in catalog_rows.items():
        chosen = dict(pick_candidate(name, candidates, minion_rows))
        if chosen["api"] >= min_api or name in minion_rows:
            rows[name] = chosen
    for name, m in minion_rows.items():
        c = rows.get(name)
        if c:
            if not c["optional"] and m["optional"]:
                c["optional"] = m["optional"]
            if m["library"]:
                c["library"] = True
            if m["api_versions"] and m["addon_version"] >= c["addon_version"]:
                c["api_versions"] = m["api_versions"]
        else:
            rows[name] = m
    for name, loc in (local_rows or {}).items():
        c = rows.get(name)
        if c:
            if loc["api_versions"]:
                c["api_versions"] = loc["api_versions"]
            if loc["library"]:
                c["library"] = True
            if not c["optional"] and loc["optional"]:
                c["optional"] = loc["optional"]
        elif loc["api_versions"] or loc["addon_version"] > 0:
            rows[name] = loc
    return rows


def parse_existing(path):
    if not os.path.exists(path):
        return {}
    out = {}
    key_re = re.compile(r'^\t\["([^"]+)"\]')
    for line in open(path, encoding="utf-8"):
        m = key_re.match(line)
        if m and "/" not in m.group(1):
            out[m.group(1)] = line.rstrip("\n")
    return out


def entry_fields(line):
    fields = {}
    for m in re.finditer(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|\d+|nil)', line):
        fields[m.group(1)] = m.group(2)
    return fields


def write_versions(path, table_name, rows, is_library):
    existing = parse_existing(path)
    names = set(existing) | {n for n, r in rows.items() if r["library"] == is_library and (r["addon_version"] > 0 or r["api_versions"])}
    lines = [HEADER, f"AoM.{table_name} = {{\n"]
    count = 0
    for name in sorted(names, key=str.lower):
        if name == "LibAPH":
            continue
        r = rows.get(name)
        if r and r["library"] != is_library:
            continue
        old = entry_fields(existing.get(name, ""))
        if r and r["addon_version"] > 0:
            required = str(r["addon_version"])
            display = lua_str(r["version"] or str(r["addon_version"]))
        else:
            required = old.get("requiredVersion", "nil")
            display = old.get("displayVersion", '""')
        parts = []
        if is_library:
            parts.append(f"fullName = {old.get('fullName') or lua_str((r or {}).get('title') or name)}")
            parts.append(f"shortName = {old.get('shortName') or lua_str(name)}")
        if required != "nil":
            parts.append(f"requiredVersion = {required}")
        if display != '""':
            parts.append(f"displayVersion = {display}")
        esoui_id = (r or {}).get("esoui_id") or (int(old["esouiId"]) if old.get("esouiId") else None)
        if esoui_id:
            parts.append(f"esouiId = {esoui_id}")
        api_versions = (r or {}).get("api_versions") or (old["apiVersion"].strip('"') if old.get("apiVersion") else "")
        if api_versions:
            parts.append(f"apiVersion = {lua_str(api_versions)}")
        lines.append(f'\t["{name}"] = {{ {", ".join(parts)} }},\n')
        count += 1
    lines.append("}\n")
    open(path, "w", encoding="utf-8").write("".join(lines))
    return count


def write_categories(path, rows):
    existing = parse_existing(path)
    lines = [HEADER, "AoM.SuggestedCategories = {\n"]
    count = 0
    for name in sorted(set(existing) | set(rows), key=str.lower):
        r = rows.get(name)
        if r:
            category = "Libraries" if r["library"] else r.get("category")
        else:
            m = re.search(r'=\s*"((?:[^"\\]|\\.)*)"', existing[name])
            category = m.group(1) if m else None
        if not category:
            continue
        lines.append(f'\t["{name}"] = {lua_str(category)},\n')
        count += 1
    lines.append("}\n")
    open(path, "w", encoding="utf-8").write("".join(lines))
    return count


def write_dependencies(path, rows):
    existing = parse_existing(path)
    names = set(existing) | {n for n, r in rows.items() if r["optional"]}
    lines = [HEADER, "AoM.KnownAddonDependencies = {\n"]
    count = 0
    for name in sorted(names, key=str.lower):
        r = rows.get(name)
        if r and r["optional"]:
            deps = r["optional"]
        else:
            deps = re.findall(r'"([^"]+)"', existing[name].split("=", 1)[1])
        if deps:
            lines.append(f'\t["{name}"] = {{ {", ".join(lua_str(d) for d in deps)} }},\n')
            count += 1
    lines.append("}\n")
    open(path, "w", encoding="utf-8").write("".join(lines))
    return count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", required=True)
    parser.add_argument("--minion-config", default=os.path.expanduser("~/.minion/config/eso.json"))
    parser.add_argument("--addons-dir", default=os.path.expanduser("~/Documents/Elder Scrolls Online/live/AddOns"))
    parser.add_argument("--min-api", type=int, default=101040)
    parser.add_argument("--filelist", default="")
    parser.add_argument("--categorylist", default="")
    parser.add_argument("--github-output", default="")
    args = parser.parse_args()

    catalog_rows, kept, total = read_catalog(args.min_api, args.filelist, args.categorylist)
    minion_rows = read_minion(args.minion_config)
    local_rows = read_local_manifests(args.addons_dir)
    rows = merge(catalog_rows, minion_rows, args.min_api, local_rows)
    d = args.data_dir
    before = {f: open(os.path.join(d, f), encoding="utf-8").read() if os.path.exists(os.path.join(d, f)) else "" for f in TABLE_FILES}
    counts = {
        "KnownLibraries.lua": write_versions(os.path.join(d, "KnownLibraries.lua"), "KnownLibraries", rows, True),
        "KnownAddonVersions.lua": write_versions(os.path.join(d, "KnownAddonVersions.lua"), "KnownAddonVersions", rows, False),
        "SuggestedCategories.lua": write_categories(os.path.join(d, "SuggestedCategories.lua"), rows),
        "KnownAddonDependencies.lua": write_dependencies(os.path.join(d, "KnownAddonDependencies.lua"), rows),
    }
    changed = [f for f in TABLE_FILES if open(os.path.join(d, f), encoding="utf-8").read() != before[f]]
    report = [
        "## Add-on data tables refresh",
        "",
        f"- Catalog: {total} listings, {kept} at API {args.min_api} or newer, {len(catalog_rows)} add-on folders",
        f"- Installed (Minion): {len(minion_rows)}",
        f"- Local manifests (.addon/.txt): {len(local_rows)}",
        f"- Merged: {len(rows)}",
        "",
        "| Table | Entries | Changed |",
        "|---|---|---|",
    ]
    for f in TABLE_FILES:
        report.append(f"| `{f}` | {counts[f]} | {'yes' if f in changed else 'no'} |")
    report.append("")
    report.append(f"**{len(changed)} table(s) changed.**" if changed else "**All tables already up to date.**")
    emit(report, [])
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as f:
            f.write(f"changed={'true' if changed else 'false'}\n")
            f.write(f"changed_files={' '.join(changed)}\n")


def emit(report_lines, annotations):
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write("\n".join(report_lines) + "\n")
    else:
        print("\n".join(report_lines))
    for a in annotations:
        print(a)


if __name__ == "__main__":
    main()
