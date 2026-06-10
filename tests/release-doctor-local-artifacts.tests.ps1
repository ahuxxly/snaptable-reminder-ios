$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$releaseDoctorPath = Join-Path $repoRoot "scripts\release-doctor.ps1"
$entryPackExporterPath = Join-Path $repoRoot "scripts\export-app-store-connect-entry-pack.ps1"
$materialsPrepPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
$failures = New-Object "System.Collections.Generic.List[string]"

function Assert-True($condition, $message) {
    if (-not $condition) {
        throw $message
    }
}

function Assert-Contains($text, $expected, $message) {
    if ($text.IndexOf($expected, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw $message
    }
}

function Invoke-ReleaseDoctor($arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $releaseDoctorPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Run-Test($name, [scriptblock]$body) {
    try {
        & $body
        Write-Host "[PASS] $name"
    } catch {
        $failures.Add("$name`: $($_.Exception.Message)") | Out-Null
        Write-Host "[FAIL] $name"
        Write-Host $_.Exception.Message
    }
}

function New-CompleteMaterialsFolder($target) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $materialsPrepPath -OutputDirectory $target | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not prepare test materials folder."
    }

    Set-Content -Path (Join-Path $target "00-account\account-private-status.md") -Encoding UTF8 -Value @"
# Private Account Status

- Apple Developer Program: active
- Paid Apps Agreement: accepted
- Tax: complete
- Banking: complete
- App Store Connect app: com.snaptable.reminder created
"@
    Set-Content -Path (Join-Path $target "release-secrets.private.json") -Encoding UTF8 -Value @"
{
  "appStoreConnectUsername": "account@example.invalid",
  "appleDeveloperTeamId": "TEAM123456",
  "appStoreConnectApiKeyId": "TESTKEY123",
  "appStoreConnectApiIssuerId": "00000000-0000-0000-0000-000000000000",
  "appleDistributionCertificatePassword": "p12-password",
  "appleCodesignKeychainPassword": "temporary-keychain-password"
}
"@
    Set-Content -Path (Join-Path $target "01-app-store-connect-api-key\AuthKey_TESTKEY123.p8") -Encoding UTF8 -Value @"
-----BEGIN PRIVATE KEY-----
test-private-key
-----END PRIVATE KEY-----
"@
    [System.IO.File]::WriteAllBytes((Join-Path $target "02-signing\apple-distribution.p12"), [byte[]](1, 2, 3, 4))
    [System.IO.File]::WriteAllText((Join-Path $target "02-signing\app-store.mobileprovision"), "com.snaptable.reminder")
    Set-Content -Path (Join-Path $target "03-review-contact\review-contact.private.json") -Encoding UTF8 -Value @"
{
  "firstName": "App",
  "lastName": "Reviewer",
  "email": "reviewer@example.invalid",
  "phone": "+1 555 010 1000"
}
"@
    Set-Content -Path (Join-Path $target "04-eu-dsa\dsa-private-evidence.md") -Encoding UTF8 -Value @"
# Private EU DSA Evidence

- EU storefronts: included
- Trader status decision: completed
"@
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-release-doctor-local-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "local-only doctor accepts complete entry packet and materials folder" {
        $entryPack = Join-Path $tempRoot "entry-pack"
        $materials = Join-Path $tempRoot "materials"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $entryPackExporterPath -OutputDirectory $entryPack | Out-Null
        Assert-True ($LASTEXITCODE -eq 0) "entry pack setup failed"
        New-CompleteMaterialsFolder $materials

        $result = Invoke-ReleaseDoctor @(
            "-LocalOnly",
            "-EntryPackDirectory", $entryPack,
            "-MaterialsDirectory", $materials
        )

        Assert-True ($result.ExitCode -ne 2) "complete local artifacts should not create blocked gates: $($result.Output)"
        Assert-Contains $result.Output "[OK] App Store Connect entry packet" "entry pack gate should be OK"
        Assert-Contains $result.Output "[OK] Apple private material folder" "materials gate should be OK"
        Assert-Contains $result.Output "blocked=0" "local-only doctor should report zero blocked gates for complete local artifacts"
    }

    Run-Test "local-only doctor blocks missing explicit artifact folders" {
        $missingEntryPack = Join-Path $tempRoot "missing-entry-pack"
        $missingMaterials = Join-Path $tempRoot "missing-materials"

        $result = Invoke-ReleaseDoctor @(
            "-LocalOnly",
            "-EntryPackDirectory", $missingEntryPack,
            "-MaterialsDirectory", $missingMaterials
        )

        Assert-True ($result.ExitCode -eq 2) "missing explicit artifact folders should exit 2: $($result.Output)"
        Assert-Contains $result.Output "[BLOCKED] App Store Connect entry packet" "missing entry pack should be blocked"
        Assert-Contains $result.Output "[BLOCKED] Apple private material folder" "missing materials should be blocked"
    }
} finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    $resolvedTempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTempRoot.StartsWith($resolvedTempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
    }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "release-doctor local artifact tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "release-doctor local artifact tests passed."
