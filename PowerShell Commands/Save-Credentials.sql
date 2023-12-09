# Generate a random AES Encryption Key.
$AESKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey);

# File Path for Credentials & Key
$SQLDBATools = Get-Module -ListAvailable -Name SQLDBATools | Select-Object -ExpandProperty ModuleBase;
$AESKeyFilePath = "$SQLDBATools\SQLDBATools_AESKey.key";
$credentialFilePath = "$SQLDBATools\SQLDBATools_Credentials.xml";
	
# Store the AESKey into a file. This file should be protected!  (e.g. ACL on the file to allow only select people to read)
Set-Content $AESKeyFilePath $AESKey   # Any existing AES Key file will be overwritten		

# Hide Key file on Disk
(get-item $AESKeyFilePath -Force).Attributes += 'Hidden';
(get-item $AESKeyFilePath -Force).Attributes += 'System';
(get-item $AESKeyFilePath -Force).Attributes += 'ReadOnly';

# Accounts to Save
$Accounts = @("contso\DevSQL","contso\ProdSQL","contso\SQLDBATools","SA");
[System.Collections.ArrayList]$Credentials = @();
foreach($username in $Accounts) {
    $password = Read-Host "Enter password for '$username': " -AsSecureString;
    $encryptedPwd = $password | ConvertFrom-SecureString -Key $AESKey;
    $obj = [PSCustomObject]@{ UserName=$username; Password=$encryptedPwd; }
    $Credentials.Add($obj)|Out-Null;
}
$Credentials | Export-Clixml -Path $credentialFilePath;

# Hide Password file on Disk
(get-item $credentialFilePath -Force).Attributes += 'Hidden';
(get-item $credentialFilePath -Force).Attributes += 'System';
(get-item $credentialFilePath -Force).Attributes += 'ReadOnly';

# Recover Password
$username = "SA"
$AESKey = Get-Content $AESKeyFilePath
$pwdTxt = (Import-Clixml $credentialFilePath | Where-Object {$_.UserName -eq $username}).Password
$securePwd = $pwdTxt | ConvertTo-SecureString -Key $AESKey

$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securePwd)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

$password
#$password = $securePwd | Show-Password # Raw Password

$credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd
