## Create new certificate
Creates a Self-Signed Certificate for use in server to server authentication. 
## About script:
Script will generate certificate, which add can be installed in local computer certificate store (personal folder). Also, will export certificate to run folder by saving them as *.pfx and .cer.

## How-to:
Just run with **administrator privilege** the `Create-SelfSignedCertificate.ps1`. 

## Create-SelfSignedCertificate.ps1 parameters:
`-CommonName` - Certificate name.

`-StartDate` - Date from when the certificate is valid *(yyyy-mm-dd, default today)*.

`-EndDate` - Date until when the certificate is valid *(yyyy-mm-dd, default today +1 year)*.

`-Password` - Certificate password.

`-RemoveCert` - Remove the certificate from your compute *(default: no)*?

`-Overwrite` - Overwrite the certificate *(default: yes)*?