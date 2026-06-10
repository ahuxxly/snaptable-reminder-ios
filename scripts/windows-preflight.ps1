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
$markerOutput = rg "TODO|TBD|PLACEHOLDER|example\.com|YOUR_|your-domain" . 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host $markerOutput
    throw "Unfinished marker text found."
}
if ($LASTEXITCODE -gt 1) {
    throw "Marker scan failed."
}
Write-Host "no unfinished markers"

Write-Section "Encoding damage scan"
$encodingOutput = rg "鈧|楼|骞|鏈|鎴|瀛|鍖|棰|鑸|璐|搴|�" SnapTableReminder docs site README.md project.yml scripts .github 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host $encodingOutput
    throw "Potential mojibake text found."
}
if ($LASTEXITCODE -gt 1) {
    throw "Encoding scan failed."
}
Write-Host "no common mojibake markers"

Write-Section "Resource parsing"
Get-Content "SnapTableReminder\Resources\Assets.xcassets\Contents.json" | ConvertFrom-Json | Out-Null
Get-Content "SnapTableReminder\Resources\Assets.xcassets\AppIcon.appiconset\Contents.json" | ConvertFrom-Json | Out-Null
Get-Content "SnapTableReminder\Resources\Localizable.xcstrings" | ConvertFrom-Json | Out-Null
[xml](Get-Content "SnapTableReminder\Resources\Info.plist" -Raw) | Out-Null
[xml](Get-Content "SnapTableReminder\Resources\PrivacyInfo.xcprivacy" -Raw) | Out-Null
Write-Host "resources parse"

Write-Section "Static site links"
$htmlFiles = Get-ChildItem site -Filter *.html
foreach ($file in $htmlFiles) {
    $content = Get-Content $file.FullName -Raw
    [regex]::Matches($content, 'href="([^"]+)"') | ForEach-Object {
        $href = $_.Groups[1].Value
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
