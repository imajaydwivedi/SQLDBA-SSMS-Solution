https://adamtheautomator.com/powershell-modules/

-- 1) Open SQL Server Management Studio and Connect to Server from PowerShell
ssms.exe <scriptfile> -S $serverName -E

-- 2) Add datetime in FileName
Write-Host "fileName_$(Get-Date -Format ddMMMyyyyTHHmm).sql";
Write-Host "fileName_$(Get-Date -Format yyyyMMdd_HHmm).sql";
Write-Host "fileName_$(Get-Date -Format 'yyyy-MM-dd HH.mm.ss').sql";

-- 3) Unattended script execution
	https://dba.stackexchange.com/questions/197360/how-to-execute-sql-server-query-in-ssms-using-powershell
sqlcmd -Q 'E:\PowerShell_PROD\Screenshot\ServerDetails.sql' -E -S localhost

-- 4) Get file name
"F:\MSSQL15.MSSQLSERVER\Data\UserTracking_data.mdf" -match "^(?'PathPhysicalName'.*[\\\/])(?'BasePhysicalName'.+)"
$Matches['BasePhysicalName'] => UserTracking_data.mdf
$Matches['PathPhysicalName'] => F:\MSSQL15.MSSQLSERVER\Data\

-- 5) Is Null or Empty
[string]::IsNullOrEmpty($StopAt_Time) -eq $false

-- 6) Create a PS Drive for Demo Purposes
New-PSDrive -Persist -Name "P" -PSProvider "FileSystem" -Root "\\MyDbServerName\g$"

-- 7) Add color to Foreground and Background text
write-host "[OK]" -ForegroundColor Cyan

-- 7) File exists or not
[System.IO.File]::Exists($n)

-- 8) Get all files on drive by Size
Get-ChildItem -Path 'F:\' -Recurse -Force -ErrorAction SilentlyContinue | 
    Select-Object Name, @{l='ParentPath';e={$_.DirectoryName}}, @{l='SizeBytes';e={$_.Length}}, @{l='Owner';e={((Get-ACL $_.FullName).Owner)}}, CreationTime, LastAccessTime, LastWriteTime, @{l='IsFolder';e={if($_.PSIsContainer) {1} else {0}}}, @{l='SizeMB';e={$_.Length/1mb}}, @{l='SizeGB';e={$_.Length/1gb}} |
    Sort-Object -Property SizeBytes -Descending | Out-GridView

-- 9) Check if -Verbose switch is used. Fixed width display with Write-Host
$verbose = $false;
if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters.Verbose.Equals($true)) { # Command line specifies -Verbose[:$false]
    $verbose = $PSBoundParameters.Get_Item('Verbose')
}

if($Verbose) {
    Write-Host ("{0,-8} {1} - {2}" -f 'INFO:', "$(Get-Date)", "Extract 'Finding' & 'Create TSQL' from Index Summary to match with Non-Prod");
    $startTime = Get-Date
    "{0} {1,-10} {2}" -f "($($startTime.ToString('yyyy-MM-dd HH:mm:ss')))","(START)","Launch setup.exe to upgrade [TestServer\SQLEXPRESS] SqlInstance.." | Write-Host -ForegroundColor Yellow

    "{0} {1,-10} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(START)","Launch setup.exe to upgrade [TestServer\SQLEXPRESS] SqlInstance.." | Write-Host -ForegroundColor Yellow
}

-- 10) Check if Module is installed
if (Get-Module -ListAvailable -Name SqlServer) {
    Write-Host "Module exists"
} else {
    Write-Host "Module does not exist"
}    

-- 11) Find path of SQLDBATools Module
(Get-Module -ListAvailable SQLDBATools).Path

-- 12) Log entry into ErrorLogs table
$MessageText = "Get-WmiObject : Access is denied. Failed in execution of Get-ServerInfo";
Write-Host $MessageText -ForegroundColor Red;
Add-CollectionError -ComputerName $ComputerName -Cmdlet 'Add-ServerInfo' -CommandText "Add-ServerInfo -ComputerName '$ComputerName'" -ErrorText $MessageText -Remark $null;
return;

-- 13) Querying using SQLProvider
$computerName = 'MyDbServerName'

Get-ChildItem SQLSERVER:\SQL\$computerName\DEFAULT
$sqlInstance = Get-Item SQLSERVER:\SQL\$computerName\DEFAULT
$sqlInstance | gm -MemberType Property

