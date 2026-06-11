param(
    [string]$MaterialsDirectory = "",
    [string]$EntryPackDirectory = "",
    [string]$SubmissionPacketDirectory = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

function Resolve-RepositoryRoot {
    $repoRoot = ""
    try {
        $repoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
    } catch {
        $repoRoot = ""
    }

    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }

    return [System.IO.Path]::GetFullPath($repoRoot)
}

function Get-DocumentsDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [Environment]::GetFolderPath("UserProfile")
    }
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [System.IO.Path]::GetTempPath()
    }
    return $documents
}

function Resolve-PathOrDefault($path, $defaultLeafName) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        return [System.IO.Path]::GetFullPath((Join-Path (Get-DocumentsDirectory) $defaultLeafName))
    }
    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Test-FilePresent($path) {
    return (Test-Path $path -PathType Leaf)
}

function Test-FirstFile($directory, $filter) {
    if (-not (Test-Path $directory -PathType Container)) {
        return $false
    }

    $file = Get-ChildItem -LiteralPath $directory -Filter $filter -File -ErrorAction SilentlyContinue | Select-Object -First 1
    return ($null -ne $file -and $file.Length -gt 0)
}

function Add-Action($actions, $title, $detail, $command, $evidence) {
    $actions.Add([pscustomobject]@{
        Title = $title
        Detail = $detail
        Command = $command
        Evidence = $evidence
    }) | Out-Null
}

