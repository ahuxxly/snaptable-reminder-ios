$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$setSecretsScriptPath = Join-Path $repoRoot "scripts\github-set-apple-secrets.ps1"
$prepareMaterialsScriptPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
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

function Invoke-SetSecretsScript($arguments, $fakeGhDirectory) {
    $previousPath = $env:PATH
    $previousErrorActionPreference = $ErrorActionPreference
    $env:PATH = "$fakeGhDirectory;$previousPath"
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $setSecretsScriptPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        $env:PATH = $previousPath
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

function New-FakeGh($directory) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Set-Content -Path (Join-Path $directory "gh.cmd") -Encoding ASCII -Value @"
@echo off
if "%1"=="auth" (
  if "%2"=="status" (
    echo Logged in to github.com as test-user
    exit /b 0
  )
)
echo unexpected gh arguments: %*
exit /b 1
"@
}

function New-CompleteMaterialsFolder($target) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $prepareMaterialsScriptPath -OutputDirectory $target | Out-Null
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-github-secrets-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $fakeGhDirectory = Join-Path $tempRoot "fake-gh"
    New-FakeGh $fakeGhDirectory

    Run-Test "dry-run reads complete Apple materials folder and plans all GitHub secrets" {
        $materials = Join-Path $tempRoot "complete-materials"
        New-CompleteMaterialsFolder $materials

        $result = Invoke-SetSecretsScript @(
            "-RepoFullName", "owner/repo",
            "-DryRun",
            "-MaterialsDirectory", $materials
        ) $fakeGhDirectory

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        foreach ($secretName in @(
            "APP_STORE_CONNECT_USERNAME",
            "APPLE_DEVELOPER_TEAM_ID",
            "APP_STORE_CONNECT_API_KEY_ID",
            "APP_STORE_CONNECT_API_ISSUER_ID",
            "APP_STORE_CONNECT_API_PRIVATE_KEY",
            "APPLE_DISTRIBUTION_CERTIFICATE_BASE64",
            "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD",
            "APPLE_APP_STORE_PROFILE_BASE64",
            "APPLE_CODESIGN_KEYCHAIN_PASSWORD",
            "APP_REVIEW_FIRST_NAME",
            "APP_REVIEW_LAST_NAME",
            "APP_REVIEW_EMAIL",
            "APP_REVIEW_PHONE"
        )) {
            Assert-Contains $result.Output "dry-run: would set $secretName" "dry run should plan $secretName"
        }
        Assert-Contains $result.Output "materials=$materials" "output should show the material folder used"
        Assert-NotContains $result.Output "p12-password" "dry run should not print certificate passwords"
        Assert-NotContains $result.Output "+1 555" "dry run should not print review phone numbers"
    }

    Run-Test "upload-only materials dry-run does not plan signing or review secrets" {
        $materials = Join-Path $tempRoot "upload-only-materials"
        New-CompleteMaterialsFolder $materials

        $result = Invoke-SetSecretsScript @(
            "-RepoFullName", "owner/repo",
            "-DryRun",
            "-UploadOnly",
            "-MaterialsDirectory", $materials
        ) $fakeGhDirectory

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "dry-run: would set APP_STORE_CONNECT_USERNAME" "upload dry run should set upload secret"
        Assert-Contains $result.Output "dry-run: would set APP_STORE_CONNECT_API_PRIVATE_KEY" "upload dry run should set private key secret"
        Assert-NotContains $result.Output "APPLE_DISTRIBUTION_CERTIFICATE_BASE64" "upload-only should not set signing secrets"
        Assert-NotContains $result.Output "APP_REVIEW_FIRST_NAME" "upload-only should not set review secrets"
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
    Write-Host "github-set-apple-secrets tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "github-set-apple-secrets tests passed."
