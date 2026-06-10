param(
    [string]$OutputDirectory = "",

    [string]$AppStoreConnectApiKeyPath,
    [string]$AppleDistributionCertificatePath,
    [string]$AppleAppStoreProfilePath,
    [string]$DsaEvidencePath,

    [string]$AppStoreConnectUsername,
    [string]$AppleDeveloperTeamId,
    [string]$AppStoreConnectApiKeyId,
    [string]$AppStoreConnectApiIssuerId,
    [string]$AppleDistributionCertificatePassword,
    [string]$AppleCodesignKeychainPassword,

    [string]$ReviewFirstName,
    [string]$ReviewLastName,
    [string]$ReviewEmail,
    [string]$ReviewPhone,

    [switch]$AppleDeveloperProgramActive,
    [switch]$PaidAppsAgreementActive,
    [switch]$TaxComplete,
    [switch]$BankingComplete,
    [switch]$AppStoreConnectAppCreated,

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

function Test-IsInsideRepository($path, $repoRoot) {
    $resolvedPath = [System.IO.Path]::GetFullPath($path)
    $resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    $repoPrefix = $resolvedRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    return $resolvedPath.Equals($resolvedRepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-OutsideRepository($path, $repoRoot, $allowWorkspacePath, $label) {
    if ($allowWorkspacePath) {
        return
    }

    if (Test-IsInsideRepository $path $repoRoot) {
        throw "$label must be stored outside this repository: $path"
    }
}

function Assert-ExistingFile($path, $label) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$label does not exist: $path"
    }
}

function Assert-RequiredText($value, $fieldName) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$fieldName cannot be empty."
    }
}

function Write-JsonFile($path, $value) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $value | ConvertTo-Json -Depth 4
    Set-Content -Path $path -Encoding UTF8 -Value $json
}

function Copy-PrivateFile($source, $destination) {
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Invoke-PrepareMaterialsFolder($repoRoot, $materialsRoot, $validateOnly, $allowWorkspacePath) {
    $prepareScript = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $prepareScript, "-OutputDirectory", $materialsRoot)
    if ($validateOnly) {
        $arguments += "-ValidateOnly"
    }
    if ($allowWorkspacePath) {
        $arguments += "-AllowWorkspacePath"
    }

    & powershell @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Apple materials folder preparation failed."
    }
}

function Assert-AccountConfirmations {
    $missing = @()
    if (-not $AppleDeveloperProgramActive) { $missing += "AppleDeveloperProgramActive" }
    if (-not $PaidAppsAgreementActive) { $missing += "PaidAppsAgreementActive" }
    if (-not $TaxComplete) { $missing += "TaxComplete" }
    if (-not $BankingComplete) { $missing += "BankingComplete" }
    if (-not $AppStoreConnectAppCreated) { $missing += "AppStoreConnectAppCreated" }

    if ($missing.Count -gt 0) {
        throw "Missing account confirmation flags: $($missing -join ', '). Confirm these in App Store Connect before staging release materials."
    }
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Get-DefaultMaterialsDirectory
}

$repoRoot = Resolve-RepositoryRoot
$materialsRoot = Resolve-FullPath $OutputDirectory "OutputDirectory"

$apiKeyPath = Resolve-FullPath $AppStoreConnectApiKeyPath "AppStoreConnectApiKeyPath"
$certificatePath = Resolve-FullPath $AppleDistributionCertificatePath "AppleDistributionCertificatePath"
$profilePath = Resolve-FullPath $AppleAppStoreProfilePath "AppleAppStoreProfilePath"
$dsaPath = Resolve-FullPath $DsaEvidencePath "DsaEvidencePath"

Assert-OutsideRepository $materialsRoot $repoRoot $AllowWorkspacePath "Apple private material output folder"
Assert-OutsideRepository $apiKeyPath $repoRoot $AllowWorkspacePath "App Store Connect API key"
Assert-OutsideRepository $certificatePath $repoRoot $AllowWorkspacePath "Apple Distribution certificate"
Assert-OutsideRepository $profilePath $repoRoot $AllowWorkspacePath "App Store provisioning profile"
Assert-OutsideRepository $dsaPath $repoRoot $AllowWorkspacePath "EU DSA evidence file"

Assert-ExistingFile $apiKeyPath "App Store Connect API key"
Assert-ExistingFile $certificatePath "Apple Distribution certificate"
Assert-ExistingFile $profilePath "App Store provisioning profile"
Assert-ExistingFile $dsaPath "EU DSA evidence file"

