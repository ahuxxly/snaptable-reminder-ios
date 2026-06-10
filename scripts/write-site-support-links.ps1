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

function Replace-ContactBlock($Path, $Pattern, $NewBlock, $Description) {
    $content = Get-Content $Path -Raw
    if ($content.Contains($NewBlock)) {
        Write-Host "$Description already current"
        return
    }
    if (-not [regex]::IsMatch($content, $Pattern)) {
        throw "Could not find expected $Description block in $Path"
    }
    $updated = [regex]::Replace(
        $content,
        $Pattern,
        [System.Text.RegularExpressions.MatchEvaluator] { param($match) $NewBlock },
        1
    )
    Set-Content -Path $Path -Value $updated -NoNewline
    Write-Host "$Description updated"
}

$newSupportBlock = @"
      <h2>Contact</h2>
      <p><a href="$encodedHref">$encodedLabel</a> for app help, privacy questions, and bug reports.</p>
      <p>Do not include private screenshots, receipts, medical documents, legal documents, or identity information in public support requests.</p>
"@

$newPrivacyBlock = @"
      <h2>Contact</h2>
      <p>For support or privacy questions, use the <a href="support.html">support page</a> or <a href="$encodedHref">$encodedPhrase</a>.</p>
"@

$supportContactPattern = '(?s)      <h2>Contact</h2>\r?\n      <p>.*?</p>(?:\r?\n      <p>Do not include private screenshots.*?</p>)?'
$privacyContactPattern = '(?s)      <h2>Contact</h2>\r?\n      <p>.*?</p>'

Replace-ContactBlock -Path $supportPath -Pattern $supportContactPattern -NewBlock $newSupportBlock -Description "support contact"
Replace-ContactBlock -Path $privacyPath -Pattern $privacyContactPattern -NewBlock $newPrivacyBlock -Description "privacy contact"

Write-Host "support_contact_url=$contactHref"
