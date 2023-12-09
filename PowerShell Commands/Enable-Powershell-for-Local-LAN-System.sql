https://stackoverflow.com/questions/14952833/get-wmiobject-win32-process-computername-gets-error-access-denied-code-0x8
	-- https://stackoverflow.com/a/14953535/4449743
	-- https://stackoverflow.com/a/11338395/4449743
	-- https://stackoverflow.com/questions/21548566/how-to-add-more-than-one-machine-to-the-trusted-hosts-list-using-winrm
Launch "wmimgmt.msc"
Right-click on "WMI Control (Local)" then select Properties
Go to the "Security" tab and select "Security" then "Advanced" then "Add"
Select the user name(s) or group(s) you want to grant access to the WMI and click ok
Grant the required permissions, I recommend starting off by granting all permissions to ensure that access is given, then remove permissions later as necessary.
Ensure the "Apply to" option is set to "This namespace and subnamespaces"
Save and exit all prompts
Add the user(s) or group(s) to the Local "Distributed COM Users" group. Note: The "Authenticated Users" and "Everyone" groups cannot be added here, so you can alternatively use the "Domain Users" group.

netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes

--	=======================================================================================
#Install-Module CredentialManager -Force;
#Get-Command -Module CredentialManager
$computerName = 'msi';

Get-Credential -UserName "$computerName\Ajay" -Message "Password please" | New-StoredCredential -Target $computerName -Persist LocalMachine
$creds = Get-StoredCredential -Target $computerName;

Get-VolumeInfo -ComputerName $computerName
Get-DbaDiskSpace -ComputerName $computerName -Credential $creds

--	=======================================================================================
Enter-PSSession : Connecting to remote server msi failed with the following error message : WinRM 
cannot process the request. The following error with errorcode 0x80090311 occurred while using 
Kerberos authentication: We can't sign you in with this credential because your domain isn't 
available. Make sure your device is connected to your organization's network and try again. If you 
previously signed in on this device with another credential, you can sign in with that credential.  
 Possible causes are:
  -The user name or password specified are invalid.
  -Kerberos is used when no authentication method and no user name are specified.
  -Kerberos accepts domain user names, but not local user names.
  -The Service Principal Name (SPN) for the remote computer name and port does not exist.
  -The client and remote computers are in different domains and there is no trust between the two 
domains.
 After checking for the above issues, try the following:
  -Check the Event Viewer for events related to authentication.
  -Change the authentication method; add the destination computer to the WinRM TrustedHosts 
configuration setting or use HTTPS transport.
 Note that computers in the TrustedHosts list might not be authenticated.
   -For more information about WinRM configuration, run the following command: winrm help config. 
For more information, see the about_Remote_Troubleshooting Help topic.
At line:1 char:1
+ Enter-PSSession -ComputerName msi -Credential (Get-StoredCredentials  ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (msi:String) [Enter-PSSession], PSRemotingTransportEx 
   ception
    + FullyQualifiedErrorId : CreateRemoteRunspaceFailed

