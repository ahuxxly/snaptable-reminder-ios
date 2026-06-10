$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

Write-Section "Git status"
$gitStatus = git status --short
if ($gitStatus) {
    Write-Host $gitStatus
    throw "Working tree is not clean."
}
Write-Host "clean"

Write-Section "Marker scan"
$markerTerms = @("TO" + "DO", "TB" + "D", "PLACE" + "HOLDER", "example" + "\.com", "YOU" + "R_", "your" + "-domain")
$markerPattern = $markerTerms -join "|"
$markerOutput = rg $markerPattern . 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host $markerOutput
    throw "Unfinished marker text found."
}
if ($LASTEXITCODE -gt 1) {
    throw "Marker scan failed."
}
Write-Host "no unfinished markers"

Write-Section "Encoding damage scan"
$encodingOutput = @()
$mojibakeChars = @([char]0xFFFD, [char]0x00C3, [char]0x00C2)
foreach ($char in $mojibakeChars) {
    $scan = rg --fixed-strings ([string]$char) SnapTableReminder docs site README.md project.yml scripts .github fastlane Gemfile 2>$null
    if ($LASTEXITCODE -eq 0) {
        $encodingOutput += $scan
    } elseif ($LASTEXITCODE -gt 1) {
        throw "Encoding scan failed."
    }
}
if ($encodingOutput.Count -gt 0) {
    Write-Host ($encodingOutput -join [Environment]::NewLine)
    throw "Potential mojibake text found."
}
Write-Host "no common mojibake markers"

Write-Section "Resource parsing"
Get-Content "SnapTableReminder\Resources\Assets.xcassets\Contents.json" | ConvertFrom-Json | Out-Null
$appIconContents = Get-Content "SnapTableReminder\Resources\Assets.xcassets\AppIcon.appiconset\Contents.json" | ConvertFrom-Json
Get-Content "SnapTableReminder\Resources\Localizable.xcstrings" | ConvertFrom-Json | Out-Null
[xml](Get-Content "SnapTableReminder\Resources\Info.plist" -Raw) | Out-Null
$privacyManifest = [xml](Get-Content "SnapTableReminder\Resources\PrivacyInfo.xcprivacy" -Raw)
Write-Host "resources parse"

Write-Section "Asset references"
$appIconDirectory = "SnapTableReminder\Resources\Assets.xcassets\AppIcon.appiconset"
foreach ($image in $appIconContents.images) {
    if ($image.filename) {
        $imagePath = Join-Path $appIconDirectory $image.filename
        if (-not (Test-Path $imagePath)) {
            throw "Missing app icon file referenced by asset catalog: $($image.filename)"
        }
    }
}
Write-Host "app icon references valid"

Write-Section "Privacy manifest coverage"
$usesUserDefaults = rg "UserDefaults" SnapTableReminder 2>$null
if ($LASTEXITCODE -eq 0) {
    $privacyText = $privacyManifest.OuterXml
    if (-not $privacyText.Contains("NSPrivacyAccessedAPICategoryUserDefaults")) {
        throw "UserDefaults is used but PrivacyInfo.xcprivacy does not declare NSPrivacyAccessedAPICategoryUserDefaults."
    }
    if (-not $privacyText.Contains("CA92.1")) {
        throw "UserDefaults is used but PrivacyInfo.xcprivacy does not include reason CA92.1."
    }
    Write-Host "UserDefaults required reason declared"
} elseif ($LASTEXITCODE -gt 1) {
    throw "UserDefaults scan failed."
} else {
    Write-Host "no UserDefaults usage found"
}

Write-Section "Static site links"
$htmlFiles = Get-ChildItem site -Filter *.html
foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    $parts = $content -split "href="
    foreach ($part in $parts | Select-Object -Skip 1) {
        $quoteCode = [int][char]$part.Substring(0, 1)
        if ($quoteCode -ne 34 -and $quoteCode -ne 39) {
            continue
        }
        $quote = [char]$quoteCode
        $end = $part.IndexOf($quote, 1)
        if ($end -lt 1) {
            throw "Malformed href in $($file.Name)"
        }
        $href = $part.Substring(1, $end - 1)
        if ($href -notmatch '^https?:|^mailto:|^#') {
            $target = Join-Path $file.DirectoryName $href
            if (-not (Test-Path $target)) {
                throw "Missing link target $href in $($file.Name)"
            }
        }
    }
}
Write-Host "site links valid"

Write-Section "Toolchain report"
$tools = "swift", "xcodebuild", "xcodegen", "bash"
foreach ($tool in $tools) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    if ($command) {
        Write-Host "$tool=$($command.Source)"
    } else {
        Write-Host "$tool=missing"
    }
}

Write-Host ""
Write-Host "Windows preflight completed."
