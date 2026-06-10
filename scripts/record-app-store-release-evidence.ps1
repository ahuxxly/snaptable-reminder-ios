param(
    [string]$MaterialsDirectory = "",
    [string]$AppStoreConnectAppId,
    [string]$AppVersion = "1.0",
    [string]$BuildNumber = "1",
    [string]$AppStatus,

    [string]$MetadataWorkflowRunUrl = "",
    [string]$TestFlightWorkflowRunUrl = "",
    [string]$AppReviewWorkflowRunUrl = "",

    [switch]$MetadataUploaded,
    [switch]$ScreenshotsUploaded,
    [switch]$ReviewCheckPassed,
    [switch]$TestFlightUploaded,
    [switch]$BuildProcessed,
    [switch]$AppReviewSubmitted,

    [switch]$DryRun,
    [switch]$AllowWorkspacePath
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

function Get-DefaultMaterialsDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [Environment]::GetFolderPath("UserProfile")
    }
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = [System.IO.Path]::GetTempPath()
    }

    return (Join-Path $documents "SnapTableReminder-Apple-Materials")
}

function Resolve-FullPath($path, $fieldName) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "$fieldName cannot be empty."
    }

    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Assert-OutsideRepository($path, $repoRoot, $allowWorkspacePath, $label) {
    if ($allowWorkspacePath) {
        return
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($path)
    $resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    $repoPrefix = $resolvedRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if ($resolvedPath.Equals($resolvedRepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$label must be stored outside this repository: $resolvedPath"
    }
}

function Assert-RequiredText($value, $fieldName) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$fieldName cannot be empty."
    }
}

function Assert-OptionalUrl($value, $fieldName) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        return
    }
    if ($value -notmatch "^https://github\.com/[^/]+/[^/]+/actions/runs/[0-9]+") {
        throw "$fieldName should look like a GitHub Actions run URL."
    }
}

function Write-JsonFile($path, $value) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $value | ConvertTo-Json -Depth 6
    Set-Content -Path $path -Encoding UTF8 -Value $json
}

function Write-SummaryFile($path, $evidence) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $lines = @(
        "# SnapTable Reminder Release Evidence",
        "",
        "Recorded at: $($evidence.recordedAt)",
        "App Store Connect app id: $($evidence.appStoreConnectAppId)",
        "Version: $($evidence.appVersion)",
        "Build: $($evidence.buildNumber)",
        "App status: $($evidence.appStatus)",
        "",
        "## Status",
        "",
        "- Metadata uploaded: $($evidence.status.metadataUploaded)",
        "- Screenshots uploaded: $($evidence.status.screenshotsUploaded)",
        "- Review check passed: $($evidence.status.reviewCheckPassed)",
        "- TestFlight uploaded: $($evidence.status.testFlightUploaded)",
        "- Build processed: $($evidence.status.buildProcessed)",
        "- App Review submitted: $($evidence.status.appReviewSubmitted)",
        "",
        "## Workflow Runs",
        "",
        "- Metadata: $($evidence.workflowRuns.metadata)",
        "- TestFlight: $($evidence.workflowRuns.testFlight)",
        "- App Review: $($evidence.workflowRuns.appReview)"
    )
    Set-Content -Path $path -Encoding UTF8 -Value ($lines -join [Environment]::NewLine)
}

if ([string]::IsNullOrWhiteSpace($MaterialsDirectory)) {
    $MaterialsDirectory = Get-DefaultMaterialsDirectory
}

$allowedStatuses = @(
    "Prepare for Submission",
    "Ready for Review",
    "Waiting for Review",
    "In Review",
    "Pending Developer Release",
    "Ready for Distribution",
    "Rejected",
    "Developer Rejected"
)

Assert-RequiredText $AppStoreConnectAppId "AppStoreConnectAppId"
Assert-RequiredText $AppVersion "AppVersion"
Assert-RequiredText $BuildNumber "BuildNumber"
Assert-RequiredText $AppStatus "AppStatus"
if ($allowedStatuses -notcontains $AppStatus) {
    throw "AppStatus must be one of: $($allowedStatuses -join ', ')."
}
Assert-OptionalUrl $MetadataWorkflowRunUrl "MetadataWorkflowRunUrl"
Assert-OptionalUrl $TestFlightWorkflowRunUrl "TestFlightWorkflowRunUrl"
Assert-OptionalUrl $AppReviewWorkflowRunUrl "AppReviewWorkflowRunUrl"

$repoRoot = Resolve-RepositoryRoot
$materialsRoot = Resolve-FullPath $MaterialsDirectory "MaterialsDirectory"
Assert-OutsideRepository $materialsRoot $repoRoot $AllowWorkspacePath "App Store release evidence folder"

if (-not (Test-Path $materialsRoot)) {
    throw "MaterialsDirectory does not exist: $materialsRoot"
}

$evidenceDirectory = Join-Path $materialsRoot "05-release-evidence"
$evidenceJsonPath = Join-Path $evidenceDirectory "release-evidence.private.json"
$summaryPath = Join-Path $evidenceDirectory "release-evidence-summary.md"

$evidence = [ordered]@{
    schemaVersion = 1
    recordedAt = [DateTimeOffset]::UtcNow.ToString("o")
    appStoreConnectAppId = $AppStoreConnectAppId
    appVersion = $AppVersion
    buildNumber = $BuildNumber
    appStatus = $AppStatus
    status = [ordered]@{
        metadataUploaded = [bool]$MetadataUploaded
        screenshotsUploaded = [bool]$ScreenshotsUploaded
        reviewCheckPassed = [bool]$ReviewCheckPassed
        testFlightUploaded = [bool]$TestFlightUploaded
        buildProcessed = [bool]$BuildProcessed
        appReviewSubmitted = [bool]$AppReviewSubmitted
    }
    workflowRuns = [ordered]@{
        metadata = $MetadataWorkflowRunUrl
        testFlight = $TestFlightWorkflowRunUrl
        appReview = $AppReviewWorkflowRunUrl
    }
}

Write-Section "Record App Store release evidence"
Write-Host "materials=$materialsRoot"
Write-Host "appStoreConnectAppId=$AppStoreConnectAppId"
Write-Host "version=$AppVersion"
Write-Host "build=$BuildNumber"
Write-Host "appStatus=$AppStatus"

if ($DryRun) {
    Write-Host "dry-run: would write release evidence JSON to $evidenceJsonPath"
    Write-Host "dry-run: would write release evidence summary to $summaryPath"
    Write-Host ""
    Write-Host "Dry run complete; no files were written."
    exit 0
}

Write-JsonFile $evidenceJsonPath $evidence
Write-SummaryFile $summaryPath ([pscustomobject]$evidence)

Write-Host ""
Write-Host "Wrote release evidence JSON: $evidenceJsonPath"
Write-Host "Wrote release evidence summary: $summaryPath"
