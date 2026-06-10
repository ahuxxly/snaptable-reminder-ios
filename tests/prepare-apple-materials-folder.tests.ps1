$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "scripts\prepare-apple-materials-folder.ps1"
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

function Invoke-MaterialsScript($arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments 2>&1 | Out-String
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("snaptable-apple-materials-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Run-Test "creates a private Apple materials folder outside the repository" {
        $target = Join-Path $tempRoot "materials"
        $result = Invoke-MaterialsScript @("-OutputDirectory", $target)

        Assert-True ($result.ExitCode -eq 0) "expected exit 0, got $($result.ExitCode): $($result.Output)"
        Assert-True (Test-Path (Join-Path $target "README.md")) "README.md was not created"
        Assert-True (Test-Path (Join-Path $target ".gitignore")) ".gitignore was not created"
        Assert-True (Test-Path (Join-Path $target "01-app-store-connect-api-key")) "API key folder was not created"
        Assert-True (Test-Path (Join-Path $target "02-signing")) "signing folder was not created"
        Assert-True (Test-Path (Join-Path $target "03-review-contact")) "review contact folder was not created"
        Assert-True (Test-Path (Join-Path $target "04-eu-dsa")) "EU DSA folder was not created"

        $readme = [System.IO.File]::ReadAllText((Join-Path $target "README.md"))
        Assert-Contains $readme "Do not commit" "README should warn against committing private material"
        Assert-Contains $readme "github-set-apple-secrets.ps1" "README should point to the GitHub secret helper"
        Assert-Contains $readme "com.snaptable.reminder" "README should include the bundle id"
    }

    Run-Test "refuses repository paths unless explicitly allowed" {
        $insideRepo = Join-Path $repoRoot ".tmp-apple-materials-inside-test"
        if (Test-Path $insideRepo) {
            Remove-Item -LiteralPath $insideRepo -Recurse -Force
        }

        try {
            $result = Invoke-MaterialsScript @("-OutputDirectory", $insideRepo)

            Assert-True ($result.ExitCode -ne 0) "expected a nonzero exit for repository-local material storage"
            Assert-Contains $result.Output "outside this repository" "expected the safety error to mention repository storage"
            Assert-True (-not (Test-Path $insideRepo)) "script should not create repository-local private folders by default"
        } finally {
            if (Test-Path $insideRepo) {
                Remove-Item -LiteralPath $insideRepo -Recurse -Force
            }
        }
    }

    Run-Test "validate-only reports missing Apple release material" {
        $target = Join-Path $tempRoot "missing-materials"
        $createResult = Invoke-MaterialsScript @("-OutputDirectory", $target)
        Assert-True ($createResult.ExitCode -eq 0) "setup failed: $($createResult.Output)"

        $result = Invoke-MaterialsScript @("-OutputDirectory", $target, "-ValidateOnly")

        Assert-True ($result.ExitCode -ne 0) "expected validation to fail while private material is missing"
        Assert-Contains $result.Output ".p8" "missing API key should be reported"
        Assert-Contains $result.Output ".p12" "missing distribution certificate should be reported"
        Assert-Contains $result.Output ".mobileprovision" "missing provisioning profile should be reported"
        Assert-Contains $result.Output "review-contact.private.json" "missing review contact should be reported"
        Assert-Contains $result.Output "dsa-private-evidence.md" "missing DSA evidence should be reported"
    }

    Run-Test "validate-only passes after required private material is present" {
        $target = Join-Path $tempRoot "complete-materials"
        $createResult = Invoke-MaterialsScript @("-OutputDirectory", $target)
        Assert-True ($createResult.ExitCode -eq 0) "setup failed: $($createResult.Output)"

        Set-Content -Path (Join-Path $target "00-account\account-private-status.md") -Encoding UTF8 -Value @"
# Private Account Status

- Apple Developer Program: active
- Paid Apps Agreement: accepted
- Tax: complete
- Banking: complete
- App Store Connect app: com.snaptable.reminder created
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
  "email": "reviewer@sample.invalid",
  "phone": "+1 555 010 1000"
}
"@
        Set-Content -Path (Join-Path $target "04-eu-dsa\dsa-private-evidence.md") -Encoding UTF8 -Value @"
# Private EU DSA Evidence

- EU storefronts: included
- Trader status decision: completed
"@

        $result = Invoke-MaterialsScript @("-OutputDirectory", $target, "-ValidateOnly")

        Assert-True ($result.ExitCode -eq 0) "expected validation to pass, got $($result.ExitCode): $($result.Output)"
        Assert-Contains $result.Output "Apple material folder is ready" "success output should summarize readiness"
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
    Write-Host "prepare-apple-materials-folder tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "prepare-apple-materials-folder tests passed."
