#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import zipfile

SHRINK_SLACK = 15
SHRINK_FRACTION = 0.05
CACHE_SAVE_EVERY = 25

HEADER = '''--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore

'''

MANIFEST_FIELD = re.compile(r'^##\s*([A-Za-z]+)\s*:\s*(.*?)\s*$')


def run_cli(cli, session, args, timeout):
    command = [cli] + args + ["--session", session]
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(args[:2])} failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def fetch_catalog(cli, session, page_size, timeout):
    listings = {}
    page = 1
    while True:
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as handle:
            out = handle.name
        try:
            run_cli(cli, session, ["list", "--all", "--page", str(page), "--page-size", str(page_size), "--output-json", out], timeout)
            payload = json.load(open(out, encoding="utf-8"))
        finally:
            os.unlink(out)
        rows = payload.get("data") or []
        for row in rows:
            listings[row["addonId"]] = row
        total = int(payload.get("total") or 0)
        if len(listings) >= total or not rows:
            return listings, total
        page += 1


def read_manifests(zip_path):
    folders = []
    with zipfile.ZipFile(zip_path) as archive:
        for name in archive.namelist():
            if not name.lower().endswith((".addon", ".txt")):
                continue
            parts = name.split("/")
            if len(parts) != 2:
                continue
            folder, manifest = parts
            if os.path.splitext(manifest)[0].lower() != folder.lower():
                continue
            fields = {}
            for raw in archive.read(name).decode("utf-8-sig", "ignore").splitlines():
                match = MANIFEST_FIELD.match(raw)
                if match:
                    fields[match.group(1).lower()] = match.group(2)
            folders.append((folder, fields))
    return folders


def download_addon(cli, session, addon_id, timeout):
    work = tempfile.mkdtemp(prefix="console-addon-")
    try:
        before = set(os.listdir(work))
        subprocess.run([cli, "download", addon_id, "--session", session], cwd=work, capture_output=True, text=True, timeout=timeout, check=True)
        new = [f for f in os.listdir(work) if f not in before and f.endswith(".zip")]
        if not new:
            raise RuntimeError("no zip produced")
        return read_manifests(os.path.join(work, new[0]))
    finally:
        shutil.rmtree(work, ignore_errors=True)


def listing_rank(entry):
    version = entry.get("addOnVersion") or ""
    return (int(version) if str(version).isdigit() else 0,
            int(entry.get("updatedAt") or 0),
            int(entry.get("downloads") or 0))


def best_listing_per_folder(cache):
    folders = {}
    for entry in cache["addons"].values():
        folder = entry["folder"]
        if folder not in folders or listing_rank(entry) > listing_rank(folders[folder]):
            folders[folder] = entry
    return folders


def split_list(raw):
    return [part for part in re.split(r"[\s,]+", str(raw or "")) if part]


def strip_version(name):
    return re.split(r"[<>=]", name, 1)[0].strip()


def count_existing_rows(path):
    if not os.path.exists(path):
        return 0
    body = open(path, encoding="utf-8").read()
    start, end = body.find("[==["), body.rfind("]==]")
    if start < 0 or end < 0:
        return 0
    return len([line for line in body[start + 4:end].splitlines() if line.strip()])


class WouldLoseData(Exception):
    pass


def guard_shrink(path, new_count, allow_shrink):
    old_count = count_existing_rows(path)
    if allow_shrink or old_count == 0:
        return
    lost = old_count - new_count
    if lost > max(SHRINK_SLACK, old_count * SHRINK_FRACTION):
        raise WouldLoseData(
            f"{os.path.basename(path)} would drop from {old_count} to {new_count} rows, losing {lost}. "
            "Nothing was written. Re-run once the downloads work, or pass --allow-shrink if the "
            "catalog really did lose that many add-ons.")


def write_lua(path, table_name, factory, rows, allow_shrink=False):
    guard_shrink(path, len(rows), allow_shrink)
    body = HEADER + f"AoM.{table_name} = AoM.{factory}([==[\n" + "\n".join(rows) + "\n]==])\n"
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    if old != body:
        open(path, "w", encoding="utf-8").write(body)
        return True, len(rows)
    return False, len(rows)


def write_libraries(path, folders, allow_shrink=False):
    rows = []
    for folder, entry in sorted(folders.items(), key=lambda kv: kv[0].lower()):
        if str(entry.get("isLibrary", "")).lower() != "true":
            continue
        values = [clean(v) for v in (folder, entry.get("addOnVersion", ""), entry.get("version", ""),
                                     entry.get("apiVersion", ""), entry.get("title", ""), entry.get("author", ""),
                                     entry.get("addonId", ""))]
        while values and values[-1] == "":
            values.pop()
        rows.append("\t".join(values))
    return write_lua(path, "KnownConsoleLibraries", "CreateConsoleTable", rows, allow_shrink)