$sqlInstance | select ComputerNamePhysicalNetBIOS, Name, Edition, ErrorLogPath, IsCaseSensitive, IsClustered,
                            IsHadrEnabled, IsFullTextInstalled, LoginMode, NetName, PhysicalMemory,
                            Processors, ServiceInstanceId, ServiceName, ServiceStartMode, 
                            VersionString, Version, DatabaseEngineEdition

$sqlInstance.Information | Select-Object * | fl
$sqlInstance.Properties | Select-Object Name, Value | ft -AutoSize
$sqlInstance.Configuration

-- 14) Querying SqlServer using PowerShell
$computerName = 'MyDbServerName'

<# SMO #> 
$server = New-Object Microsoft.SqlServer.Management.Smo.Server("$computerName")
$server | Select-Object ComputerNamePhysicalNetBIOS, Name, Edition, ErrorLogPath, IsCaseSensitive, IsClustered,
                            IsHadrEnabled, IsFullTextInstalled, LoginMode, NetName, PhysicalMemory,
                            Processors, ServiceInstanceId, ServiceName, ServiceStartMode, 
                            VersionString, Version, DatabaseEngineEdition

$server.Configuration.MaxServerMemory
$server.Configuration.CostThresholdForParallelism
$server.Configuration.MinServerMemory
$server.Configuration.MaxDegreeOfParallelism
$server.Configuration.Properties | ft -AutoSize -Wrap
                            
<# SQL Provider #> 
Get-ChildItem SQLSERVER:\SQL\$computerName\DEFAULT
$sqlInstance = Get-Item SQLSERVER:\SQL\$computerName\DEFAULT
$sqlInstance.Databases['DBA'].Schemas
$sqlInstance.Databases['DBA'].Tables | Select-Object Schema, Name, RowCount
Get-ChildItem SQLSERVER:\SQL\$computerName\DEFAULT\Databases\DBA\Tables | Select-Object Schema, Name, RowCount;
(Get-Item SQLSERVER:\SQL\$computerName\DEFAULT\Databases\DBA\Tables).Collection | Select-Object Schema, Name, RowCount;

$sqlInstance | gm -MemberType Property

$sqlInstance | select ComputerNamePhysicalNetBIOS, Name, Edition, ErrorLogPath, IsCaseSensitive, IsClustered,
                            IsHadrEnabled, IsFullTextInstalled, LoginMode, NetName, PhysicalMemory,
                            Processors, ServiceInstanceId, ServiceName, ServiceStartMode, 
                            VersionString, Version, DatabaseEngineEdition

$sqlInstance.Information | Select-Object * | fl
$sqlInstance.Properties | Select-Object Name, Value | ft -AutoSize
$sqlInstance.Configuration 

-- 15) Set Mail profile
# Set computerName
$computerName = 'MyDbServerName'

$srv = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Server("$computerName");
$sm = $srv.Mail.Profiles | Where-Object {$_.Name -eq $computerName};
$srv.JobServer.AgentMailType = 'DatabaseMail';
$srv.JobServer.DatabaseMailProfile = $sm.Name;
$srv.JobServer.Alter();

--	16) CollectionTime
@{l='CollectionTime';e={(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")}}
@{l='CollectionTime';e={(Get-Date).ToString("yyyy-MM-dd HH.mm.ss")}}

-- 17) Out-GridView
Get-Process|Where {$_.cpu -ne $null}|ForEach {New-Object -TypeName psObject -Property @{name=$_.Name;cpu=[double]$_.cpu}}|Out-GridView

-- 18) Move *.sql Files & Folder from Source to Destination
$sServer = 'SrvSource';
$tServer = 'SrvDestination';

$basePath = 'f$\mssqldata'

# Find source folders
$folders = Get-ChildItem "\\$sServer\$basePath" -Recurse | Where-Object {$_.PsIsContainer};

# Create same folders on destination
foreach($fldr in $folders)
{
    $newPath = $fldr.FullName -replace "\\\\$sServer\\", "\\\\$tServer\\";
    $exists = ([System.IO.Directory]::Exists($newPath));

    if($exists) {
        Write-Host "Exists=> $newPath" -ForegroundColor Green;
    } else {
        Write-Host "NotExists=> $newPath" -ForegroundColor Yellow;
        #[System.IO.Directory]::CreateDirectory($newPath);
    }
    #$fldr.FullName -replace "\\\\$sServer\\", "\\\\$tServer\\"
}

# Find source folders
$sqlfiles = Get-ChildItem "\\$sServer\$basePath" -Recurse | Where-Object {$_.PsIsContainer -eq $false} | 
                Where-Object {$_.Extension -eq '.sql' -or $_.Extension -eq '.bat'};

# Create same folders on destination
foreach($file in $sqlfiles)
{
    $newPath = $file.FullName -replace "\\\\$sServer\\", "\\\\$tServer\\";
    $exists = ([System.IO.File]::Exists($newPath));

    if($exists) {
        Write-Host "Exists=> $newPath" -ForegroundColor Green;
    } else {
        Write-Host "NotExists=> $newPath" -ForegroundColor Yellow;
        #Copy-Item "$($file.FullName)" -Destination "$newPath"
    }
}

-- 16) Get Inventory Servers on Excel
Import-Module SQLDBATools -DisableNameChecking;

