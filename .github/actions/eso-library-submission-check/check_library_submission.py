#!/usr/bin/env python3
import argparse
import os
import re
import sys

VERSIONED_ENTRY_RE = re.compile(
	r'^\t(?:\["([^"]+)"\]|([A-Za-z_][A-Za-z0-9_.-]*))\s*=\s*\{'
	r'.*?requiredVersion\s*=\s*(nil|-?\d+).*?displayVersion\s*=\s*"([^"]*)".*?\}\s*,?\s*$'
)

LIST_ENTRY_RE = re.compile(
	r'^\t\["([^"]+)"\]\s*=\s*\{\s*((?:"[^"]*"\s*,?\s*)*)\}\s*,?\s*$'
)


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
	m = LIST_ENTRY_RE.match(line)
	if m:
		return m.group(1)
	return None


def entries_equal(a, b):
	if a["kind"] != b["kind"]:
		return False
	if a["kind"] == "list":
		return a["deps"] == b["deps"]
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

		if new["kind"] == "list" or old["kind"] == "list":
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
	parser.add_argument("--apply-output", default=None, help="If set (together with --fresh-base-file), write the fresh-base-file with only the still-safe entries swapped in, to this path")
	args = parser.parse_args()

	base_entries = parse_table(args.base_file)
	head_entries = parse_table(args.head_file)
	result = classify(base_entries, head_entries)

	needs_review = bool(result["added"] or result["removed"] or result["problems"] or result["list_changes"])
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
