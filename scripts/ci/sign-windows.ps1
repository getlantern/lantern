<#
.SYNOPSIS
    Signs a Windows binary using SignPath.

.DESCRIPTION
    Submits a file to SignPath for code signing, waits for completion,
    and downloads the signed artifact back to the original path.

.PARAMETER FilePath
    Path to the file to sign. The signed file will overwrite this path.

.PARAMETER SigningPolicy
    SignPath signing policy slug (e.g., 'release-signing' or 'test-signing').

.PARAMETER OrganizationId
    SignPath organization ID.

.PARAMETER ProjectSlug
    SignPath project slug.

.PARAMETER ApiToken
    SignPath API token.

.PARAMETER Description
    Optional description for the signing request.

.PARAMETER MaxAttempts
    Maximum number of polling attempts (default: 60).

.PARAMETER PollIntervalSeconds
    Seconds between polling attempts (default: 10).

.EXAMPLE
    ./sign-windows.ps1 -FilePath "build/lantern.exe" -SigningPolicy "release-signing" `
        -OrganizationId $env:SIGNPATH_ORG_ID -ProjectSlug "lantern" -ApiToken $env:SIGNPATH_API_TOKEN
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string]$SigningPolicy,

    [Parameter(Mandatory = $true)]
    [string]$OrganizationId,

    [Parameter(Mandatory = $true)]
    [string]$ProjectSlug,

    [Parameter(Mandatory = $true)]
    [string]$ApiToken,

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [int]$MaxAttempts = 60,

    [Parameter(Mandatory = $false)]
    [int]$PollIntervalSeconds = 10
)

$ErrorActionPreference = "Stop"

# Validate file exists
if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$fileName = Split-Path $FilePath -Leaf
Write-Host "=== SignPath Signing ==="
Write-Host "File: $fileName"
Write-Host "Policy: $SigningPolicy"
Write-Host "========================"

# Submit signing request
Write-Host "Submitting signing request..."

$response = Invoke-WebRequest -Method POST `
    -Uri "https://app.signpath.io/API/v1/$OrganizationId/SigningRequests" `
    -Headers @{ "Authorization" = "Bearer $ApiToken" } `
    -SkipHttpErrorCheck `
    -Form @{
        "ProjectSlug" = $ProjectSlug
        "SigningPolicySlug" = $SigningPolicy
        "Artifact" = Get-Item $FilePath
        "Description" = if ($Description) { $Description } else { "Signing $fileName" }
    }

if ($response.StatusCode -ne 201) {
    Write-Error "Failed to submit signing request: HTTP $($response.StatusCode)"
    Write-Host "Response body: $($response.Content)"
    exit 1
}

$signRequestUrl = $response.Headers.Location[0]
Write-Host "Signing request submitted: $signRequestUrl"

# Poll for completion
Write-Host "Waiting for signing to complete..."

$attempt = 0
while ($attempt -lt $MaxAttempts) {
    Start-Sleep -Seconds $PollIntervalSeconds
    $attempt++

    $status = Invoke-RestMethod -Method GET `
        -Uri $signRequestUrl `
        -Headers @{ "Authorization" = "Bearer $ApiToken" }

    Write-Host "Status: $($status.Status) (attempt $attempt/$MaxAttempts)"

    if ($status.Status -eq "Completed") {
        Write-Host "Signing completed successfully!"

        # Download signed artifact to a temp file first
        $tempFile = "${FilePath}.signed"
        Invoke-WebRequest -Method GET `
            -Uri "$signRequestUrl/SignedArtifact" `
            -Headers @{ "Authorization" = "Bearer $ApiToken" } `
            -OutFile $tempFile `
            -SkipHttpErrorCheck

        # Replace original with signed version
        Move-Item -Force $tempFile $FilePath

        Write-Host "Downloaded signed artifact to: $FilePath"

        # Verify signature
        $sig = Get-AuthenticodeSignature -FilePath $FilePath
        Write-Host "=== Signature Verification ==="
        Write-Host "Status: $($sig.Status)"
        Write-Host "Signer: $($sig.SignerCertificate.Subject)"
        Write-Host "Thumbprint: $($sig.SignerCertificate.Thumbprint)"
        Write-Host "=============================="

        if ($sig.Status -ne "Valid") {
            # Determine whether this is a self-signed/test flow based on the signing policy.
            # Example policies mentioned in the script header: 'release-signing' and 'test-signing'.
            $isSelfSignedFlow = $SigningPolicy -like "*test*"

            # Always fail on HashMismatch regardless of policy.
            if ($sig.Status -eq "HashMismatch") {
                Write-Error "Signature verification failed (hash mismatch): $($sig.Status) for policy '$SigningPolicy'"
                exit 1
            }

            if (-not $isSelfSignedFlow) {
                # For production/EV signing, require a strictly valid signature.
                Write-Error "Signature verification failed for policy '$SigningPolicy': $($sig.Status)"
                exit 1
            }

            # For self-signed/test policies, allow only a narrow set of expected statuses.
            $allowedSelfSignedStatuses = @("Valid", "UnknownError")
            if ($allowedSelfSignedStatuses -notcontains $sig.Status) {
                Write-Error "Signature verification failed for self-signed/test policy '$SigningPolicy': $($sig.Status)"
                exit 1
            }

            Write-Warning "Signature status is $($sig.Status) for self-signed/test policy '$SigningPolicy' - this may be expected for self-signed certificates"
        }

        Write-Host "Signing complete: $fileName"
        $global:LASTEXITCODE = 0
        return

    } elseif ($status.Status -eq "Failed" -or $status.Status -eq "Denied") {
        Write-Error "Signing failed with status: $($status.Status)"
        exit 1
    }
}

Write-Error "Timeout waiting for signing to complete after $MaxAttempts attempts"
exit 1