def write_dependencies(path, folders, allow_shrink=False):
    rows = []
    for folder, entry in sorted(folders.items(), key=lambda kv: kv[0].lower()):
        optional = [strip_version(name) for name in split_list(entry.get("optionalDependsOn"))]
        optional = sorted({name for name in optional if name})
        if optional:
            rows.append(clean(folder) + "\t" + "\t".join(clean(name) for name in optional))
    return write_lua(path, "KnownConsoleAddonDependencies", "CreateConsoleListTable", rows, allow_shrink)


def write_categories(path, folders, esoui_categories, allow_shrink=False):
    rows = []
    for folder, entry in sorted(folders.items(), key=lambda kv: kv[0].lower()):
        if str(entry.get("isLibrary", "")).lower() == "true":
            category = "Libraries"
        else:
            category = esoui_categories.get(folder)
        if category:
            rows.append(clean(folder) + "\t" + clean(category))
    return write_lua(path, "ConsoleSuggestedCategories", "CreateConsoleValueTable", rows, allow_shrink)


def read_esoui_categories(path):
    categories = {}
    if not path or not os.path.exists(path):
        return categories
    for line in open(path, encoding="utf-8"):
        match = re.match(r'^\t\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"', line)
        if match:
            categories[match.group(1)] = match.group(2)
    return categories


def save_cache(cache, cache_path):
    json.dump(cache, open(cache_path, "w", encoding="utf-8"), indent=1, sort_keys=True)


def would_shrink(data_file, cache):
    old_count = count_existing_rows(data_file)
    new_count = len(best_listing_per_folder(cache))
    return old_count > 0 and old_count - new_count > max(SHRINK_SLACK, old_count * SHRINK_FRACTION)


def save(cache, cache_path, data_file, extras=None, allow_shrink=False):
    changed, count = write_table(data_file, cache, allow_shrink)
    if extras:
        folders = best_listing_per_folder(cache)
        directory = os.path.dirname(data_file)
        changed = write_libraries(os.path.join(directory, "KnownConsoleLibraries.lua"), folders, allow_shrink)[0] or changed
        changed = write_dependencies(os.path.join(directory, "KnownConsoleAddonDependencies.lua"), folders, allow_shrink)[0] or changed
        changed = write_categories(os.path.join(directory, "ConsoleSuggestedCategories.lua"), folders, extras, allow_shrink)[0] or changed
    save_cache(cache, cache_path)
    return changed, count


def show_progress(done, total, failed, label):
    width = 30
    filled = int(width * done / total) if total else width
    bar = "#" * filled + "-" * (width - filled)
    percent = (100.0 * done / total) if total else 100.0
    line = f"[{bar}] {done}/{total} ({percent:4.1f}%)  fails: {failed}  {label[:40]}"
    if sys.stdout.isatty():
        sys.stdout.write("\r" + line.ljust(110))
    else:
        sys.stdout.write(line + "\n")
    sys.stdout.flush()


def clean(value):
    return str(value).replace("\t", " ").replace("\n", " ").replace("\r", " ").strip()