foreach ($requiredTextField in @(
    @($AppStoreConnectUsername, "AppStoreConnectUsername"),
    @($AppleDeveloperTeamId, "AppleDeveloperTeamId"),
    @($AppStoreConnectApiKeyId, "AppStoreConnectApiKeyId"),
    @($AppStoreConnectApiIssuerId, "AppStoreConnectApiIssuerId"),
    @($AppleDistributionCertificatePassword, "AppleDistributionCertificatePassword"),
    @($AppleCodesignKeychainPassword, "AppleCodesignKeychainPassword"),
    @($ReviewFirstName, "ReviewFirstName"),
    @($ReviewLastName, "ReviewLastName"),
    @($ReviewEmail, "ReviewEmail"),
    @($ReviewPhone, "ReviewPhone")
)) {
    Assert-RequiredText $requiredTextField[0] $requiredTextField[1]
}

if ($AppStoreConnectUsername -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
    throw "AppStoreConnectUsername should look like an email address."
}
if ($ReviewEmail -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
    throw "ReviewEmail should look like an email address."
}
if ($ReviewPhone -notmatch "^\+?[0-9][0-9\s().-]{6,}$") {
    throw "ReviewPhone should include a reachable country code phone number."
}

Assert-AccountConfirmations

$apiKeyText = Get-Content -LiteralPath $apiKeyPath -Raw
if (-not $apiKeyText.Contains("BEGIN PRIVATE KEY")) {
    throw "App Store Connect API key file does not look like a private key."
}
if ((Get-Item -LiteralPath $certificatePath).Length -le 0) {
    throw "Apple Distribution certificate file is empty."
}
if ((Get-Item -LiteralPath $profilePath).Length -le 0) {
    throw "App Store provisioning profile file is empty."
}

$apiKeyDestination = Join-Path $materialsRoot "01-app-store-connect-api-key\AuthKey_$AppStoreConnectApiKeyId.p8"
$certificateDestination = Join-Path $materialsRoot "02-signing\apple-distribution.p12"
$profileDestination = Join-Path $materialsRoot "02-signing\app-store.mobileprovision"
$accountDestination = Join-Path $materialsRoot "00-account\account-private-status.md"
$releaseSecretsDestination = Join-Path $materialsRoot "release-secrets.private.json"
$reviewContactDestination = Join-Path $materialsRoot "03-review-contact\review-contact.private.json"
$dsaDestination = Join-Path $materialsRoot "04-eu-dsa\dsa-private-evidence.md"

Write-Section "Stage Apple release materials"
Write-Host "materials=$materialsRoot"

if ($DryRun) {
    Write-Host "dry-run: would initialize Apple materials folder"
    Write-Host "dry-run: would copy App Store Connect API key to $apiKeyDestination"
    Write-Host "dry-run: would copy Apple Distribution certificate to $certificateDestination"
    Write-Host "dry-run: would copy App Store provisioning profile to $profileDestination"
    Write-Host "dry-run: would write 00-account/account-private-status.md"
    Write-Host "dry-run: would write release-secrets.private.json"
    Write-Host "dry-run: would write 03-review-contact/review-contact.private.json"
    Write-Host "dry-run: would copy EU DSA evidence to $dsaDestination"
    Write-Host ""
    Write-Host "Dry run complete; no files were written."
    exit 0
}

Invoke-PrepareMaterialsFolder $repoRoot $materialsRoot $false $AllowWorkspacePath

Copy-PrivateFile $apiKeyPath $apiKeyDestination
Copy-PrivateFile $certificatePath $certificateDestination
Copy-PrivateFile $profilePath $profileDestination
Copy-PrivateFile $dsaPath $dsaDestination

Set-Content -Path $accountDestination -Encoding UTF8 -Value @"
# Private Account Status

- Apple Developer Program: active
- Paid Apps Agreement: accepted
- Tax: complete
- Banking: complete
- App Store Connect app: com.snaptable.reminder created
"@

Write-JsonFile $releaseSecretsDestination ([ordered]@{
    appStoreConnectUsername = $AppStoreConnectUsername
    appleDeveloperTeamId = $AppleDeveloperTeamId
    appStoreConnectApiKeyId = $AppStoreConnectApiKeyId
    appStoreConnectApiIssuerId = $AppStoreConnectApiIssuerId
    appleDistributionCertificatePassword = $AppleDistributionCertificatePassword
    appleCodesignKeychainPassword = $AppleCodesignKeychainPassword
})

Write-JsonFile $reviewContactDestination ([ordered]@{
    firstName = $ReviewFirstName
    lastName = $ReviewLastName
    email = $ReviewEmail
    phone = $ReviewPhone
})

Invoke-PrepareMaterialsFolder $repoRoot $materialsRoot $true $AllowWorkspacePath

Write-Host ""
Write-Host "Staged Apple release materials in: $materialsRoot"
Write-Host "Next: run scripts/github-set-apple-secrets.ps1 -MaterialsDirectory `"$materialsRoot`" -DryRun"
