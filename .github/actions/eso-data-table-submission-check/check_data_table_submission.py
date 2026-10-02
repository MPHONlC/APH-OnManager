#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import urllib.request

FILELIST_URL = "https://api.mmoui.com/v4/game/ESO/filelist.json"
CATEGORYLIST_URL = "https://api.mmoui.com/v4/game/ESO/categorylist.json"
DISCONTINUED_CATEGORY_ID = 157

VERSIONED_ENTRY_RE = re.compile(
	r'^\t(?:\["([^"]+)"\]|([A-Za-z_][A-Za-z0-9_.-]*))\s*=\s*\{'
	r'.*?requiredVersion\s*=\s*(nil|-?\d+).*?displayVersion\s*=\s*"([^"]*)".*?\}\s*,?\s*$'
)

ROW_ENTRY_RE = re.compile(r'^([^\t\[][^\t]*)\t([^\t]*)\t?([^\t]*)')

LIST_ENTRY_RE = re.compile(
	r'^\t\["([^"]+)"\]\s*=\s*\{\s*((?:"[^"]*"\s*,?\s*)*)\}\s*,?\s*$'
)

VALUE_ENTRY_RE = re.compile(r'^\t\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')


def fetch_json(url, timeout):
	with urllib.request.urlopen(url, timeout=timeout) as response:
		return json.load(response)


def load_catalog(filelist_path, categorylist_path, timeout):
	filelist = json.load(open(filelist_path, encoding="utf-8")) if filelist_path else fetch_json(FILELIST_URL, timeout)
	categories = json.load(open(categorylist_path, encoding="utf-8")) if categorylist_path else fetch_json(CATEGORYLIST_URL, timeout)
	category_names = {int(c["id"]): str(c["title"]) for c in categories}
	rows = {}
	for listing in filelist:
		category = category_names.get(int(listing.get("categoryId") or 0))
		for addon in listing.get("addons") or []:
			name = str(addon.get("path") or "").rsplit("/", 1)[-1].strip()
			if not name:
				continue
			raw_version = str(addon.get("addOnVersion") or "").strip()
			rows.setdefault(name, []).append({
				"esoui_id": int(listing["id"]),
				"title": str(listing.get("title") or name),
				"version": str(listing.get("version") or "").strip(),
				"addon_version": int(raw_version) if raw_version.isdigit() else 0,
				"library": bool(addon.get("library")) or bool(listing.get("library")),
				"category": category,
				"category_id": int(listing.get("categoryId") or 0),
				"last_update": int(listing.get("lastUpdate") or 0),
				"bundle_size": len(listing.get("addons") or []),
			})
	return rows, set(category_names.values())


def pick_listing(name, candidates, wanted_esoui_id):
	if wanted_esoui_id:
		for candidate in candidates:
			if candidate["esoui_id"] == wanted_esoui_id:
				return candidate
	live = [c for c in candidates if c["category_id"] != DISCONTINUED_CATEGORY_ID] or candidates
	return max(live, key=lambda c: (c["bundle_size"] == 1, c["title"].lower() == name.lower(), c["last_update"]))


def parse_table(path):
	entries = {}
	if not os.path.isfile(path):
		return entries
	with open(path, encoding="utf-8-sig", errors="ignore") as f:
		for line in f:
			stripped = line.rstrip("\n")

			m = VERSIONED_ENTRY_RE.match(stripped)
			if m:
				key = m.group(1) or m.group(2)
				ver, disp = m.group(3), m.group(4)
				entries[key] = {
					"kind": "versioned",
					"requiredVersion": None if ver == "nil" else int(ver),
					"displayVersion": disp,
					"line": stripped,
				}
				continue

			m = ROW_ENTRY_RE.match(stripped)
			if m:
				ver = m.group(2)
				fields = stripped.split("\t")
				esoui_id = fields[3] if len(fields) > 3 else ""
				entries[m.group(1)] = {
					"kind": "versioned",
					"requiredVersion": int(ver) if re.fullmatch(r"-?\d+", ver) else None,
					"displayVersion": m.group(3),
					"esouiId": int(esoui_id) if esoui_id.isdigit() else None,
					"line": stripped,
				}
				continue

			m = VALUE_ENTRY_RE.match(stripped)
			if m:
				entries[m.group(1)] = {
					"kind": "value",
					"value": m.group(2),
					"line": stripped,
				}
				continue

			m = LIST_ENTRY_RE.match(stripped)
			if m:
				key = m.group(1)
				deps = tuple(sorted(re.findall(r'"([^"]*)"', m.group(2))))
				entries[key] = {
					"kind": "list",
					"deps": deps,
					"line": stripped,
				}
	return entries