# Fetch ServerInstances from Inventory
$tsqlInventory = @"
select * from Info.Server
"@;

$Servers = (Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query $tsqlInventory | Select-Object -ExpandProperty ServerName);
$SqlInstance = @();


foreach($server in $Servers)
{
    $r = Fetch-ServerInfo -ComputerName $server;
    $SqlInstance += $r;
}

$SqlInstance | Export-Excel 'C:\temp\contsoSQLServerInventory.xlsx'


-- 17) Group-Object & Measure-Object
$PathOrFolder = 'E:\'
$files = Get-ChildItem -Path $PathOrFolder -Recurse -File | ForEach-Object {
                $Parent = (Split-Path -path $_.FullName);
                New-Object psobject -Property @{
                   Name = $_.Name;
                   FullName = $_.FullName;
                   Parent = $Parent;
                   SizeBytes = $_.Length;
                }
            }

$FolderWithSize = $files | Group-Object Parent | %{
            New-Object psobject -Property @{
                                            Parent = $_.Name
                                            Sum = ($_.Group | Measure-Object SizeBytes -Sum).Sum
                                           }
        }

--	18) 
<# Script to Find databases which are not backed up in Last 7 Days
#>

$Server2Analyze = 'testvm';
$DateSince = (Get-Date).AddDays(-7) # Last 7 days

# Find Latest Bacukps
$Backups = Get-DbaBackupHistory -SqlInstance $Server2Analyze -Type Full -Since $DateSince #'5/5/2018 00:00:00'

$BackedDbs = $Backups | Select-Object -ExpandProperty Database -Unique

# List of available dbs
$dbs = Invoke-Sqlcmd -ServerInstance $Server2Analyze -Database master -Query "select name from sys.databases" | select -ExpandProperty name;

$NotBackedDbs = @();
foreach($db in $dbs)
{
    if($BackedDbs -contains $db){
        Write-Host "$db is +nt";
    }
    else {
        $NotBackedDbs += $db;
    }
}

Write-Host "Returing Dbs for which backup is not there.." -ForegroundColor Green;
$NotBackedDbs | Add-Member -NotePropertyName ServerName -NotePropertyValue $Server2Analyze -PassThru -Force | 
    Out-GridView -Title "Not Backed Dbs"

#Remove-Variable -Name NotBackedDbs

--	19) Import Remove Server Module
$session = New-PSSession -computerName MyDbServerName;
Invoke-Command -scriptblock { Import-Module dbatools } -session $session;
Import-PSSession -module dbatools -session $session;

--	20) Remove Files Older than 2 Days
DECLARE @result int;
DECLARE @_errorMSG VARCHAR(500);  

EXEC @result = xp_cmdshell 'PowerShell.exe -noprofile -command "Get-ChildItem $path -Recurse | Select-Object FullName, LastAccessTime, PSIsContainer | Where-Object {$_.PSIsContainer -eq $false -and $_.LastAccessTime -lt (Get-Date).AddDays(-2) } #| Remove-Item"' ,no_output;  

IF (@result = 0) 
BEGIN 
	PRINT 'PowerShell script successfully executed.';	
END
ELSE
BEGIN
	SET @_errorMSG = 'PowerShell script execution has failed.';
	IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
		EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
	ELSE
		EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
END

--	21) Check if in Elevated Mode
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

--	22) Kill Robocopy
taskkill /F /IM robocopy.exe

--	23) Make DoubleHop Remoting
$Server = 'RemoteServer'

# Define Credentials
[string]$userName = 'Contso\SQLServices'
[string]$userPassword = 'SomeStrongPassword'

