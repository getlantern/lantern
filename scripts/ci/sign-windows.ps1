<#
.SYNOPSIS
    Signs a Windows binary using SignPath.

.DESCRIPTION
    Submits a file to SignPath for code signing, waits for completion,
    and downloads the signed artifact back to the original path.

.PARAMETER FilePath
    Path to the file to sign. The signed file will overwrite this path.

.PARAMETER SigningPolicy
    SignPath signing policy slug ('prod-policy' or 'test-policy').

.PARAMETER OrganizationId
    SignPath organization ID.

.PARAMETER ProjectSlug
    SignPath project slug.

.PARAMETER ApiToken
    SignPath API token.

.PARAMETER ArtifactConfigurationSlug
    Optional SignPath artifact configuration slug (required for zip bundles).

.PARAMETER Description
    Optional description for the signing request.

.PARAMETER MaxAttempts
    Maximum number of polling attempts (default: 60).

.PARAMETER PollIntervalSeconds
    Seconds between polling attempts (default: 10).

.PARAMETER IsTestCertificate
    When set, allows relaxed signature verification for test/self-signed certificates.

.EXAMPLE
    ./sign-windows.ps1 -FilePath "build/lantern.exe" -SigningPolicy "prod-policy" `
        -OrganizationId $env:SIGNPATH_ORG_ID -ProjectSlug "lantern" -ApiToken $env:SIGNPATH_API_TOKEN
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("prod-policy", "test-policy")]
    [string]$SigningPolicy,

    [Parameter(Mandatory = $true)]
    [string]$OrganizationId,

    [Parameter(Mandatory = $true)]
    [string]$ProjectSlug,

    [Parameter(Mandatory = $true)]
    [string]$ApiToken,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactConfigurationSlug = "",

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [int]$MaxAttempts = 60,

    [Parameter(Mandatory = $false)]
    [int]$PollIntervalSeconds = 10,

    [Parameter(Mandatory = $false)]
    [switch]$IsTestCertificate = $false
)

$ErrorActionPreference = "Stop"

# Validate file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
}

$fileName = Split-Path $FilePath -Leaf
$ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
$archiveExtensions = @('.zip', '.7z', '.rar', '.tar', '.gz', '.tgz', '.bz2')

if (($archiveExtensions -contains $ext) -and [string]::IsNullOrWhiteSpace($ArtifactConfigurationSlug)) {
    Write-Error "ArtifactConfigurationSlug is required when signing archive artifacts ($ext): $fileName"
}

Write-Host "=== SignPath Signing ==="
Write-Host "File: $fileName"
Write-Host "Policy: $SigningPolicy"
Write-Host "========================"

# Submit signing request
Write-Host "Submitting signing request..."

$form = @{
    "ProjectSlug"      = $ProjectSlug
    "SigningPolicySlug" = $SigningPolicy
    "Artifact"         = Get-Item $FilePath
    "Description"      = if ($Description) { $Description } else { "Signing $fileName" }
}
if ($ArtifactConfigurationSlug) {
    $form["ArtifactConfigurationSlug"] = $ArtifactConfigurationSlug
}

$response = Invoke-WebRequest -Method POST `
    -Uri "https://app.signpath.io/API/v1/$OrganizationId/SigningRequests" `
    -Headers @{ "Authorization" = "Bearer $ApiToken" } `
    -SkipHttpErrorCheck `
    -Form $form

if ($response.StatusCode -ne 201) {
    Write-Error "Failed to submit signing request: HTTP $($response.StatusCode) - $($response.Content)"
}

$signRequestUrl = $response.Headers.Location[0]
Write-Host "Signing request submitted: $signRequestUrl"

# Poll for completion
Write-Host "Waiting for signing to complete..."

$attempt = 0
:certStatusCheck while ($attempt -lt $MaxAttempts) {
    Start-Sleep -Seconds $PollIntervalSeconds
    $attempt++

    $status = Invoke-RestMethod -Method GET `
        -Uri $signRequestUrl `
        -Headers @{ "Authorization" = "Bearer $ApiToken" } `
        -SkipHttpErrorCheck

    Write-Host "Status: $($status.Status) (attempt $attempt/$MaxAttempts)"

    switch ($status.Status) {
        { $_ -in @("Failed", "Denied") } {
            Write-Error "Signing failed with status: $($status.Status)"
        }
        "Completed" {
            break certStatusCheck
        }
        { $attempt -ge $MaxAttempts } {
            Write-Error "Timeout waiting for signing to complete after $MaxAttempts attempts"
        }
    }
}

# Download signed artifact
Write-Host "Signing completed successfully!"

$tempFile = "$FilePath.signed"
Invoke-WebRequest -Method GET `
    -Uri "$signRequestUrl/SignedArtifact" `
    -Headers @{ "Authorization" = "Bearer $ApiToken" } `
    -OutFile $tempFile

Move-Item -Force $tempFile $FilePath
Write-Host "Downloaded signed artifact to: $FilePath"

# Verify signature (only for PE files, not archives)
if ($ext -in @('.exe', '.dll', '.sys', '.msi')) {
    $sig = Get-AuthenticodeSignature -FilePath $FilePath
    Write-Host "=== Signature Verification ==="
    Write-Host "Status: $($sig.Status)"
    Write-Host "Signer: $($sig.SignerCertificate.Subject)"
    Write-Host "Thumbprint: $($sig.SignerCertificate.Thumbprint)"
    Write-Host "=============================="

    if ($sig.Status -ne "Valid") {
        $isSelfSignedFlow = $IsTestCertificate

        # Always fail on HashMismatch regardless of policy.
        if ($sig.Status -eq "HashMismatch") {
            Write-Error "Signature verification failed (hash mismatch): $($sig.Status) for policy '$SigningPolicy'"
        }

        if (-not $isSelfSignedFlow) {
            # For production/EV signing, require a strictly valid signature.
            Write-Error "Signature verification failed for policy '$SigningPolicy': $($sig.Status)"
        }

        # For self-signed/test policies, allow only a narrow set of expected statuses.
        $allowedSelfSignedStatuses = @("Valid", "UnknownError")
        if ($allowedSelfSignedStatuses -notcontains $sig.Status) {
            Write-Error "Signature verification failed for self-signed/test policy '$SigningPolicy': $($sig.Status)"
        }

        Write-Warning "Signature status is $($sig.Status) for self-signed/test policy '$SigningPolicy' - this may be expected for self-signed certificates"
    }
} else {
    Write-Host "Skipping authenticode verification for non-PE file: $fileName"
}

Write-Host "Signing complete: $fileName"
$global:LASTEXITCODE = 0
