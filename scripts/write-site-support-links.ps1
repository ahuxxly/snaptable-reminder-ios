param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [string]$SupportEmail = ""
)

$ErrorActionPreference = "Stop"

if ($Owner -notmatch "^[A-Za-z0-9_.-]+$") {
    throw "GitHub owner contains unsupported characters."
}
if ($RepoName -notmatch "^[A-Za-z0-9_.-]+$") {
    throw "GitHub repository name contains unsupported characters."
}
if ($SupportEmail -and $SupportEmail -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
    throw "SupportEmail should be a valid email address."
}

$siteDirectory = Join-Path (Get-Location) "site"
$supportPath = Join-Path $siteDirectory "support.html"
$privacyPath = Join-Path $siteDirectory "privacy.html"

if (-not (Test-Path $supportPath)) {
    throw "Missing site support page: $supportPath"
}
if (-not (Test-Path $privacyPath)) {
    throw "Missing site privacy page: $privacyPath"
}

$issuesUrl = "https://github.com/$Owner/$RepoName/issues"
if ($SupportEmail) {
    $contactHref = "mailto:$SupportEmail"
    $contactLabel = "Email support"
    $contactPhrase = "email support"
} else {
    $contactHref = $issuesUrl
    $contactLabel = "Open a support request on GitHub"
    $contactPhrase = "open a support request on GitHub"
}

$encodedHref = [System.Net.WebUtility]::HtmlEncode($contactHref)
$encodedLabel = [System.Net.WebUtility]::HtmlEncode($contactLabel)
$encodedPhrase = [System.Net.WebUtility]::HtmlEncode($contactPhrase)

function Replace-ExactBlock($Path, $OldBlock, $NewBlock, $Description) {
    $content = Get-Content $Path -Raw
    if ($content.Contains($NewBlock)) {
        Write-Host "$Description already current"
        return
    }
    if (-not $content.Contains($OldBlock)) {
        throw "Could not find expected $Description block in $Path"
    }
    $updated = $content.Replace($OldBlock, $NewBlock)
    Set-Content -Path $Path -Value $updated -NoNewline
    Write-Host "$Description updated"
}

$oldSupportBlock = @'
      <h2>Contact</h2>
      <p>Use the support contact published with the app's App Store listing for app help, privacy questions, and bug reports.</p>
'@

$newSupportBlock = @"
      <h2>Contact</h2>
      <p><a href="$encodedHref">$encodedLabel</a> for app help, privacy questions, and bug reports.</p>
      <p>Do not include private screenshots, receipts, medical documents, legal documents, or identity information in public support requests.</p>
"@

$oldPrivacyBlock = @'
      <h2>Contact</h2>
      <p>For support or privacy questions, use the support contact published with the app's App Store listing.</p>
'@

$newPrivacyBlock = @"
      <h2>Contact</h2>
      <p>For support or privacy questions, use the <a href="support.html">support page</a> or <a href="$encodedHref">$encodedPhrase</a>.</p>
"@

Replace-ExactBlock -Path $supportPath -OldBlock $oldSupportBlock -NewBlock $newSupportBlock -Description "support contact"
Replace-ExactBlock -Path $privacyPath -OldBlock $oldPrivacyBlock -NewBlock $newPrivacyBlock -Description "privacy contact"

Write-Host "support_contact_url=$contactHref"