# Crete credential Object
[SecureString]$secureString = $userPassword | ConvertTo-SecureString -AsPlainText -Force;
[PSCredential]$credentialObject = New-Object System.Management.Automation.PSCredential -ArgumentList $userName, $secureString;

# Create PSSessionConfig
Invoke-Command -ComputerName $Server -ScriptBlock { Register-PSSessionConfiguration -Name SQLDBATools -RunAsCredential $Using:credentialObject -Force -WarningAction Ignore}

$scriptBlock = {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);
    Copy-Item '\\ftpServerName\it\SQL_Server_Setups\2014\Developer' -Destination E:\ -Recurse;
}

Invoke-Command -ComputerName $Server -ScriptBlock $scriptBlock -ConfigurationName SQLDBATools;

--	24) Get Called Function 
$MyInvocation.PSCommandPath
GCI $MyInvocation.PSCommandPath | Select -Expand Name

--	25) Powershell CallStack
$callstack = Get-PSCallStack;
if($callstack[1].FunctionName -eq '<ScriptBlock>') {
    $snowed = Read-Host "Have you got service now ticket? Y/N";
    $backed = Read-Host "Have you backed up databases? Y/N";

    if($snowed -ne 'Y' -or $backed -ne 'Y') {
        Write-Output "Kindly make sure you have a ServiceNow ticket for uninstall.";
        Write-Output "Kindly make sure you have taken a full backup of the databases before uninstalling."
        return;
    }
}

--	26) Generate Temp File
 [System.IO.Path]::GetTempFileName();
 [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), 'xlsx')

--	27) Override toString() method of psobject
$BackupSizeBytes = $backup.BackupSize;
        $BackupSize = [PSCustomObject]@{
                            Bytes = $BackupSizeBytes;
                            KiloBytes = [math]::round($BackupSizeBytes / 1Kb,2);
                            MegaByte = [math]::round($BackupSizeBytes / 1Mb,2);
                            GigaByte = [math]::round($BackupSizeBytes / 1Gb,2);
                            TeraByte = [math]::round($BackupSizeBytes / 1Tb,2);
                        }
        
        $MethodBlock = {    if($this.TeraByte -ge 1) {
                                "$($this.TeraByte) tb"
                            }elseif ($this.GigaByte -ge 1) {
                                "$($this.GigaByte) gb"
                            }elseif ($this.MegaByte -ge 1) {
                                "$($this.MegaByte) mb"
                            }elseif ($this.KiloBytes -ge 1) {
                                "$($this.KiloBytes) kb"
                            }else {
                                "$($this.Bytes) bytes"
                            }
                        }
        $BackupSize | Add-Member -MemberType ScriptMethod -Name tostring -Value $MethodBlock -Force;


-- 28) https://stackoverflow.com/questions/49702843/powershell-group-object-psobject-with-multiple-properties
	-- https://stackoverflow.com/a/49704328/4449743
$list | Group-Object -Property BakId, Lsn, Name | 
 Select-Object @{n='BakId'; e={ $_.Values[0] }}, 
                @{n='Lsn';   e={ $_.Values[1] }},
                @{n='Name';  e={ $_.Values[2] }},
                @{n='Files'; e={ $_.Group | Select-Object File, Size }}


