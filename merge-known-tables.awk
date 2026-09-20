# APH-OnManager - Copyright 2026 @APHONlC.
# Licensed under the GNU General Public License v3.0 (GPLv3).
# See LICENSE.md and NOTICE.md.

function extract_key(line,    k) {
	k = line
	if (sub(/^\t\["/, "", k)) {
		sub(/"\].*/, "", k)
		return k
	}
	k = line
	if (sub(/^\t/, "", k) && sub(/ = \{.*/, "", k) && k !~ / /) {
		return k
	}
	return ""
}
function extract_version(line,    v) {
	v = line
	if (sub(/.*requiredVersion = /, "", v)) {
		sub(/[^0-9].*/, "", v)
		return v + 0
	}
	return -1
}
function extract_display(line,    v) {
	v = line
	if (sub(/.*displayVersion = "/, "", v)) {
		sub(/".*/, "", v)
		return v
	}
	return ""
}
FNR == NR {
	key = extract_key($0)
	if (key != "") {
		if (!(key in local_line)) local_order[++n] = key
		local_line[key] = $0
		local_ver[key] = extract_version($0)
	} else if (!in_table) {
		header[++h] = $0
	}
	if ($0 ~ / = \{$/) in_table = 1
	next
}
{
	key = extract_key($0)
	if (key != "") {
		rver = extract_version($0)
		rdisp = extract_display($0)
		if (!(key in local_line)) {
			local_order[++n] = key
			local_line[key] = $0
			local_ver[key] = rver
			added++
			added_detail[added] = key ": new entry, version " rver " (" rdisp ")"
		} else if (rver > local_ver[key]) {
			old_ver = local_ver[key]
			old_disp = extract_display(local_line[key])
			local_line[key] = $0
			local_ver[key] = rver
			updated++
			updated_detail[updated] = key ": " old_ver " (" old_disp ") -> " rver " (" rdisp ")"
		}
	}
}
END {
	for (i = 2; i <= n; i++) {
		key_i = local_order[i]
		j = i - 1
		while (j >= 1 && tolower(local_order[j]) > tolower(key_i)) {
			local_order[j + 1] = local_order[j]
			j--
		}
		local_order[j + 1] = key_i
	}
	for (i = 1; i <= h; i++) print header[i]
	for (i = 1; i <= n; i++) print local_line[local_order[i]]
	print "}"
	print "ADDED=" added+0 > "/dev/stderr"
	print "UPDATED=" updated+0 > "/dev/stderr"
	for (i = 1; i <= added; i++) print "# + " added_detail[i] > "/dev/stderr"
	for (i = 1; i <= updated; i++) print "# ~ " updated_detail[i] > "/dev/stderr"
}
