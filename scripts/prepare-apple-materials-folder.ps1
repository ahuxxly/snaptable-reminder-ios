param(
    [string]$OutputDirectory = "",
    [switch]$ValidateOnly,
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

function Resolve-FullPath($path) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "OutputDirectory cannot be empty."
    }

    if ([System.IO.Path]::IsPathRooted($path)) {
        return [System.IO.Path]::GetFullPath($path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $path))
}

function Assert-PrivateFolderLocation($materialsRoot, $repoRoot, $allowWorkspacePath) {
    if ($allowWorkspacePath) {
        return
    }

    $resolvedMaterialsRoot = [System.IO.Path]::GetFullPath($materialsRoot)
    $resolvedRepoRoot = [System.IO.Path]::GetFullPath($repoRoot)
    $repoPrefix = $resolvedRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if ($resolvedMaterialsRoot.Equals($resolvedRepoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedMaterialsRoot.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Apple private material must be stored outside this repository: $resolvedMaterialsRoot"
    }
}

function Set-TextFileIfMissing($path, $content) {
    if (-not (Test-Path $path)) {
        $parent = Split-Path -Parent $path
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent | Out-Null
        }
        Set-Content -Path $path -Encoding UTF8 -Value $content
    }
}

function Initialize-MaterialsFolder($materialsRoot) {
    $directories = @(
        "00-account",
        "01-app-store-connect-api-key",
        "02-signing",
        "03-review-contact",
        "04-eu-dsa",
        "05-release-evidence"
    )

    New-Item -ItemType Directory -Path $materialsRoot -Force | Out-Null
    foreach ($directory in $directories) {
        $directoryPath = Join-Path $materialsRoot $directory
        New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null
        Set-TextFileIfMissing (Join-Path $directoryPath ".keep") ""
    }

    Set-TextFileIfMissing (Join-Path $materialsRoot ".gitignore") @"
*
!.gitignore
!README.md
!*.template.*
!.keep
"@

    Set-TextFileIfMissing (Join-Path $materialsRoot "00-account\account-private-status.template.md") @"
# Private Account Status Template

Keep a private copy after checking App Store Connect.

- Apple Developer Program: active
- Paid Apps Agreement: accepted
- Tax: complete
- Banking: complete
- App Store Connect app: com.snaptable.reminder created
"@

    Set-TextFileIfMissing (Join-Path $materialsRoot "03-review-contact\review-contact.template.json") @"
{
  "firstName": "App",
  "lastName": "Reviewer",
  "email": "reviewer@sample.invalid",
  "phone": "+1 555 010 1000"
}
"@

    Set-TextFileIfMissing (Join-Path $materialsRoot "04-eu-dsa\dsa-private-evidence.template.md") @"
# Private EU DSA Evidence Template

- EU storefronts: included or deferred
- Trader status decision: completed
- Contact verification: completed if the account is a trader account
"@

    Set-TextFileIfMissing (Join-Path $materialsRoot "release-secrets.template.json") @"
{
  "appStoreConnectUsername": "account@example.com",
  "appleDeveloperTeamId": "TEAMID1234",
  "appStoreConnectApiKeyId": "KEYID1234",
  "appStoreConnectApiIssuerId": "00000000-0000-0000-0000-000000000000",
  "appleDistributionCertificatePassword": "p12-export-password",
  "appleCodesignKeychainPassword": "temporary-ci-keychain-password"
}
"@

    Set-TextFileIfMissing (Join-Path $materialsRoot "README.md") @'
# SnapTable Reminder Apple Release Materials

This folder is for private Apple release material for `com.snaptable.reminder`.
Do not commit this folder, screenshots of private Apple pages, tax records, banking records, identity documents, App Review contact details, `.p8`, `.p12`, or `.mobileprovision` files.

## What to Put Here

- `00-account/account-private-status.md`: private notes that Apple Developer Program, Paid Apps Agreement, tax, banking, and the App Store Connect app record are complete.
- `01-app-store-connect-api-key/AuthKey_<key-id>.p8`: App Store Connect API key downloaded once from App Store Connect.
- `02-signing/*.p12`: Apple Distribution certificate exported from Keychain Access.
- `02-signing/*.mobileprovision`: App Store provisioning profile for `com.snaptable.reminder`.
- `03-review-contact/review-contact.private.json`: private App Review contact details.
- `04-eu-dsa/dsa-private-evidence.md`: private EU Digital Services Act decision evidence.
- `05-release-evidence/`: screenshots or notes proving upload, TestFlight processing, and App Review submission status.
- `release-secrets.private.json`: private upload/signing values used by `scripts/github-set-apple-secrets.ps1 -MaterialsDirectory`.

## After Materials Exist

From the repository root, validate this private folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/prepare-apple-materials-folder.ps1 -OutputDirectory "$materialsRoot" -ValidateOnly
```

If all Apple files and private values are ready, the staging helper can copy and write the required private files for you:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stage-apple-release-materials.ps1 -OutputDirectory "$materialsRoot" -AppStoreConnectApiKeyPath "C:\path\to\AuthKey_KEYID1234.p8" -AppleDistributionCertificatePath "C:\path\to\apple-distribution.p12" -AppleAppStoreProfilePath "C:\path\to\SnapTableReminder_AppStore.mobileprovision" -DsaEvidencePath "C:\path\to\dsa-private-evidence.md" -AppStoreConnectUsername "account@example.invalid" -AppleDeveloperTeamId "TEAMID1234" -AppStoreConnectApiKeyId "KEYID1234" -AppStoreConnectApiIssuerId "00000000-0000-0000-0000-000000000000" -AppleDistributionCertificatePassword "p12-export-password" -AppleCodesignKeychainPassword "temporary-ci-keychain-password" -ReviewFirstName "App" -ReviewLastName "Reviewer" -ReviewEmail "reviewer@example.invalid" -ReviewPhone "+1 555 010 1000" -AppleDeveloperProgramActive -PaidAppsAgreementActive -TaxComplete -BankingComplete -AppStoreConnectAppCreated -DryRun
```

Then set GitHub secrets:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -MaterialsDirectory "$materialsRoot" -UploadOnly
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -MaterialsDirectory "$materialsRoot" -SigningOnly
powershell -ExecutionPolicy Bypass -File scripts/github-set-apple-secrets.ps1 -MaterialsDirectory "$materialsRoot" -ReviewOnly
```

Use `-DryRun` first when you only want to verify paths and field shapes.

After TestFlight upload and App Review submission, record private release evidence:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/record-app-store-connect-setup-evidence.ps1 -MaterialsDirectory "$materialsRoot" -AppStoreConnectAppId "1234567890" -AppName "SnapTable Reminder" -BundleId "com.snaptable.reminder" -Sku "SNAPTABLE-REMINDER-IOS-V1" -PrimaryLanguage "en-US" -PrimaryCategory "Productivity" -PriceCurrency "USD" -PriceAmount "1.99" -AvailabilityMode "selectedCountriesOrRegions" -ExcludedCountriesOrRegions "China mainland" -PrivacyPolicyUrl "https://ahuxxly.github.io/snaptable-reminder-ios/privacy.html" -SupportUrl "https://ahuxxly.github.io/snaptable-reminder-ios/support.html" -PrivacyAnswersCompleted -AgeRatingCompleted -ExportComplianceCompleted -EuDsaTraderStatusCompleted -DryRun
powershell -ExecutionPolicy Bypass -File scripts/record-app-store-release-evidence.ps1 -MaterialsDirectory "$materialsRoot" -AppStoreConnectAppId "1234567890" -AppVersion "1.0" -BuildNumber "1" -MetadataUploaded -ScreenshotsUploaded -ReviewCheckPassed -TestFlightUploaded -BuildProcessed -AppReviewSubmitted -AppStatus "Waiting for Review" -DryRun
```
'@
}