def write_table(path, cache, allow_shrink=False):
    rows = []
    for folder, entry in sorted(best_listing_per_folder(cache).items(), key=lambda kv: kv[0].lower()):
        values = [folder, entry.get("addOnVersion", ""), entry.get("version", ""), entry.get("apiVersion", ""),
                  entry.get("title", ""), entry.get("author", ""), entry.get("addonId", "")]
        values = [clean(v) for v in values]
        while values and values[-1] == "":
            values.pop()
        rows.append("\t".join(values))
    guard_shrink(path, len(rows), allow_shrink)
    body = HEADER + "AoM.KnownConsoleAddons = AoM.CreateConsoleTable([==[\n" + "\n".join(rows) + "\n]==])\n"
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    if old != body:
        open(path, "w", encoding="utf-8").write(body)
        return True, len(rows)
    return False, len(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True)
    parser.add_argument("--session", required=True)
    parser.add_argument("--cache", required=True)
    parser.add_argument("--data-file", required=True)
    parser.add_argument("--limit", type=int, default=0, help="How many add-ons to download in this run (0 = every one that changed)")
    parser.add_argument("--esoui-categories", default="", help="SuggestedCategories.lua to borrow categories from for ported add-ons")
    parser.add_argument("--page-size", type=int, default=50)
    parser.add_argument("--timeout", type=float, default=180.0)
    parser.add_argument("--github-output", default="")
    parser.add_argument("--allow-shrink", action="store_true",
                        help="Permit a run to write fewer rows than the tables already hold")
    args = parser.parse_args()

    args.cli = os.path.abspath(os.path.expanduser(args.cli))
    if not os.path.isfile(args.cli) or not os.access(args.cli, os.X_OK):
        parser.error(f"--cli is not an executable file: {args.cli}")
    args.session = os.path.abspath(os.path.expanduser(args.session))
    args.cache = os.path.abspath(os.path.expanduser(args.cache))
    args.data_file = os.path.abspath(os.path.expanduser(args.data_file))
    if args.esoui_categories:
        args.esoui_categories = os.path.abspath(os.path.expanduser(args.esoui_categories))

    esoui_categories = read_esoui_categories(args.esoui_categories or os.path.join(os.path.dirname(args.data_file), "SuggestedCategories.lua"))
    cache = {"addons": {}, "by_id": {}}
    if os.path.exists(args.cache):
        cache.update(json.load(open(args.cache, encoding="utf-8")))

    listings, total = fetch_catalog(args.cli, args.session, args.page_size, args.timeout)
    if not listings:
        print("The catalog came back empty, so this run has nothing to compare against. Nothing was written.")
        return 1
    gone = [addon_id for addon_id in list(cache["by_id"]) if addon_id not in listings]
    for addon_id in gone:
        cache["by_id"].pop(addon_id, None)
        for key in [k for k, v in cache["addons"].items() if v.get("addonId") == addon_id]:
            cache["addons"].pop(key, None)

    stale = [row for addon_id, row in listings.items()
             if cache["by_id"].get(addon_id, {}).get("version") != row.get("version")]
    stale.sort(key=lambda row: str(row.get("updatedAt") or 0), reverse=True)
    todo = stale[:args.limit] if args.limit > 0 else stale
    rebuilding = not args.allow_shrink and would_shrink(args.data_file, cache)
    if rebuilding:
        print(f"The download cache holds {len(cache['by_id'])} of {len(listings)} add-ons, fewer than the tables already list, "
              "so it is rebuilt first and the tables stay as they are until it covers them again.")

    downloaded, failed, table_changed = 0, [], False
    for index, row in enumerate(todo, start=1):
        show_progress(index - 1, len(todo), len(failed), row.get("title", ""))
        try:
            folders = download_addon(args.cli, args.session, row["addonId"], args.timeout)
        except Exception as error:
            failed.append(f'{row.get("title")}: {error}')
            continue
        downloaded += 1
        cache["by_id"][row["addonId"]] = {"version": row.get("version"), "folders": [f for f, _ in folders]}
        for folder, fields in folders:
            cache["addons"][row["addonId"] + "/" + folder] = {
                "folder": folder,
                "addonId": row["addonId"],
                "updatedAt": row.get("updatedAt", 0),
                "downloads": (row.get("xboxDownloads") or 0) + (row.get("ps5Downloads") or 0),
                "title": row.get("title", ""),
                "author": row.get("author", ""),
                "version": row.get("version") or fields.get("version", ""),
                "addOnVersion": fields.get("addonversion", ""),
                "apiVersion": fields.get("apiversion", ""),
                "isLibrary": fields.get("islibrary", ""),
                "dependsOn": fields.get("dependson", ""),
                "optionalDependsOn": fields.get("optionaldependson", ""),
            }
        if rebuilding:
            if downloaded % CACHE_SAVE_EVERY == 0:
                save_cache(cache, args.cache)
            continue
        try:
            table_changed = save(cache, args.cache, args.data_file, esoui_categories, args.allow_shrink)[0] or table_changed
        except WouldLoseData as error:
            sys.stdout.write("\n")
            print(f"Refusing to write: {error}")
            return 1

    show_progress(len(todo), len(todo), len(failed), "done")
    if sys.stdout.isatty():
        sys.stdout.write("\n")
    if downloaded == 0 and failed:
        print(f"Every one of the {len(failed)} downloads failed, so this run learned nothing. Nothing was written.")
        for line in failed[:5]:
            print(f"  failed: {line}")
        if len(failed) > 5:
            print(f"  ... and {len(failed) - 5} more, all the same way")
        return 1
    remaining = max(0, len(stale) - downloaded)
    if rebuilding and remaining > 0 and would_shrink(args.data_file, cache):
        save_cache(cache, args.cache)
        print(f"Rebuilding the download cache: {len(cache['by_id'])} of {len(listings)} add-ons fetched so far, "
              f"{remaining} still to go. The tables were left as they are; the next run carries on.")
        for line in failed:
            print(f"  failed: {line}")
        if args.github_output:
            with open(args.github_output, "a", encoding="utf-8") as handle:
                handle.write("changed=true\n")
                handle.write(f"remaining={remaining}\n")
        return 0
    try:
        changed, count = save(cache, args.cache, args.data_file, esoui_categories, args.allow_shrink)
    except WouldLoseData as error:
        print(f"Refusing to write: {error}")
        return 1
    changed = changed or table_changed

    print(f"Console catalog: {total} add-ons listed, {len(stale)} need a download, {downloaded} fetched this run.")
    if gone:
        print(f"Removed {len(gone)} add-on(s) no longer on Bethesda.net.")
    print(f"Table now holds {count} folder(s) from {len(cache['by_id'])} add-on(s). Changed: {'yes' if changed else 'no'}")
    for line in failed:
        print(f"  failed: {line}")
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as handle:
            handle.write(f"changed={'true' if changed else 'false'}\n")
            handle.write(f"remaining={remaining}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
