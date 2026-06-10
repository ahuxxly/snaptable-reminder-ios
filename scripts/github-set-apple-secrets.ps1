param(
    [string]$RepoFullName = "",

    [switch]$UploadOnly,
    [switch]$SigningOnly,
    [switch]$ReviewOnly,
    [switch]$DryRun,
    [string]$MaterialsDirectory = "",

    [string]$AppStoreConnectUsername = "",
    [string]$AppleDeveloperTeamId = "",
    [string]$AppStoreConnectApiKeyId = "",
    [string]$AppStoreConnectApiIssuerId = "",
    [string]$AppStoreConnectApiKeyPath = "",

    [string]$AppleDistributionCertificatePath = "",
    [string]$AppleDistributionCertificatePassword = "",
    [string]$AppleAppStoreProfilePath = "",
    [string]$AppleCodesignKeychainPassword = "",

    [string]$AppReviewFirstName = "",
    [string]$AppReviewLastName = "",
    [string]$AppReviewEmail = "",
    [string]$AppReviewPhone = ""
)

$ErrorActionPreference = "Stop"

function Write-Section($title) {
    Write-Host ""
    Write-Host "== $title =="
}

function Resolve-GitHubCli {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        return $gh.Source
    }

    $fallbackGhPath = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $fallbackGhPath) {
        return $fallbackGhPath
    }

    throw "GitHub CLI is missing. Install it with: winget install --id GitHub.cli -e --source winget"
}

function Read-RequiredText($prompt, $currentValue) {
    if (-not [string]::IsNullOrWhiteSpace($currentValue)) {
        return $currentValue.Trim()
    }

    $value = Read-Host $prompt
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$prompt is required."
    }
    return $value.Trim()
}

function Convert-SecureStringToPlainText($secureString) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-RequiredSecretText($prompt, $currentValue) {
    if (-not [string]::IsNullOrEmpty($currentValue)) {
        return $currentValue
    }

    $secureValue = Read-Host $prompt -AsSecureString
    $plainValue = Convert-SecureStringToPlainText $secureValue
    if ([string]::IsNullOrEmpty($plainValue)) {
        throw "$prompt is required."
    }
    return $plainValue
}

function Resolve-RequiredPath($prompt, $currentValue) {
    $pathText = Read-RequiredText $prompt $currentValue
    $resolvedPath = Resolve-Path -LiteralPath $pathText -ErrorAction Stop
    return $resolvedPath.Path
}

function Assert-FileOutsideRepository($path, $repoRoot, $label) {
    $fullPath = [System.IO.Path]::GetFullPath($path)
    $fullRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)

    if ($fullPath.StartsWith($fullRepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$label must be stored outside this repository: $fullPath"
    }
}

function Assert-DirectoryOutsideRepository($path, $repoRoot, $label) {
    $fullPath = [System.IO.Path]::GetFullPath($path)
    $fullRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    $repoPrefix = $fullRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if ($fullPath.Equals($fullRepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$label must be stored outside this repository: $fullPath"
    }
}

function Find-FirstFile($directory, $filter, $label) {
    if (-not (Test-Path $directory)) {
        throw "Materials directory is missing $label folder: $directory"
    }

    $file = Get-ChildItem -LiteralPath $directory -Filter $filter -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $file) {
        throw "Materials directory is missing $label matching $filter in $directory"
    }
    return $file.FullName
}

function Read-JsonFile($path, $label) {
    if (-not (Test-Path $path)) {
        throw "Materials directory is missing $label`: $path"
    }

    try {
        return Get-Content $path -Raw | ConvertFrom-Json
    } catch {
        throw "$label is not valid JSON: $path"
    }
}

function Use-ValueIfEmpty($currentValue, $newValue) {
    if (-not [string]::IsNullOrWhiteSpace($currentValue)) {
        return $currentValue
    }
    if ($null -eq $newValue) {
        return ""
    }
    return ([string]$newValue).Trim()
}

function Load-MaterialsDirectory($materialsDirectory, $repoRoot) {
    $resolvedMaterialsDirectory = Resolve-Path -LiteralPath $materialsDirectory -ErrorAction Stop
    $materialsRoot = [System.IO.Path]::GetFullPath($resolvedMaterialsDirectory.Path)
    Assert-DirectoryOutsideRepository $materialsRoot $repoRoot "Apple materials directory"

    $releaseSecrets = Read-JsonFile (Join-Path $materialsRoot "release-secrets.private.json") "release-secrets.private.json"
    $reviewContact = Read-JsonFile (Join-Path $materialsRoot "03-review-contact\review-contact.private.json") "review-contact.private.json"

    [pscustomobject]@{
        Root = $materialsRoot
        ReleaseSecrets = $releaseSecrets
        ReviewContact = $reviewContact
        ApiKeyPath = Find-FirstFile (Join-Path $materialsRoot "01-app-store-connect-api-key") "AuthKey_*.p8" "App Store Connect API key"
        DistributionCertificatePath = Find-FirstFile (Join-Path $materialsRoot "02-signing") "*.p12" "Apple Distribution certificate"
        AppStoreProfilePath = Find-FirstFile (Join-Path $materialsRoot "02-signing") "*.mobileprovision" "App Store provisioning profile"
    }
}

function Convert-FileToBase64($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    return [Convert]::ToBase64String($bytes)
}

function Set-GitHubSecret($ghPath, $repoFullName, $name, $value, $dryRun) {
    if ([string]::IsNullOrEmpty($value)) {
        throw "Secret $name cannot be empty."
    }

    if ($dryRun) {
        Write-Host "dry-run: would set $name"
        return
    }

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $ghPath
    $processStartInfo.Arguments = "secret set $name --repo $repoFullName"
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardInput = $true
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo
    [void]$process.Start()
    $process.StandardInput.Write($value)
    $process.StandardInput.Close()
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($standardOutput) {
        Write-Host $standardOutput.Trim()
    }
    if ($process.ExitCode -ne 0) {
        if ($standardError) {
            Write-Host $standardError.Trim()
        }
        throw "Could not set GitHub secret $name."
    }
}

if ((@($UploadOnly, $SigningOnly, $ReviewOnly) | Where-Object { $_ }).Count -gt 1) {
    throw "Use only one of -UploadOnly, -SigningOnly, or -ReviewOnly."
}

$configureUploadSecrets = -not $SigningOnly -and -not $ReviewOnly
$configureSigningSecrets = -not $UploadOnly -and -not $ReviewOnly
$configureReviewSecrets = -not $UploadOnly -and -not $SigningOnly

$ghPath = Resolve-GitHubCli

Write-Section "GitHub CLI"
Write-Host "gh=$ghPath"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$authOutput = & $ghPath auth status 2>&1
$authExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($authExitCode -ne 0) {
    Write-Host $authOutput
    throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
}
Write-Host "gh authenticated"

Write-Section "Repository"
if ([string]::IsNullOrWhiteSpace($RepoFullName)) {
    $RepoFullName = (& $ghPath repo view --json nameWithOwner --jq ".nameWithOwner").Trim()
}
if (-not $RepoFullName -or -not $RepoFullName.Contains("/")) {
    throw "RepoFullName must look like owner/repo."
}
Write-Host "repo=$RepoFullName"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) {
    throw "Could not determine the repository root."
}

if (-not [string]::IsNullOrWhiteSpace($MaterialsDirectory)) {
    Write-Section "Apple materials folder"
    $materials = Load-MaterialsDirectory $MaterialsDirectory $repoRoot
    Write-Host "materials=$($materials.Root)"

    $AppStoreConnectUsername = Use-ValueIfEmpty $AppStoreConnectUsername $materials.ReleaseSecrets.appStoreConnectUsername
    $AppleDeveloperTeamId = Use-ValueIfEmpty $AppleDeveloperTeamId $materials.ReleaseSecrets.appleDeveloperTeamId
    $AppStoreConnectApiKeyId = Use-ValueIfEmpty $AppStoreConnectApiKeyId $materials.ReleaseSecrets.appStoreConnectApiKeyId
    $AppStoreConnectApiIssuerId = Use-ValueIfEmpty $AppStoreConnectApiIssuerId $materials.ReleaseSecrets.appStoreConnectApiIssuerId
    $AppleDistributionCertificatePassword = Use-ValueIfEmpty $AppleDistributionCertificatePassword $materials.ReleaseSecrets.appleDistributionCertificatePassword
    $AppleCodesignKeychainPassword = Use-ValueIfEmpty $AppleCodesignKeychainPassword $materials.ReleaseSecrets.appleCodesignKeychainPassword
    $AppReviewFirstName = Use-ValueIfEmpty $AppReviewFirstName $materials.ReviewContact.firstName
    $AppReviewLastName = Use-ValueIfEmpty $AppReviewLastName $materials.ReviewContact.lastName
    $AppReviewEmail = Use-ValueIfEmpty $AppReviewEmail $materials.ReviewContact.email
    $AppReviewPhone = Use-ValueIfEmpty $AppReviewPhone $materials.ReviewContact.phone
    $AppStoreConnectApiKeyPath = Use-ValueIfEmpty $AppStoreConnectApiKeyPath $materials.ApiKeyPath
    $AppleDistributionCertificatePath = Use-ValueIfEmpty $AppleDistributionCertificatePath $materials.DistributionCertificatePath
    $AppleAppStoreProfilePath = Use-ValueIfEmpty $AppleAppStoreProfilePath $materials.AppStoreProfilePath
}

