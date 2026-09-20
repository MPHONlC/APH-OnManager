#!/bin/bash
# APH-OnManager - Copyright 2026 @APHONlC.
# Licensed under the GNU General Public License v3.0 (GPLv3).
# See LICENSE.md and NOTICE.md.

REPO_RAW_BASE="https://raw.githubusercontent.com/MPHONlC/APH-OnManager/main/DATA"

if [[ -t 0 ]]; then
	trap 'echo ""; read -r -p "Press Enter to close this window..."' EXIT
fi

echo "=== Is Everything Up to Date? ==="
echo ""

cd "$(dirname "$0")" || exit 1

if [[ ! -f "merge-known-tables.awk" ]]; then
	echo "ERROR: merge-known-tables.awk not found next to this script."
	exit 1
fi

sync_table() {
	local file_name="$1"
	local local_file="DATA/${file_name}"

	if [[ ! -f "$local_file" ]]; then
		echo "ERROR: $local_file not found. Run this script from inside your APH-OnManager addon folder."
		return 1
	fi

	local tmp_remote
	tmp_remote=$(mktemp)
	echo "Checking ${file_name} ..."
	if ! curl -fsSL "${REPO_RAW_BASE}/${file_name}" -o "$tmp_remote"; then
		echo "  ERROR: could not download ${file_name} from GitHub."
		echo "  Check your internet connection, or that REPO_RAW_BASE above still points at the right branch."
		rm -f "$tmp_remote"
		return 1
	fi

	local tmp_merged tmp_stats
	tmp_merged=$(mktemp)
	tmp_stats=$(mktemp)
	awk -f merge-known-tables.awk "$local_file" "$tmp_remote" > "$tmp_merged" 2> "$tmp_stats"
	source "$tmp_stats"

	if cmp -s "$local_file" "$tmp_merged"; then
		echo "  Already up to date."
	else
		mv "$tmp_merged" "$local_file"
		echo "  Updated: ${UPDATED:-0} entr$([[ "${UPDATED:-0}" == "1" ]] && echo y || echo ies) bumped, ${ADDED:-0} new entr$([[ "${ADDED:-0}" == "1" ]] && echo y || echo ies) added."
		while IFS= read -r detail_line; do
			echo "    ${detail_line#\# }"
		done < <(grep '^# ' "$tmp_stats")
	fi

	rm -f "$tmp_remote" "$tmp_merged" "$tmp_stats"
}

sync_table "KnownLibraries.lua"
sync_table "KnownAddonVersions.lua"

echo ""
echo "Reload your UI (/reloadui) for any change to take effect."