def match_entry_key(line):
	m = VERSIONED_ENTRY_RE.match(line)
	if m:
		return m.group(1) or m.group(2)
	m = ROW_ENTRY_RE.match(line)
	if m:
		return m.group(1)
	m = VALUE_ENTRY_RE.match(line)
	if m:
		return m.group(1)
	m = LIST_ENTRY_RE.match(line)
	if m:
		return m.group(1)
	return None


def entries_equal(a, b):
	if a["kind"] != b["kind"]:
		return False
	if a["kind"] == "list":
		return a["deps"] == b["deps"]
	if a["kind"] == "value":
		return a["value"] == b["value"]
	return a["requiredVersion"] == b["requiredVersion"] and a["displayVersion"] == b["displayVersion"]


def classify(base_entries, head_entries):
	base_keys = set(base_entries)
	head_keys = set(head_entries)

	added = sorted(head_keys - base_keys)
	removed = sorted(base_keys - head_keys)
	common = base_keys & head_keys
	modified = sorted(k for k in common if not entries_equal(base_entries[k], head_entries[k]))

	problems = []
	safe_updates = []
	list_changes = []

	for key in modified:
		old = base_entries[key]
		new = head_entries[key]

		if new["kind"] in ("list", "value") or old["kind"] in ("list", "value"):
			list_changes.append(key)
			continue

		if new["requiredVersion"] is None:
			if old["requiredVersion"] is not None:
				problems.append(f'"{key}": requiredVersion changed from {old["requiredVersion"]} to nil - needs a human to confirm this library genuinely stopped exposing an AddOnVersion.')
			continue

		if old["requiredVersion"] is not None and new["requiredVersion"] < old["requiredVersion"]:
			problems.append(f'"{key}": requiredVersion would go backwards ({old["requiredVersion"]} -> {new["requiredVersion"]}).')
			continue

		if new["displayVersion"].strip() == "":
			problems.append(f'"{key}": displayVersion is empty.')
			continue

		safe_updates.append(key)

	return {
		"added": added,
		"removed": removed,
		"modified": modified,
		"safe_updates": safe_updates,
		"problems": problems,
		"list_changes": list_changes,
	}


def validate_against_esoui(entries, keys, catalog, category_names):
	verified, mismatched, unknown = [], [], []
	for key in sorted(keys):
		entry = entries.get(key)
		if entry is None:
			continue
		if entry["kind"] == "value":
			if entry["value"] in category_names:
				verified.append(f'"{key}": category "{entry["value"]}" exists on ESOUI.')
			else:
				mismatched.append(f'"{key}": category "{entry["value"]}" is not an ESOUI category.')
			continue
		candidates = catalog.get(key)
		if not candidates:
			unknown.append(f'"{key}": no add-on with this folder name is listed on ESOUI - a human has to confirm it is real.')
			continue
		row = pick_listing(key, candidates, entry.get("esouiId"))
		if entry["kind"] == "list":
			verified.append(f'"{key}": listed on ESOUI (id {row["esoui_id"]}), but its dependency list cannot be checked automatically.')
			continue
		problems = []
		if entry.get("esouiId") and entry["esouiId"] != row["esoui_id"]:
			problems.append(f'esouiId {entry["esouiId"]} but ESOUI says {row["esoui_id"]}')
		if row["version"] and entry["displayVersion"] and entry["displayVersion"] != row["version"]:
			problems.append(f'displayVersion "{entry["displayVersion"]}" but ESOUI says "{row["version"]}"')
		if row["addon_version"] and entry["requiredVersion"] and entry["requiredVersion"] > row["addon_version"]:
			problems.append(f'requiredVersion {entry["requiredVersion"]} is newer than the {row["addon_version"]} ESOUI lists')
		if problems:
			mismatched.append(f'"{key}": ' + "; ".join(problems) + ".")
		else:
			verified.append(f'"{key}": matches ESOUI (id {row["esoui_id"]}, version "{row["version"]}").')
	return verified, mismatched, unknown