if ($configureUploadSecrets) {
    Write-Section "App Store Connect upload secrets"
    $AppStoreConnectUsername = Read-RequiredText "App Store Connect username email" $AppStoreConnectUsername
    $AppleDeveloperTeamId = Read-RequiredText "Apple Developer Team ID" $AppleDeveloperTeamId
    $AppStoreConnectApiKeyId = Read-RequiredText "App Store Connect API Key ID" $AppStoreConnectApiKeyId
    $AppStoreConnectApiIssuerId = Read-RequiredText "App Store Connect API Issuer ID" $AppStoreConnectApiIssuerId
    $AppStoreConnectApiKeyPath = Resolve-RequiredPath "Path to App Store Connect AuthKey .p8" $AppStoreConnectApiKeyPath

    Assert-FileOutsideRepository $AppStoreConnectApiKeyPath $repoRoot "App Store Connect .p8 key"

    if ([System.IO.Path]::GetExtension($AppStoreConnectApiKeyPath) -ne ".p8") {
        throw "App Store Connect API key should use the .p8 extension."
    }

    $appStorePrivateKey = [System.IO.File]::ReadAllText($AppStoreConnectApiKeyPath)
    if (-not $appStorePrivateKey.Contains("BEGIN PRIVATE KEY")) {
        throw "The App Store Connect .p8 file does not look like a private key."
    }

    Set-GitHubSecret $ghPath $RepoFullName "APP_STORE_CONNECT_USERNAME" $AppStoreConnectUsername $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APPLE_DEVELOPER_TEAM_ID" $AppleDeveloperTeamId $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APP_STORE_CONNECT_API_KEY_ID" $AppStoreConnectApiKeyId $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APP_STORE_CONNECT_API_ISSUER_ID" $AppStoreConnectApiIssuerId $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APP_STORE_CONNECT_API_PRIVATE_KEY" $appStorePrivateKey $DryRun
}

if ($configureSigningSecrets) {
    Write-Section "Apple signing secrets"
    $AppleDistributionCertificatePath = Resolve-RequiredPath "Path to Apple Distribution .p12 certificate" $AppleDistributionCertificatePath
    $AppleAppStoreProfilePath = Resolve-RequiredPath "Path to App Store .mobileprovision profile" $AppleAppStoreProfilePath
    $AppleDistributionCertificatePassword = Read-RequiredSecretText "Apple Distribution .p12 password" $AppleDistributionCertificatePassword
    $AppleCodesignKeychainPassword = Read-RequiredSecretText "Temporary CI keychain password" $AppleCodesignKeychainPassword

    Assert-FileOutsideRepository $AppleDistributionCertificatePath $repoRoot "Apple Distribution .p12 certificate"
    Assert-FileOutsideRepository $AppleAppStoreProfilePath $repoRoot "App Store provisioning profile"

    if ([System.IO.Path]::GetExtension($AppleDistributionCertificatePath) -ne ".p12") {
        throw "Apple Distribution certificate should use the .p12 extension."
    }
    if ([System.IO.Path]::GetExtension($AppleAppStoreProfilePath) -ne ".mobileprovision") {
        throw "App Store provisioning profile should use the .mobileprovision extension."
    }

    Set-GitHubSecret $ghPath $RepoFullName "APPLE_DISTRIBUTION_CERTIFICATE_BASE64" (Convert-FileToBase64 $AppleDistributionCertificatePath) $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD" $AppleDistributionCertificatePassword $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APPLE_APP_STORE_PROFILE_BASE64" (Convert-FileToBase64 $AppleAppStoreProfilePath) $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APPLE_CODESIGN_KEYCHAIN_PASSWORD" $AppleCodesignKeychainPassword $DryRun
}

if ($configureReviewSecrets) {
    Write-Section "App Review contact secrets"
    $AppReviewFirstName = Read-RequiredText "App Review first name" $AppReviewFirstName
    $AppReviewLastName = Read-RequiredText "App Review last name" $AppReviewLastName
    $AppReviewEmail = Read-RequiredText "App Review email" $AppReviewEmail
    $AppReviewPhone = Read-RequiredSecretText "App Review phone with country code" $AppReviewPhone

    if ($AppReviewEmail -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
        throw "App Review email should look like a valid email address."
    }
    if ($AppReviewPhone -notmatch "^\+?[0-9][0-9\s().-]{6,}$") {
        throw "App Review phone should look like a review-reachable phone number."
    }

    Set-GitHubSecret $ghPath $RepoFullName "APP_REVIEW_FIRST_NAME" $AppReviewFirstName $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APP_REVIEW_LAST_NAME" $AppReviewLastName $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APP_REVIEW_EMAIL" $AppReviewEmail $DryRun
    Set-GitHubSecret $ghPath $RepoFullName "APP_REVIEW_PHONE" $AppReviewPhone $DryRun
}

if ($DryRun) {
    Write-Section "Dry run complete"
    Write-Host "No GitHub secrets were changed."
    exit 0
}

Write-Section "Configured secrets"
& $ghPath secret list --repo $RepoFullName

Write-Host ""
Write-Host "Apple GitHub secrets are configured for $RepoFullName."
