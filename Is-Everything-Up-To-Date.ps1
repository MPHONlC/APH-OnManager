# APH-OnManager - Copyright 2026 @APHONlC.
# Licensed under the GNU General Public License v3.0 (GPLv3).
# See LICENSE.md and NOTICE.md.

$RepoRawBase = "https://raw.githubusercontent.com/MPHONlC/APH-OnManager/main/DATA"

Write-Host "=== Is Everything Up to Date? ==="
Write-Host ""

Set-Location -Path $PSScriptRoot

function Get-EntryKey($line) {
	if ($line -match '^\t\["([^"]+)"\]') { return $matches[1] }
	if ($line -match '^\t([A-Za-z0-9_.\-]+) = \{') { return $matches[1] }
	return $null
}

function Get-EntryVersion($line) {
	if ($line -match 'requiredVersion = (\d+)') { return [int]$matches[1] }
	return -1
}

function Get-EntryDisplay($line) {
	if ($line -match 'displayVersion = "([^"]*)"') { return $matches[1] }
	return ""
}

function Merge-KnownTable($localLines, $remoteLines) {
	$order = New-Object System.Collections.Generic.List[string]
	$lineByKey = @{}
	$verByKey = @{}
	$header = New-Object System.Collections.Generic.List[string]
	$inTable = $false
	$added = 0
	$updated = 0
	$details = New-Object System.Collections.Generic.List[string]

	foreach ($line in $localLines) {
		$key = Get-EntryKey $line
		if ($key) {
			if (-not $lineByKey.ContainsKey($key)) { $order.Add($key) | Out-Null }
			$lineByKey[$key] = $line
			$verByKey[$key] = Get-EntryVersion $line
		} elseif (-not $inTable) {
			$header.Add($line) | Out-Null
		}
		if ($line -match ' = \{$') { $inTable = $true }
	}

	foreach ($line in $remoteLines) {
		$key = Get-EntryKey $line
		if ($key) {
			$rver = Get-EntryVersion $line
			$rdisp = Get-EntryDisplay $line
			if (-not $lineByKey.ContainsKey($key)) {
				$order.Add($key) | Out-Null
				$lineByKey[$key] = $line
				$verByKey[$key] = $rver
				$added++
				$details.Add("+ ${key}: new entry, version $rver ($rdisp)") | Out-Null
			} elseif ($rver -gt $verByKey[$key]) {
				$oldVer = $verByKey[$key]
				$oldDisp = Get-EntryDisplay $lineByKey[$key]
				$lineByKey[$key] = $line
				$verByKey[$key] = $rver
				$updated++
				$details.Add("~ ${key}: $oldVer ($oldDisp) -> $rver ($rdisp)") | Out-Null
			}
		}
	}

	$sortedKeys = $order | Sort-Object { $_.ToLower() }
	$output = New-Object System.Collections.Generic.List[string]
	foreach ($h in $header) { $output.Add($h) | Out-Null }
	foreach ($k in $sortedKeys) { $output.Add($lineByKey[$k]) | Out-Null }
	$output.Add("}") | Out-Null

	return @{ Lines = $output; Added = $added; Updated = $updated; Details = $details }
}

function Sync-Table($fileName) {
	$localFile = "DATA\$fileName"
	if (-not (Test-Path $localFile)) {
		Write-Host "ERROR: $localFile not found. Run this script from inside your APH-OnManager addon folder."
		return
	}

	Write-Host "Checking $fileName ..."
	$tmpRemote = [System.IO.Path]::GetTempFileName()
	try {
		Invoke-WebRequest -Uri "$RepoRawBase/$fileName" -OutFile $tmpRemote -UseBasicParsing
	} catch {
		Write-Host "  ERROR: could not download $fileName from GitHub."
		Write-Host "  Check your internet connection, or that RepoRawBase above still points at the right branch."
		Remove-Item $tmpRemote -ErrorAction SilentlyContinue
		return
	}

	$localLines = Get-Content $localFile
	$remoteLines = Get-Content $tmpRemote
	Remove-Item $tmpRemote -ErrorAction SilentlyContinue

	$result = Merge-KnownTable $localLines $remoteLines

	if (($result.Lines -join "`n") -eq ($localLines -join "`n")) {
		Write-Host "  Already up to date."
	} else {
		Set-Content -Path $localFile -Value $result.Lines
		Write-Host "  Updated: $($result.Updated) entries bumped, $($result.Added) new entries added."
		foreach ($detail in $result.Details) {
			Write-Host "    $detail"
		}
	}
}

try {
	Sync-Table "KnownLibraries.lua"
	Sync-Table "KnownAddonVersions.lua"

	Write-Host ""
	Write-Host "Reload your UI (/reloadui) for any change to take effect."
} finally {
	Write-Host ""
	Read-Host "Press Enter to close this window"
}
