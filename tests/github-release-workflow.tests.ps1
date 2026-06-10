$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$releaseRunnerPath = Join-Path $repoRoot "scripts\github-run-app-store-release.ps1"
$reviewSubmitPath = Join-Path $repoRoot "scripts\github-submit-app-review.ps1"
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

function Invoke-ReleaseScript($scriptPath, $arguments, $fakeGhDirectory) {
    $previousPath = $env:PATH
    $previousErrorActionPreference = $ErrorActionPreference
    $env:PATH = "$fakeGhDirectory;$previousPath"
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments 2>&1 | Out-String
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

function New-FakeGhWithoutSecrets($directory) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Set-Content -Path (Join-Path $directory "gh.cmd") -Encoding ASCII -Value @"
@echo off
if "%1"=="auth" (
  if "%2"=="status" (
    echo Logged in to github.com as test-user
    exit /b 0
  )
)
if "%1"=="secret" (
  if "%2"=="list" (
    echo []
    exit /b 0
  )
)
if "%1"=="run" (
  if "%2"=="list" (
    echo completed success iOS CI master
    exit /b 0
  )
)
if "%1"=="repo" (
  if "%2"=="view" (
    echo owner/repo
    exit /b 0
  )
)
if "%1"=="workflow" (
  if "%2"=="run" (
    echo workflow should not be invoked by dry-run tests
    exit /b 9
  )
)
echo unexpected gh arguments: %*
exit /b 1
"@
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-release-workflow-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $fakeGhDirectory = Join-Path $tempRoot "fake-gh"
    New-FakeGhWithoutSecrets $fakeGhDirectory

    Run-Test "App Store release dry-run prints workflow command even before Apple secrets exist" {
        $result = Invoke-ReleaseScript $releaseRunnerPath @(
            "-RepoFullName", "owner/repo",
            "-Ref", "master",
            "-DryRun",
            "-SkipTestFlight"
        ) $fakeGhDirectory

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "Missing App Store Connect upload secrets" "dry-run should still report missing upload secrets"
        Assert-Contains $result.Output "dry-run: gh workflow run app-store-connect-upload.yml --repo owner/repo --ref master" "dry-run should print the App Store Connect workflow command"
        Assert-Contains $result.Output "upload_metadata=true" "dry-run should show metadata upload input"
        Assert-Contains $result.Output "Dry run complete; no workflows were triggered." "dry-run should confirm no workflow dispatch happened"
        Assert-NotContains $result.Output "testflight-upload.yml" "SkipTestFlight should avoid the TestFlight workflow command"
    }

    Run-Test "App Store release non-dry-run blocks missing upload secrets" {
        $result = Invoke-ReleaseScript $releaseRunnerPath @(
            "-RepoFullName", "owner/repo",
            "-Ref", "master",
            "-SkipTestFlight"
        ) $fakeGhDirectory

        Assert-True ($result.ExitCode -ne 0) "expected non-zero exit when upload secrets are missing"
        Assert-Contains $result.Output "Missing App Store Connect upload secrets" "non-dry-run should block missing upload secrets"
        Assert-NotContains $result.Output "dry-run: gh workflow run" "non-dry-run missing-secret path should not print a dry-run command"
    }

    Run-Test "App Review dry-run keeps the explicit review confirmation gate" {
        $result = Invoke-ReleaseScript $reviewSubmitPath @(
            "-RepoFullName", "owner/repo",
            "-Ref", "master",
            "-DryRun"
        ) $fakeGhDirectory

        Assert-True ($result.ExitCode -ne 0) "expected non-zero exit without explicit review confirmation"
        Assert-Contains $result.Output "Pass -ConfirmSubmitForReview YES" "dry-run should still require explicit review confirmation"
    }

    Run-Test "App Review dry-run prints submit workflow command even before review secrets exist" {
        $result = Invoke-ReleaseScript $reviewSubmitPath @(
            "-RepoFullName", "owner/repo",
            "-Ref", "master",
            "-DryRun",
            "-ConfirmSubmitForReview", "YES"
        ) $fakeGhDirectory

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "Missing App Review submission secrets" "dry-run should still report missing review secrets"
        Assert-Contains $result.Output "dry-run: gh workflow run app-review-submit.yml --repo owner/repo --ref master -f confirm_submit_for_review=YES" "dry-run should print the App Review workflow command"
        Assert-Contains $result.Output "Dry run complete; no workflows were triggered." "dry-run should confirm no workflow dispatch happened"
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
    Write-Host "github-release-workflow tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "github-release-workflow tests passed."
