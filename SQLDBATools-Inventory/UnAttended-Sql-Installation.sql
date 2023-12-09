$ssn = New-PSSession -ComputerName $InventoryServer -Name $InventoryServer;
$ScriptBlock = {
    $env:COMPUTERNAME;
    Import-Module SQLDBATools;
    Import-Module CredentialManager;
    Import-Module CredentialManagement;
    [string]$SQLServiceAccount = ($Using:SQLServiceAccount).Split('\')[1];
    $SQLServiceAccount
    Get-StoredCredentials -Target $SQLServiceAccount;
    Get-StoredCredential -Target $SQLServiceAccount;
    <#
    $SQLServiceAccountPassword = (Get-StoredCredentials -Target $SQLServiceAccount) | Select-Object -ExpandProperty Password) | Show-Password;
    $SAPassword = ((Get-StoredCredentials -Target 'SQL_sa').Password | Show-Password);
    $Passwords = @{SQLServiceAccountPassword=$SQLServiceAccountPassword;SAPassword=$SAPassword;}
    $Passwords
    #>
}
Invoke-Command -Session $ssn -ScriptBlock $ScriptBlock





https://www.richardswinbank.net/admin/extract_linked_server_passwords 
 
Msg 8522, Level 16, State 3, Line 1
Microsoft Distributed Transaction Coordinator (MS DTC) has stopped this transaction. 
All the linked servers need to be recreated with the SQL Native Client 11 driver of they will not work 
 
SELECT TOP 1000 creativeWorkId
FROM �ReplPublisher.[DatabaseName].dbo.CreativeWork 
EXEC master.dbo.sp_addlinkedserver @server = N'ReplPublisher', @srvproduct=N'sql_server', @provider=N'SQLNCLI11', @datasrc=N'DbServerName' 
 


[enum]::GetNames("system.io.fileattributes")