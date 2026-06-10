$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stageMaterialsPath = Join-Path $repoRoot "scripts\stage-apple-release-materials.ps1"
$prepareMaterialsPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
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

function Assert-NotContains($text, $unexpected, $message) {
    if ($text.IndexOf($unexpected, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw $message
    }
}

function Invoke-StageMaterials($arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $stageMaterialsPath @arguments 2>&1 | Out-String
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

function New-SourceMaterials($directory) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $apiKeyPath = Join-Path $directory "AuthKey_TESTKEY123.p8"
    $certificatePath = Join-Path $directory "distribution-export.p12"
    $profilePath = Join-Path $directory "SnapTableReminder_AppStore.mobileprovision"
    $dsaPath = Join-Path $directory "dsa-note.md"

    Set-Content -Path $apiKeyPath -Encoding UTF8 -Value @"
-----BEGIN PRIVATE KEY-----
test-private-key
-----END PRIVATE KEY-----
"@
    [System.IO.File]::WriteAllBytes($certificatePath, [byte[]](1, 2, 3, 4, 5))
    Set-Content -Path $profilePath -Encoding UTF8 -Value "com.snaptable.reminder"
    Set-Content -Path $dsaPath -Encoding UTF8 -Value @"
# DSA note

- EU storefronts: included
- Trader status decision: completed in App Store Connect
"@

    [pscustomobject]@{
        ApiKey = $apiKeyPath
        Certificate = $certificatePath
        Profile = $profilePath
        Dsa = $dsaPath
    }
}

function New-CompleteStageArguments($target, $source) {
    @(
        "-OutputDirectory", $target,
        "-AppStoreConnectApiKeyPath", $source.ApiKey,
        "-AppleDistributionCertificatePath", $source.Certificate,
        "-AppleAppStoreProfilePath", $source.Profile,
        "-DsaEvidencePath", $source.Dsa,
        "-AppStoreConnectUsername", "account@example.invalid",
        "-AppleDeveloperTeamId", "TEAM123456",
        "-AppStoreConnectApiKeyId", "TESTKEY123",
        "-AppStoreConnectApiIssuerId", "00000000-0000-0000-0000-000000000000",
        "-AppleDistributionCertificatePassword", "p12-password",
        "-AppleCodesignKeychainPassword", "temporary-keychain-password",
        "-ReviewFirstName", "App",
        "-ReviewLastName", "Reviewer",
        "-ReviewEmail", "reviewer@example.invalid",
        "-ReviewPhone", "+1 555 010 1000",
        "-AppleDeveloperProgramActive",
        "-PaidAppsAgreementActive",
        "-TaxComplete",
        "-BankingComplete",
        "-AppStoreConnectAppCreated"
    )
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-stage-materials-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "stages complete Apple materials into canonical private folder" {
        $source = New-SourceMaterials (Join-Path $tempRoot "source")
        $target = Join-Path $tempRoot "materials"

        $result = Invoke-StageMaterials (New-CompleteStageArguments $target $source)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "Apple material folder is ready" "stage script should validate the completed folder"
        Assert-NotContains $result.Output "p12-password" "stage script should not print certificate passwords"
        Assert-NotContains $result.Output "+1 555" "stage script should not print review phone numbers"

        Assert-True (Test-Path (Join-Path $target "01-app-store-connect-api-key\AuthKey_TESTKEY123.p8")) "API key should be copied to canonical path"
        Assert-True (Test-Path (Join-Path $target "02-signing\apple-distribution.p12")) "certificate should be copied to canonical path"
        Assert-True (Test-Path (Join-Path $target "02-signing\app-store.mobileprovision")) "profile should be copied to canonical path"
        Assert-True (Test-Path (Join-Path $target "release-secrets.private.json")) "release secrets JSON should be written"
        Assert-True (Test-Path (Join-Path $target "03-review-contact\review-contact.private.json")) "review contact JSON should be written"

        $validation = & powershell -NoProfile -ExecutionPolicy Bypass -File $prepareMaterialsPath -OutputDirectory $target -ValidateOnly 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0) "prepared folder should validate: $validation"
    }

    Run-Test "dry-run reports staging plan without writing private files" {
        $source = New-SourceMaterials (Join-Path $tempRoot "dry-source")
        $target = Join-Path $tempRoot "dry-materials"

        $result = Invoke-StageMaterials ((New-CompleteStageArguments $target $source) + @("-DryRun"))

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "dry-run: would copy App Store Connect API key" "dry run should show API key copy plan"
        Assert-Contains $result.Output "dry-run: would write release-secrets.private.json" "dry run should show release secret plan"
        Assert-NotContains $result.Output "temporary-keychain-password" "dry run should not print keychain passwords"
        Assert-True (-not (Test-Path (Join-Path $target "release-secrets.private.json"))) "dry run should not write release secrets"
        Assert-True (-not (Test-Path (Join-Path $target "01-app-store-connect-api-key\AuthKey_TESTKEY123.p8"))) "dry run should not copy API key"
    }

    Run-Test "rejects Apple credential inputs from the repository" {
        $insideRepo = Join-Path $repoRoot ".tmp-stage-materials-inside-test"
        if (Test-Path $insideRepo) {
            Remove-Item -LiteralPath $insideRepo -Recurse -Force
        }
        try {
            $source = New-SourceMaterials $insideRepo
            $target = Join-Path $tempRoot "reject-materials"

            $result = Invoke-StageMaterials (New-CompleteStageArguments $target $source)

            Assert-True ($result.ExitCode -ne 0) "expected non-zero exit for repository credential inputs"
            Assert-Contains $result.Output "outside this repository" "credential inputs inside the repo should be rejected"
        } finally {
            $resolvedInsideRepo = [System.IO.Path]::GetFullPath($insideRepo)
            $resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)
            if ($resolvedInsideRepo.StartsWith($resolvedRepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $resolvedInsideRepo)) {
                Remove-Item -LiteralPath $resolvedInsideRepo -Recurse -Force
            }
        }
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
    Write-Host "stage-apple-release-materials tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "stage-apple-release-materials tests passed."