-- 29) Using the -F format Operator
https://social.technet.microsoft.com/wiki/contents/articles/7855.powershell-using-the-f-format-operator.aspx
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Creating Log file '$LogFile'.." | Tee-Object -FilePath $LogFile -Append | Write-Host -ForegroundColor Green
<#
$cmd = "-noexit -command `"Get-Content -Path '$LogFile' -Wait`""
start-process powershell -ArgumentList $cmd
#>


-- 30) Using Robocopy to Copy Entire Directories
robocopy "I:\Study Materials" "F:\AjayDwivedi-SQL-Server" /z /e /mt 4 /it *.*

-- 31) Import latest module version
$dbatools_latestversion = ((Get-Module dbatools -ListAvailable | Sort-Object Version -Descending | select -First 1).Version);
Import-Module dbatools -RequiredVersion $dbatools_latestversion;

-- 32) How to pass a Function to a scriptblock
	--	https://social.technet.microsoft.com/Forums/ie/en-US/485df2df-1577-4770-9db9-a9c5627dd04a/how-to-pass-a-function-to-a-scriptblock
$code = @"
Function Foo
{
$(Get-Command Foo | Select -expand Definition)
}
"@

$MyScriptblock =
{
Param ( $FunctionCode )

. Invoke-Expression $FunctionCode
#Lots of code and stuff...

#Run the Function Foo:
Foo

#More code
}

Invoke-Command -ComputerName vm01 -ScriptBlock $MyScriptblock -ArgumentList $code

-- 33) Clean up session variables without restarting Powershell Terminal
Remove-Variable * -ErrorAction SilentlyContinue; Remove-Module *; $Error.Clear()

-- 34) How to return several items from a Powershell function
https://stackoverflow.com/questions/12620375/how-to-return-several-items-from-a-powershell-function
> function test () {return @('a','c'),'b'}
> $a,$b = test

-- 35) Multiple Program Names using Invoke-DbaQuery
$con = New-DbaConnectionString -SqlInstance msi -ClientName 'Powershell - 1' -Database master
Invoke-DbaQuery -SqlInstance $con `
				-Query 'SELECT getutcdate() as time, @@servername as srv_name, SUSER_NAME() as login_name, PROGRAM_NAME() as program_name;' `
                -As DataTable


-- 35) Get Properties from Object(Result)
($resultGetReplState | Get-Member -MemberType Property | Select-Object -ExpandProperty Name) -join ', '

-- 36) Install Assembly into GAC (Register dll in gac)
# Method 01
$dllpath = 'C:\Users\Public\Documents\ProjectWork\sql2019upgrade\Microsoft.SqlServer.Replication.dll'
try {
    Add-Type -Path $dllpath
}
catch {
    $_.Exception.LoaderExceptions | % { Write-Host $_.Message -ForegroundColor Red }
}

# Method 02
$dllpath = c:\path\yourdll.dll
[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")
$publish = New-Object System.EnterpriseServices.Internal.Publish
$publish.GacInstall($dllpath)
** Restart Computer **

-- 37) Find loaded Assemblies
[System.AppDomain]::CurrentDomain.GetAssemblies() |
  Where-Object Location |
  Sort-Object -Property FullName |
  Select-Object -Property Name, Location, Version |
  Out-GridView

-- 38) Take file folder ownership
# Cmd
icacls "E:\Ajay\*" /grant "DOMAIN\SQL Services":F /T

# Powershell
icacls --% "E:\Ajay\*" /grant "DOMAIN\SQL Services":F /T

-- 39) Runing executable using PowerShell
https://social.technet.microsoft.com/wiki/contents/articles/7703.powershell-running-executables.aspx

-- 40) Running PowerShell script in SQL Server Agent Job using CmdExec Job Step Type
powershell.exe -ExecutionPolicy Bypass -Command {
    Invoke-SqlCmd -ServerInstance "servername" -Query "insert into DB.dbo.tbl values ('cat')"
}


-- 41) Create Image Using PowerShell
Add-Type -AssemblyName System.Drawing

$disks = Get-SdtVolumeInfo | Format-Table -AutoSize | Out-String

$filename = "$home\foo.png" 
$bmp = new-object System.Drawing.Bitmap 1028,250 # Image size
$font = new-object System.Drawing.Font Consolas,10 # Font size
$brushBg = [System.Drawing.Brushes]::Yellow # Image background
$brushFg = [System.Drawing.Brushes]::Black # Text Color
$graphics = [System.Drawing.Graphics]::FromImage($bmp) 
$graphics.FillRectangle($brushBg,0,0,$bmp.Width,$bmp.Height) 
$graphics.DrawString($disks,$font,$brushFg,0,0) # Relative coordinates within Image Canvas
$graphics.Dispose() 
$bmp.Save($filename) 

Invoke-Item $filename  


-- 42) Copy folder from Source to Remote Server maintaining director structure
$ssn = New-PSSession -ComputerName $($sqlServerInfo.host_name) -Credential $SqlCredential
Copy-Item $perfmonPath -Destination "C:\Perfmon" -ToSession $ssn -Recurse

-- 43) Decrypt secure string
$SqlCredential.GetNetworkCredential().password
----------------
$password = ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force

$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($password)
$result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
$result 

-- 44) Reset Domain (Fix Broken Domain) without Reboot (Only logoff)
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)

-- 45) Embed Image in Email
/*	Inline Image in Email	*/
https://stackoverflow.com/a/27305815/4449743
https://stackoverflow.com/a/41994121/4449743
https://www.sqlservercentral.com/forums/topic/how-to-imbed-an-image-into-an-email-sent-by-dbmail#post-1183987