function Get-ReleaseActions($materialsPath, $entryPackPath, $submissionPacketPath) {
    $actions = New-Object "System.Collections.Generic.List[object]"

    if (-not (Test-Path $materialsPath -PathType Container)) {
        Add-Action $actions `
            "Create the private Apple materials folder" `
            "Prepare the local folder that will hold Apple account, signing, review, DSA, and release evidence. Keep it outside the repository." `
            "powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1 -OutputDirectory `"$materialsPath`"" `
            "The folder exists and contains README.md plus 00-account, 01-app-store-connect-api-key, 02-signing, 03-review-contact, 04-eu-dsa, and 05-release-evidence."
    }

    if (-not (Test-Path $materialsPath -PathType Container)) {
        if (-not (Test-Path $entryPackPath -PathType Container)) {
            Add-Action $actions `
                "Export the App Store Connect entry packet" `
                "Generate paste-ready app record, pricing, availability, privacy, compliance, and review fields from repository sources." `
                "powershell -ExecutionPolicy Bypass -File scripts/export-app-store-connect-entry-pack.ps1 -OutputDirectory `"$entryPackPath`" -Owner `"ahuxxly`" -RepoName `"snaptable-reminder-ios`"" `
                "The entry packet folder contains app-store-connect-entry-pack.json and the numbered paste files."
        }
        return $actions
    }

    $accountPath = Join-Path $materialsPath "00-account\account-private-status.md"
    if (-not (Test-FilePresent $accountPath)) {
        Add-Action $actions `
            "Complete Apple account and paid app setup" `
            "Confirm Apple Developer Program, Paid Apps Agreement, tax, banking, and the App Store Connect app record for com.snaptable.reminder." `
            "# Open App Store Connect, complete Account and Business setup, then write private notes to `"$accountPath`"." `
            "account-private-status.md mentions Apple Developer Program, Paid Apps Agreement, tax, banking, and com.snaptable.reminder."
    }

    $apiKeyDirectory = Join-Path $materialsPath "01-app-store-connect-api-key"
    if (-not (Test-FirstFile $apiKeyDirectory "AuthKey_*.p8")) {
        Add-Action $actions `
            "Download the App Store Connect API key" `
            "Create an App Store Connect API key with app management access and save the one-time .p8 download in the private materials folder." `
            "# Save the key as `"$apiKeyDirectory\AuthKey_<key-id>.p8`"." `
            "The .p8 file exists and starts with BEGIN PRIVATE KEY."
    }

    $signingDirectory = Join-Path $materialsPath "02-signing"
    $hasCertificate = Test-FirstFile $signingDirectory "*.p12"
    $hasProfile = Test-FirstFile $signingDirectory "*.mobileprovision"
    if (-not $hasCertificate -or -not $hasProfile) {
        Add-Action $actions `
            "Create Apple signing assets" `
            "Export an Apple Distribution .p12 certificate and download an App Store provisioning profile for com.snaptable.reminder." `
            "# Place the files in `"$signingDirectory`", or run scripts/stage-apple-release-materials.ps1 after downloading them." `
            "02-signing contains a non-empty .p12 file and a non-empty .mobileprovision file."
    }

    $releaseSecretsPath = Join-Path $materialsPath "release-secrets.private.json"
    if (-not (Test-FilePresent $releaseSecretsPath)) {
        Add-Action $actions `
            "Write private release secret values" `
            "Record the Apple username, team id, API key id, issuer id, certificate password, and temporary CI keychain password outside the repository." `
            "# Use scripts/stage-apple-release-materials.ps1 -DryRun first, then remove -DryRun when every value is correct." `
            "release-secrets.private.json exists and validates with scripts/prepare-apple-materials-folder.ps1 -ValidateOnly."
    }

    $reviewContactPath = Join-Path $materialsPath "03-review-contact\review-contact.private.json"
    if (-not (Test-FilePresent $reviewContactPath)) {
        Add-Action $actions `
            "Add private App Review contact details" `
            "Choose a reachable first name, last name, email, and phone number for Apple review. Do not commit these values." `
            "# Write `"$reviewContactPath`", or let scripts/stage-apple-release-materials.ps1 create it from parameters." `
            "review-contact.private.json contains firstName, lastName, email, and phone."
    }

    $dsaEvidencePath = Join-Path $materialsPath "04-eu-dsa\dsa-private-evidence.md"
    if (-not (Test-FilePresent $dsaEvidencePath)) {
        Add-Action $actions `
            "Record EU DSA trader status evidence" `
            "Complete the EU Digital Services Act trader-status decision before keeping EU storefronts in version 1." `
            "# Write private notes to `"$dsaEvidencePath`" after completing the App Store Connect DSA flow." `
            "dsa-private-evidence.md records EU storefronts and trader status decision."
    }

    $setupEvidencePath = Join-Path $materialsPath "05-release-evidence\app-store-connect-setup.private.json"
    if (-not (Test-FilePresent $setupEvidencePath)) {
        Add-Action $actions `
            "Record App Store Connect setup evidence" `
            "After the app record, pricing, availability, privacy, age rating, export compliance, and EU DSA fields match the source fields, record that proof locally." `
            "powershell -ExecutionPolicy Bypass -File scripts/record-app-store-connect-setup-evidence.ps1 -MaterialsDirectory `"$materialsPath`" -AppStoreConnectAppId `"1234567890`" -AppName `"SnapTable Reminder`" -BundleId `"com.snaptable.reminder`" -Sku `"SNAPTABLE-REMINDER-IOS-V1`" -PrimaryLanguage `"en-US`" -PrimaryCategory `"Productivity`" -PriceCurrency `"USD`" -PriceAmount `"1.99`" -AvailabilityMode `"selectedCountriesOrRegions`" -ExcludedCountriesOrRegions `"China mainland`" -PrivacyPolicyUrl `"https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html`" -SupportUrl `"https://ahuxxly.github.io/snaptable-reminder-ios/support.html`" -PrivacyAnswersCompleted -AgeRatingCompleted -ExportComplianceCompleted -EuDsaTraderStatusCompleted -DryRun" `
            "05-release-evidence/app-store-connect-setup.private.json exists and release-doctor accepts it."
        return $actions
    }

    $releaseEvidencePath = Join-Path $materialsPath "05-release-evidence\release-evidence.private.json"
    if (-not (Test-FilePresent $releaseEvidencePath)) {
        $uploadCommand = @(
            "powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -MaterialsDirectory `"$materialsPath`" -DryRun",
            "powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -DryRun",
            "powershell -ExecutionPolicy Bypass -File scripts/github-run-app-store-release.ps1 -ConfirmUseActionsMinutes YES -Wait"
        ) -join "`n"
        Add-Action $actions `
            "Upload metadata, screenshots, and TestFlight build" `
            "Set GitHub secrets from the private materials folder, then run the release workflows after dry-run previews." `
            $uploadCommand `
            "GitHub Actions show successful metadata, screenshot, review check, and TestFlight upload runs."
        Add-Action $actions `
            "Record App Store release evidence" `
            "After App Store Connect shows the build processed and App Review submission status, record that evidence locally." `
            "powershell -ExecutionPolicy Bypass -File scripts/record-app-store-release-evidence.ps1 -MaterialsDirectory `"$materialsPath`" -AppStoreConnectAppId `"1234567890`" -AppVersion `"1.0`" -BuildNumber `"1`" -MetadataUploaded -ScreenshotsUploaded -ReviewCheckPassed -TestFlightUploaded -BuildProcessed -AppReviewSubmitted -AppStatus `"Waiting for Review`" -DryRun" `
            "05-release-evidence/release-evidence.private.json exists and records Waiting for Review or later."
        return $actions
    }

    Add-Action $actions `
        "Run release doctor for final status" `
        "All private materials and evidence are recorded locally. Now run the full release doctor and use its remaining gates as the authoritative final checklist." `
        "powershell -ExecutionPolicy Bypass -File scripts/release-doctor.ps1 -RunPreflight -EntryPackDirectory `"$entryPackPath`" -SubmissionPacketDirectory `"$submissionPacketPath`" -MaterialsDirectory `"$materialsPath`"" `
        "Release doctor reports zero blocked gates, or only external App Store status that must be checked in App Store Connect."

    return $actions
}

function Write-MarkdownPacket($path, $materialsPath, $entryPackPath, $submissionPacketPath, $actions) {
    $parent = Split-Path -Parent $path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $generatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    $lines = New-Object "System.Collections.Generic.List[string]"
    $lines.Add("# SnapTable Reminder Apple Release Next Actions") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Generated at: $generatedAt") | Out-Null
    $lines.Add("Materials folder: $materialsPath") | Out-Null
    $lines.Add("Entry packet folder: $entryPackPath") | Out-Null
    $lines.Add("Submission packet folder: $submissionPacketPath") | Out-Null
    $lines.Add("") | Out-Null

    $hasFinalDoctorAction = ($actions.Count -eq 1 -and $actions[0].Title -eq "Run release doctor for final status")
    if ($hasFinalDoctorAction) {
        $lines.Add("All private materials and evidence are recorded locally. The next step is final verification, not more local collection.") | Out-Null
        $lines.Add("") | Out-Null
    }

    $lines.Add("## Next Action") | Out-Null
    $lines.Add("") | Out-Null
    if ($actions.Count -eq 0) {
        $lines.Add("No local action was detected.") | Out-Null
    } else {
        $next = $actions[0]
        $lines.Add("1. $($next.Title)") | Out-Null
        $lines.Add("") | Out-Null
        $lines.Add($next.Detail) | Out-Null
        $lines.Add("") | Out-Null
        $lines.Add("Evidence to keep: $($next.Evidence)") | Out-Null
        $lines.Add("") | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($next.Command)) {
            $lines.Add('```powershell') | Out-Null
            foreach ($commandLine in ($next.Command -split "`n")) {
                $lines.Add($commandLine) | Out-Null
            }
            $lines.Add('```') | Out-Null
            $lines.Add("") | Out-Null
        }
    }

    $lines.Add("## Ordered Checklist") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($action in $actions) {
        $lines.Add("- [ ] $($action.Title)") | Out-Null
        $lines.Add("  Evidence: $($action.Evidence)") | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($action.Command)) {
            $firstCommandLine = ($action.Command -split "`n" | Select-Object -First 1)
            $lines.Add("  Command: $firstCommandLine") | Out-Null
        }
    }
    $lines.Add("") | Out-Null

    $lines.Add("## Safety Rules") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Do not paste private Apple values into GitHub issues, commits, public docs, screenshots, or chat unless you intentionally redact them first.") | Out-Null
    $lines.Add("- Keep .p8 keys, .p12 certificates, mobileprovision files, tax, banking, identity, and App Review contact details outside this repository.") | Out-Null
    $lines.Add("- Use every command with -DryRun first when the command supports it.") | Out-Null
    $lines.Add("- Version 1 remains paid upfront, local-only, no backend, no analytics, no tracking, and no China mainland availability.") | Out-Null

    Set-Content -Path $path -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
}

