$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/lab-signing.ps1"

function Assert-Rejected {
    param([scriptblock]$Action)
    try { & $Action } catch { return }
    throw 'Expected the invalid lab signature to be rejected'
}

$directory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$certificate = $null
try {
    $certificate = New-LabSigningCertificate -OutputDirectory $directory
    $public = [Security.Cryptography.X509Certificates.X509Certificate2]::new($certificate.CertificatePath)
    if ($public.HasPrivateKey -or $public.Thumbprint -ne $certificate.Thumbprint) {
        throw 'The exported certificate must contain only the expected public key'
    }
    $private = Get-LabSigningCertificate -Thumbprint $certificate.Thumbprint
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($private)
    Assert-Rejected { $null = $rsa.ExportParameters($true) }
    $rsa.Dispose()
    $source = Join-Path $directory 'main.go'
    $executable = Join-Path $directory 'signed.exe'
    Set-Content $source 'package main; func main() {}' -Encoding utf8
    & go build -o $executable $source
    if ($LASTEXITCODE -ne 0) { throw 'Lab signing fixture compilation failed' }
    Invoke-LabSigning -FilePath $executable -Thumbprint $certificate.Thumbprint
    Assert-Rejected { Assert-LabSignature -FilePath $executable -Thumbprint ('0' * 40) }
    $bytes = [IO.File]::ReadAllBytes($executable)
    $bytes[0x40] = $bytes[0x40] -bxor 1
    [IO.File]::WriteAllBytes($executable, $bytes)
    Assert-Rejected { Assert-LabSignature -FilePath $executable -Thumbprint $certificate.Thumbprint }
    Write-Host 'Lab signing certificate, timestamp, private key protection and tamper checks passed'
} finally {
    if ($certificate) {
        Remove-LabSigningCertificate -Thumbprint $certificate.Thumbprint
        foreach ($store in 'Cert:\CurrentUser\My', 'Cert:\LocalMachine\Root', 'Cert:\LocalMachine\TrustedPublisher') {
            if (Test-Path "$store\$($certificate.Thumbprint)") { throw 'Lab certificate cleanup failed' }
        }
    }
    if (Test-Path $directory) { Remove-Item $directory -Recurse -Force }
}
