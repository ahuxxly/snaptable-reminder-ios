$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$releaseDoctorPath = Join-Path $repoRoot "scripts\release-doctor.ps1"
$failures = New-Object "System.Collections.Generic.List[string]"

function Assert-True($condition, $message) {
    if (-not $condition) {
        throw $message
    }
}

function Invoke-Test($name, [scriptblock]$body) {
    try {
        & $body
        Write-Host "[PASS] $name"
    } catch {
        $failures.Add("$name`: $($_.Exception.Message)") | Out-Null
        Write-Host "[FAIL] $name"
        Write-Host $_.Exception.Message
    }
}

. $releaseDoctorPath -LoadFunctionsOnly

Invoke-Test "marks workflow run OK when latest successful run matches current head" {
    $gates = New-Object "System.Collections.Generic.List[object]"
    $latestRun = [pscustomobject]@{
        status = "completed"
        conclusion = "success"
        headSha = "abc123"
        url = "https://github.com/owner/repo/actions/runs/1"
    }

    Add-WorkflowRunGate $gates "iOS CI" $latestRun "abc123" $true

    Assert-True ($gates.Count -eq 1) "expected one gate"
    Assert-True ($gates[0].Status -eq "OK") "matching successful run should be OK"
    Assert-True ($gates[0].Detail.Contains("Latest run succeeded")) "OK detail should describe success"
}

Invoke-Test "warns when latest successful workflow run is stale for current head" {
    $gates = New-Object "System.Collections.Generic.List[object]"
    $latestRun = [pscustomobject]@{
        status = "completed"
        conclusion = "success"
        headSha = "old456"
        url = "https://github.com/owner/repo/actions/runs/2"
    }

    Add-WorkflowRunGate $gates "iOS CI" $latestRun "new789" $true

    Assert-True ($gates.Count -eq 1) "expected one gate"
    Assert-True ($gates[0].Status -eq "WARN") "stale successful run should be a warning"
    Assert-True ($gates[0].Detail.Contains("old456")) "warning should name the stale run sha"
    Assert-True ($gates[0].NextAction.Contains("workflow_dispatch")) "warning should tell the user to run the manual workflow"
}

Invoke-Test "blocks failed workflow run even when it matches current head" {
    $gates = New-Object "System.Collections.Generic.List[object]"
    $latestRun = [pscustomobject]@{
        status = "completed"
        conclusion = "failure"
        headSha = "abc123"
        url = "https://github.com/owner/repo/actions/runs/3"
    }

    Add-WorkflowRunGate $gates "iOS CI" $latestRun "abc123" $true

    Assert-True ($gates.Count -eq 1) "expected one gate"
    Assert-True ($gates[0].Status -eq "BLOCKED") "failed run should be blocked"
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "release-doctor workflow gate tests failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host ""
Write-Host "release-doctor workflow gate tests passed."
