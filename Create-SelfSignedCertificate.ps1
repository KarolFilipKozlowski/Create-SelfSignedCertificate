#Requires -RunAsAdministrator
<# Creates a Self Signed Certificate for use in server to server authentication #>
function CreateSelfSignedCertificate {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$CommonName,

    [Parameter(Mandatory=$true)]
    [DateTime]$StartDate,

    [Parameter(Mandatory=$true)]
    [DateTime]$EndDate,

    [Parameter(Mandatory=$true)]
    [SecureString]$Password,

    [Parameter(Mandatory=$true)]
    [bool]$RemoveCert,

    [Parameter(Mandatory=$true)]
    [bool]$Overwrite
)
    
    #Remove and existing certificates with the same common name from personal and root stores
    #Need to be very wary of this as could break something
    if($CommonName.ToLower().StartsWith("cn="))
    {
        # Remove CN from common name
        $CommonName = $CommonName.Substring(3)
    }
    $certs = Get-ChildItem -Path Cert:\LocalMachine\my | Where-Object{$_.Subject -eq "CN=$CommonName"}
    if($null -ne $certs -and $certs.Length -gt 0)
    {
        if($Overwrite)
        {
            foreach($c in $certs)
            {
                remove-item $c.PSPath
            }
        } else {
            Write-Host -ForegroundColor Red "One or more certificates with the same common name (CN=$CommonName) are already located in the local certificate store. Use -Overwrite to remove them";
            return $false
        }
    }

    $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=$CommonName", 0)

    $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $key.KeySpec = 1
    $key.Length = 2048
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $key.MachineContext = 1
    $key.ExportPolicy = 1 # This is required to allow the private key to be exported
    $key.Create()

    $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1") # Server Authentication
    $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
    $ekuoids.add($serverauthoid)
    $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = $StartDate
    $cert.NotAfter = $EndDate
    $cert.X509Extensions.Add($ekuext)
    $cert.Encode()

    $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")
    
    if($CommonName.ToLower().StartsWith("cn="))
    {
        # Remove CN from common name
        $CommonName = $CommonName.Substring(3)
    }
    $cert = Get-ChildItem -Path Cert:\LocalMachine\my | where-object{$_.Subject -eq "CN=$CommonName"}

    $_ExportPfxCertificate = Export-PfxCertificate -Cert $cert -Password $Password -FilePath "$($CommonName).pfx"
    $_ExportCertificate = Export-Certificate -Cert $cert -Type CERT -FilePath "$CommonName.cer"

    Write-Host "Certificates: " -ForegroundColor Green
    Write-Host "- $($CommonName).pfx" -ForegroundColor Green
    Write-Host "- $($CommonName).cer" -ForegroundColor Green
    Write-Host "expoted to the $($PSScriptRoot) folder." -ForegroundColor Green

    if($RemoveCert)
    {
        # Once the certificates have been been exported we can safely remove them from the store
        if($CommonName.ToLower().StartsWith("cn="))
        {
            # Remove CN from common name
            $CommonName = $CommonName.Substring(3)
        }
        $certs = Get-ChildItem -Path Cert:\LocalMachine\my | Where-Object{$_.Subject -eq "CN=$CommonName"}
        foreach($c in $certs)
        {
            remove-item $c.PSPath
        }
    }
}

$date = Get-Date
# -CommonName
$CommonName = $Null
While (($Null -eq $CommonName) -or ($CommonName.Length -lt 6)) {
    $CommonName = Read-Host -Prompt "Enter common name for certificate (min. 5 chars)"
}
# -StartDate
$defaultStartDate = $date.ToString("yyyy-MM-dd")
Write-Host "Press enter to accept the default start date - " -NoNewline
Write-Host "$($defaultStartDate)" -ForegroundColor Yellow -NoNewline
Write-Host " or enter custom date: " -NoNewline
$StartDate = Read-Host
$StartDate = ($defaultStartDate, $StartDate)[[bool]$tStartDate]
# -EndDate
$defaultEndDate = $date.AddYears(2).ToString("yyyy-MM-dd")
Write-Host "Press enter to accept the default end date - " -NoNewline
Write-Host "$($defaultEndDate)" -ForegroundColor Yellow -NoNewline
Write-Host " or enter custom date: " -NoNewline
$EndDate = Read-Host
$EndDate = ($defaultEndDate, $EndDate)[[bool]$EndDate]
# -Password
[SecureString]$Password = $Null
While (($Null -eq $Password) -or ($Password.Length -lt 6)) {
    $Password = Read-Host -Prompt "Enter password to protect private key for certificate (min. 5 chars)" -AsSecureString
}
# -RemoveCert
[bool]$RemoveCert = $false
$defaultRemoveCert = $Null
While (($Null -eq $defaultRemoveCert) -and (($defaultRemoveCert -ne "Y") -or ($defaultRemoveCert -ne "N"))) {
    Write-Host "Remove certificate from computer? " -NoNewline
    Write-Host "Y for Yes" -ForegroundColor Yellow -NoNewline
    Write-Host " or " -NoNewline
    Write-Host "N for No (default)" -ForegroundColor Yellow -NoNewline
    Write-Host ": " -NoNewline
    $defaultRemoveCert = Read-Host
    $defaultRemoveCert = ("N", $defaultRemoveCert)[[bool]$defaultRemoveCert]
}
if($defaultRemoveCert -eq "Y")
{
    $RemoveCert = $true
}
# -Overwrite
[bool]$Overwrite = $true
$defaultOverwrite = $Null
While (($Null -eq $defaultOverwrite) -and (($defaultOverwrite -ne "Y") -or ($defaultOverwrite -ne "N"))) {
    Write-Host "Overwrite existing certificates? " -NoNewline
    Write-Host "Y for Yes (default)" -ForegroundColor Yellow -NoNewline
    Write-Host " or " -NoNewline
    Write-Host "N for No" -ForegroundColor Yellow -NoNewline
    Write-Host ": " -NoNewline
    $defaultOverwrite = Read-Host
    $defaultOverwrite = ("N", $defaultOverwrite)[[bool]$defaultOverwrite]
}
if($defaultForce -eq "N")
{
    $Overwrite = $false
}
<# RUN #>
CreateSelfSignedCertificate -CommonName $CommonName -StartDate $StartDate -EndDate $EndDate -Password $Password -RemoveCert $RemoveCert -Overwrite $Overwrite