def revalidate_against_fresh(safe_keys, head_entries, fresh_entries):
	still_safe = []
	skipped = []

	for key in safe_keys:
		new = head_entries[key]
		fresh = fresh_entries.get(key)

		if fresh is None:
			skipped.append(f'"{key}": no longer exists on the target branch - someone else must have removed/renamed it since this PR was checked, skipping.')
			continue

		if fresh["line"] == new["line"]:
			skipped.append(f'"{key}": target branch already has this exact entry (someone else merged the same change), nothing to apply.')
			continue

		if fresh["requiredVersion"] is not None and new["requiredVersion"] is not None and new["requiredVersion"] < fresh["requiredVersion"]:
			skipped.append(f'"{key}": target branch already moved to {fresh["requiredVersion"]}, this PR\'s {new["requiredVersion"]} would go backwards - skipping, needs a human.')
			continue

		still_safe.append(key)

	return still_safe, skipped


def apply_safe_updates(fresh_base_path, head_entries, safe_keys, output_path):
	with open(fresh_base_path, encoding="utf-8-sig", errors="ignore") as f:
		lines = f.readlines()

	applied = []
	safe_key_set = set(safe_keys)
	for i, line in enumerate(lines):
		key = match_entry_key(line.rstrip("\n"))
		if key is None:
			continue
		if key in safe_key_set:
			lines[i] = head_entries[key]["line"] + "\n"
			applied.append(key)

	with open(output_path, "w", encoding="utf-8") as f:
		f.writelines(lines)

	return applied


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--base-file", required=True, help="Path to the file as it existed at the PR's merge-base")
	parser.add_argument("--head-file", required=True, help="Path to the file as it exists in the PR")
	parser.add_argument("--github-output", default=None, help="Path to $GITHUB_OUTPUT, if running in Actions")
	parser.add_argument("--fresh-base-file", default=None, help="A freshly-fetched copy of the target branch's file, read immediately before applying. Each safe_update is re-validated against THIS file's current per-key value (not a full re-diff, which would spuriously flag unrelated drift) before being written - required together with --apply-output")
	parser.add_argument("--skip-esoui-check", action="store_true", help="Do not check the submitted entries against the public ESOUI catalog")
	parser.add_argument("--filelist", default="", help="Local copy of filelist.json instead of fetching it")
	parser.add_argument("--categorylist", default="", help="Local copy of categorylist.json instead of fetching it")
	parser.add_argument("--esoui-timeout", type=float, default=30.0)
	parser.add_argument("--apply-output", default=None, help="If set (together with --fresh-base-file), write the fresh-base-file with only the still-safe entries swapped in, to this path")
	args = parser.parse_args()

	base_entries = parse_table(args.base_file)
	head_entries = parse_table(args.head_file)
	result = classify(base_entries, head_entries)

	verified, mismatched, unknown = [], [], []
	checked_keys = set(result["added"]) | set(result["modified"])
	if checked_keys and not args.skip_esoui_check:
		try:
			catalog, category_names = load_catalog(args.filelist, args.categorylist, args.esoui_timeout)
			verified, mismatched, unknown = validate_against_esoui(head_entries, checked_keys, catalog, category_names)
		except Exception as error:
			unknown.append(f"Could not reach the ESOUI catalog ({error}) - every changed entry needs a human.")
			result["safe_updates"] = []

	if mismatched or unknown:
		result["safe_updates"] = [k for k in result["safe_updates"] if not any(f'"{k}"' in line for line in mismatched + unknown)]

	needs_review = bool(result["added"] or result["removed"] or result["problems"] or result["list_changes"] or mismatched or unknown)
	safe_to_merge = (not needs_review) and bool(result["safe_updates"])

	lines = []
	if result["added"]:
		lines.append("New entries (always need a human to check for a troll/bogus submission before this gets added):")
		for k in result["added"]:
			lines.append(f"  - {k}")
	if result["removed"]:
		lines.append("Removed entries (always need a human to confirm this is intentional):")
		for k in result["removed"]:
			lines.append(f"  - {k}")
	if result["list_changes"]:
		lines.append("Dependency-list entries changed (no version field to auto-verify against, always needs a human):")
		for k in result["list_changes"]:
			old_deps = base_entries[k]["deps"] if base_entries[k]["kind"] == "list" else None
			new_deps = head_entries[k]["deps"] if head_entries[k]["kind"] == "list" else None
			lines.append(f"  - {k}: {old_deps} -> {new_deps}")
	if result["problems"]:
		lines.append("Problems found:")
		for p in result["problems"]:
			lines.append(f"  - {p}")
	if mismatched:
		lines.append("Checked against ESOUI and wrong (a human has to look):")
		for line in mismatched:
			lines.append(f"  - {line}")
	if unknown:
		lines.append("Could not be checked against ESOUI:")
		for line in unknown:
			lines.append(f"  - {line}")
	if verified:
		lines.append("Checked against ESOUI and correct:")
		for line in verified:
			lines.append(f"  - {line}")
	if result["safe_updates"]:
		lines.append("Version bumps that passed every automated check:")
		for k in result["safe_updates"]:
			lines.append(f'  - {k}: requiredVersion {base_entries[k]["requiredVersion"]} -> {head_entries[k]["requiredVersion"]}')

	report = "\n".join(lines) if lines else "No entries changed."
	print(report)

	summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
	if summary_path:
		with open(summary_path, "a", encoding="utf-8") as f:
			f.write("## Library Submission Check\n\n")
			f.write(f"```\n{report}\n```\n")

	if args.github_output:
		with open(args.github_output, "a", encoding="utf-8") as f:
			f.write(f"needs_review={'true' if needs_review else 'false'}\n")
			f.write(f"safe_to_merge={'true' if safe_to_merge else 'false'}\n")
			f.write(f"safe_keys={','.join(result['safe_updates'])}\n")

	if needs_review:
		print("::warning::This PR needs a human to review it - see the summary above.")
	if not (result["added"] or result["removed"] or result["modified"]):
		print("::warning::No recognizable entries changed in this file - check the PR touches the right file/format.")

	if not head_entries and os.path.isfile(args.head_file):
		print("::warning::No entries in this file matched either known table format (versioned or dependency-list) - check the file/format.")

	if args.apply_output:
		if not args.fresh_base_file:
			print("::error::--apply-output requires --fresh-base-file.")
			return 1
		if needs_review or not result["safe_updates"]:
			print("::warning::Nothing was safe to apply even before checking the fresh base-file - writing nothing.")
		else:
			fresh_entries = parse_table(args.fresh_base_file)
			still_safe, skipped = revalidate_against_fresh(result["safe_updates"], head_entries, fresh_entries)
			for s in skipped:
				print(f"::warning::Skipped at apply time - {s}")
			if still_safe:
				applied = apply_safe_updates(args.fresh_base_file, head_entries, still_safe, args.apply_output)
				print(f"Applied against the fresh target-branch file: {', '.join(applied)}")
			else:
				print("::warning::Nothing was still safe against the fresh target-branch file - writing nothing.")

	return 0


if __name__ == "__main__":
	sys.exit(main())
