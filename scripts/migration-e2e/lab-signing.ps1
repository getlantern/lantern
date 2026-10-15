param(
    [string]$BuildDirectory,
    [string]$Thumbprint
)

$ErrorActionPreference = 'Stop'

function Get-LabSigningCertificate {
    param([Parameter(Mandatory)][string]$Thumbprint)
    if ($Thumbprint -notmatch '^[A-Fa-f0-9]{40}$') { throw 'Invalid lab certificate thumbprint' }
    $certificate = Get-Item "Cert:\CurrentUser\My\$Thumbprint"
    if ($certificate.Subject -ne 'CN=Lantern Migration Lab' -or -not $certificate.HasPrivateKey) {
        throw 'Expected the ephemeral migration lab signing certificate'
    }
    return $certificate
}

function New-LabSigningCertificate {
    param([Parameter(Mandatory)][string]$OutputDirectory)
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $certificate = New-SelfSignedCertificate -Type CodeSigningCert `
        -Subject 'CN=Lantern Migration Lab' -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 `
        -KeyExportPolicy NonExportable -CertStoreLocation Cert:\CurrentUser\My `
        -NotAfter (Get-Date).AddDays(7)
    try {
        $publicPath = Join-Path (Resolve-Path $OutputDirectory) 'lab-signing.cer'
        Export-Certificate -Cert $certificate -FilePath $publicPath -Type CERT | Out-Null
        foreach ($store in 'Root', 'TrustedPublisher') {
            Import-Certificate -FilePath $publicPath -CertStoreLocation "Cert:\LocalMachine\$store" | Out-Null
        }
        [ordered]@{
            schema_version = 1
            signing_mode = 'lab'
            subject = $certificate.Subject
            signer_thumbprint = $certificate.Thumbprint
            certificate_sha256 = (Get-FileHash $publicPath -Algorithm SHA256).Hash.ToLowerInvariant()
            expires_at = $certificate.NotAfter.ToUniversalTime().ToString('o')
            production_activation_ready = $false
        } | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'lab-signing.json') -Encoding utf8
        return [pscustomobject]@{ Thumbprint = $certificate.Thumbprint; CertificatePath = $publicPath }
    } catch {
        Remove-LabSigningCertificate -Thumbprint $certificate.Thumbprint
        throw
    }
}

function Assert-LabSignature {
    param([Parameter(Mandatory)][string]$FilePath, [Parameter(Mandatory)][string]$Thumbprint)
    $signature = Get-AuthenticodeSignature -FilePath $FilePath
    if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate -or
        $signature.SignerCertificate.Thumbprint -ne $Thumbprint -or -not $signature.TimeStamperCertificate) {
        throw "Invalid or untimestamped lab signature: $FilePath ($($signature.Status))"
    }
}

function Invoke-LabSigning {
    param([Parameter(Mandatory)][string[]]$FilePath, [Parameter(Mandatory)][string]$Thumbprint)
    $null = Get-LabSigningCertificate -Thumbprint $Thumbprint
    $signTool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $signTool) { throw 'Windows SDK SignTool was not found' }
    foreach ($path in $FilePath) {
        $resolved = (Resolve-Path -LiteralPath $path).Path
        & $signTool sign /sha1 $Thumbprint /s My /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $resolved
        if ($LASTEXITCODE -ne 0) { throw "Lab signing failed: $path" }
        Assert-LabSignature -FilePath $resolved -Thumbprint $Thumbprint
    }
}

function Invoke-LabBuildSigning {
    param([Parameter(Mandatory)][string]$BuildDirectory, [Parameter(Mandatory)][string]$Thumbprint)
    $thirdParty = @('flutter_windows.dll', 'WebView2Loader.dll', 'VC_redist.x64.exe', 'WinSparkle.dll')
    $binaries = @(Get-ChildItem -LiteralPath $BuildDirectory -Recurse -File |
        Where-Object { $_.Extension -in '.exe', '.dll' -and $_.Name -notin $thirdParty })
    if ($binaries.Count -eq 0) { throw 'No first-party Windows binaries were found' }
    Invoke-LabSigning -FilePath $binaries.FullName -Thumbprint $Thumbprint
}

function Remove-LabSigningCertificate {
    param([Parameter(Mandatory)][string]$Thumbprint)
    $certificate = Get-LabSigningCertificate -Thumbprint $Thumbprint
    foreach ($store in 'Root', 'TrustedPublisher') {
        $path = "Cert:\LocalMachine\$store\$($certificate.Thumbprint)"
        if (Test-Path $path) { Remove-Item $path -Force }
    }
    Remove-Item $certificate.PSPath -DeleteKey -Force
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $BuildDirectory -or -not $Thumbprint) { throw 'BuildDirectory and Thumbprint are required' }
    Invoke-LabBuildSigning -BuildDirectory $BuildDirectory -Thumbprint $Thumbprint
}