$repoRoot = Resolve-RepositoryRoot
$materialsPath = Resolve-PathOrDefault $MaterialsDirectory "SnapTableReminder-Apple-Materials"
$entryPackPath = Resolve-PathOrDefault $EntryPackDirectory "SnapTableReminder-AppStoreConnect-EntryPack"
$submissionPacketPath = Resolve-PathOrDefault $SubmissionPacketDirectory "SnapTableReminder-AppStoreSubmissionPacket"
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path (Get-DocumentsDirectory) "SnapTableReminder-Apple-Next-Actions.md"
}
$resolvedOutputPath = Resolve-PathOrDefault $OutputPath "SnapTableReminder-Apple-Next-Actions.md"

Push-Location $repoRoot
try {
    $actions = @(Get-ReleaseActions $materialsPath $entryPackPath $submissionPacketPath)
    Write-MarkdownPacket $resolvedOutputPath $materialsPath $entryPackPath $submissionPacketPath $actions
} finally {
    Pop-Location
}

$nextTitle = "No local action detected"
if ($actions.Count -gt 0) {
    $nextTitle = $actions[0].Title
}

Write-Section "Apple release next actions"
Write-Host "materials=$materialsPath"
Write-Host "entryPack=$entryPackPath"
Write-Host "submissionPacket=$submissionPacketPath"
Write-Host "output=$resolvedOutputPath"
Write-Host "next=$nextTitle"