function Find-FirstFile($directory, $filter) {
    if (-not (Test-Path $directory)) {
        return $null
    }

    return Get-ChildItem -LiteralPath $directory -Filter $filter -File -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Add-Missing($missingItems, $message) {
    $missingItems.Add($message) | Out-Null
}

function Test-MaterialsFolder($materialsRoot) {
    $missingItems = New-Object "System.Collections.Generic.List[string]"

    if (-not (Test-Path $materialsRoot)) {
        Add-Missing $missingItems "Materials folder does not exist: $materialsRoot"
        return $missingItems
    }

    $accountPath = Join-Path $materialsRoot "00-account\account-private-status.md"
    if (-not (Test-Path $accountPath)) {
        Add-Missing $missingItems "Missing 00-account/account-private-status.md with Apple Developer Program, Paid Apps Agreement, tax, banking, and app record evidence."
    } else {
        $accountText = Get-Content $accountPath -Raw
        foreach ($term in @("Apple Developer Program", "Paid Apps Agreement", "Tax", "Banking", "com.snaptable.reminder")) {
            if (-not $accountText.Contains($term)) {
                Add-Missing $missingItems "00-account/account-private-status.md should mention $term."
            }
        }
    }

    $apiKeyDirectory = Join-Path $materialsRoot "01-app-store-connect-api-key"
    $apiKeyFile = Find-FirstFile $apiKeyDirectory "AuthKey_*.p8"
    if ($null -eq $apiKeyFile) {
        Add-Missing $missingItems "Missing App Store Connect API key: 01-app-store-connect-api-key/AuthKey_<key-id>.p8."
    } else {
        $apiKeyText = Get-Content $apiKeyFile.FullName -Raw
        if (-not $apiKeyText.Contains("BEGIN PRIVATE KEY")) {
            Add-Missing $missingItems "App Store Connect .p8 file does not look like a private key: $($apiKeyFile.Name)."
        }
    }

    $signingDirectory = Join-Path $materialsRoot "02-signing"
    $certificateFile = Find-FirstFile $signingDirectory "*.p12"
    if ($null -eq $certificateFile) {
        Add-Missing $missingItems "Missing Apple Distribution certificate: 02-signing/*.p12."
    } elseif ($certificateFile.Length -le 0) {
        Add-Missing $missingItems "Apple Distribution .p12 file is empty: $($certificateFile.Name)."
    }

    $profileFile = Find-FirstFile $signingDirectory "*.mobileprovision"
    if ($null -eq $profileFile) {
        Add-Missing $missingItems "Missing App Store provisioning profile: 02-signing/*.mobileprovision."
    } elseif ($profileFile.Length -le 0) {
        Add-Missing $missingItems "App Store provisioning profile file is empty: $($profileFile.Name)."
    }

    $releaseSecretsPath = Join-Path $materialsRoot "release-secrets.private.json"
    if (-not (Test-Path $releaseSecretsPath)) {
        Add-Missing $missingItems "Missing private release secret values: release-secrets.private.json."
    } else {
        try {
            $releaseSecrets = Get-Content $releaseSecretsPath -Raw | ConvertFrom-Json
            foreach ($field in @(
                "appStoreConnectUsername",
                "appleDeveloperTeamId",
                "appStoreConnectApiKeyId",
                "appStoreConnectApiIssuerId",
                "appleDistributionCertificatePassword",
                "appleCodesignKeychainPassword"
            )) {
                if ([string]::IsNullOrWhiteSpace([string]$releaseSecrets.$field)) {
                    Add-Missing $missingItems "release-secrets.private.json is missing $field."
                }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$releaseSecrets.appStoreConnectUsername) -and [string]$releaseSecrets.appStoreConnectUsername -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
                Add-Missing $missingItems "release-secrets.private.json appStoreConnectUsername should look like an email address."
            }
        } catch {
            Add-Missing $missingItems "release-secrets.private.json is not valid JSON."
        }
    }

    $reviewContactPath = Join-Path $materialsRoot "03-review-contact\review-contact.private.json"
    if (-not (Test-Path $reviewContactPath)) {
        Add-Missing $missingItems "Missing App Review contact file: 03-review-contact/review-contact.private.json."
    } else {
        try {
            $reviewContact = Get-Content $reviewContactPath -Raw | ConvertFrom-Json
            foreach ($field in @("firstName", "lastName", "email", "phone")) {
                if ([string]::IsNullOrWhiteSpace([string]$reviewContact.$field)) {
                    Add-Missing $missingItems "review-contact.private.json is missing $field."
                }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$reviewContact.email) -and [string]$reviewContact.email -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
                Add-Missing $missingItems "review-contact.private.json email should look like a valid email address."
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$reviewContact.phone) -and [string]$reviewContact.phone -notmatch "^\+?[0-9][0-9\s().-]{6,}$") {
                Add-Missing $missingItems "review-contact.private.json phone should include a reachable country code phone number."
            }
        } catch {
            Add-Missing $missingItems "review-contact.private.json is not valid JSON."
        }
    }

    $dsaEvidencePath = Join-Path $materialsRoot "04-eu-dsa\dsa-private-evidence.md"
    if (-not (Test-Path $dsaEvidencePath)) {
        Add-Missing $missingItems "Missing EU DSA evidence file: 04-eu-dsa/dsa-private-evidence.md."
    } else {
        $dsaText = Get-Content $dsaEvidencePath -Raw
        if (-not $dsaText.Contains("EU storefronts")) {
            Add-Missing $missingItems "dsa-private-evidence.md should record whether EU storefronts are included or deferred."
        }
        if (-not $dsaText.Contains("Trader status decision")) {
            Add-Missing $missingItems "dsa-private-evidence.md should record the trader status decision."
        }
    }

    return $missingItems
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Get-DefaultMaterialsDirectory
}

$repoRoot = Resolve-RepositoryRoot
$materialsRoot = Resolve-FullPath $OutputDirectory
Assert-PrivateFolderLocation $materialsRoot $repoRoot $AllowWorkspacePath

Write-Section "Apple materials folder"
Write-Host "repo=$repoRoot"
Write-Host "materials=$materialsRoot"

if (-not $ValidateOnly) {
    Initialize-MaterialsFolder $materialsRoot
    Write-Host "Private material folder prepared."
}

if ($ValidateOnly) {
    Write-Section "Validation"
    $missingItems = Test-MaterialsFolder $materialsRoot
    if ($missingItems.Count -gt 0) {
        Write-Host "Apple material folder is not ready."
        foreach ($missingItem in $missingItems) {
            Write-Host "- $missingItem"
        }
        exit 2
    }

    Write-Host "Apple material folder is ready: $materialsRoot"
}
