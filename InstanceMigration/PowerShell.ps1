Clear-Host;
$GalaxyServer = 'SqlPractice';
$DestinationInstance = $InventoryInstance
Import-Module SqlServer -DisableNameChecking -Scope Global;
$sqlInst = "SQLSERVER:\SQL\$GalaxyServer\DEFAULT";

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.ii) Agent Category
        Script out Job Categories 
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.ii) Agent Category\AddCategory_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$jobCategories = Get-ChildItem "$sqlInst\JobServer\JobCategories";
#$jobCategories | GM
foreach ($c in $jobCategories)
{
    Write-Host "Scripting Job Category $($c.Name)";
    $c.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
}

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.iii) Agent Jobs
        Script out Jobs
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.iii) Agent Jobs\1. AgentJobs_WithoutReplication&Checksum_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$skipJobs = @('Temp – Shell programs delete'
,'DBA Rebuild Galaxy0 FTCs'
,'DBA Checksumdb load'
,'DBA Update Stats live db');

$skipJobs;

$Jobs = Get-ChildItem "$sqlInst\JobServer\Jobs";
#$jobCategories | GM
foreach ($i in $Jobs)
{
    Write-Host "Job Name = $($i.Name)"
    if ($i.Category -like "*Repl*") {
        Write-Host "   Skipping due to Replication Category"  -ForegroundColor DarkYello;
    }
    if ($i.Name -like "*checksum*") {
        Write-Host "   Skipping due to Checksum job" -ForegroundColor DarkYello;
    }
    if ($skipJobs -contains $i.Name) 
    {
        Write-Host "   Marked for skipping by application team" -ForegroundColor DarkYello;
    }
  
    if ($skipJobs -notcontains $i.Name -and $i.Category -notlike "*Repl*" -and $i.Name -notlike "*checksum*") 
    {
        Write-Host "Scripting Job Category $($i.Name)" -ForegroundColor DarkGreen;
        $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    }
    
}
notepad.exe $outputPath;

# ---------------------------------------------
<# 1.a.iii) Agent Jobs
        -- Disable
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.iii) Agent Jobs\2. AgentJobs_WithoutReplication&Checksum_Disable_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

foreach ($i in $Jobs)
{
    Write-Host "Job Name = $($i.Name)"
    if ($i.Category -like "*Repl*") {
        Write-Host "   Skipping due to Replication Category"  -ForegroundColor DarkYello;
    }
    if ($i.Name -like "*checksum*") {
        Write-Host "   Skipping due to Checksum job" -ForegroundColor DarkYello;
    }
    if ($skipJobs -contains $i.Name) 
    {
        Write-Host "   Marked for skipping by application team" -ForegroundColor DarkYello;
    }
  
    if ($skipJobs -notcontains $i.Name -and $i.Category -notlike "*Repl*" -and $i.Name -notlike "*checksum*") 
    {
       Write-Host "Scripting Tsql code to disable job: $($i.Name)" -ForegroundColor DarkGreen;
        @"
EXEC msdb.dbo.sp_update_job @job_name='$($i.Name)',@enabled = 0
GO
"@ | Out-File -FilePath $outputPath -Append;
    }
    
}
notepad.exe $outputPath;

# ----------------------------------------------------
<# 1.a.iii) Agent Jobs
        -- Enable
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.iii) Agent Jobs\3. AgentJobs_Enable_WithoutReplication&Checksum_Script.sql";
#$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.iii) Agent Jobs\3. AgentJobs_Enable_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

foreach ($i in ($Jobs | Where-Object {$_.IsEnabled -eq $true}))
{
    if ($skipJobs -notcontains $i.Name  -and $i.Category -notlike "*Repl*" -and $i.Name -notlike "*checksum*") 
    {
        Write-Host "Scripting Tsql code to disable job: $($i.Name)" -ForegroundColor DarkGreen;
        @"
EXEC msdb.dbo.sp_update_job @job_name='$($i.Name)',@enabled = 1
GO
"@ | Out-File -FilePath $outputPath -Append;
    }
    else {
        Write-Host "Skipping Job $($i.Name)" -ForegroundColor DarkYellow;
    }
}
notepad.exe $outputPath;

$Jobs | Where-Object {$_.IsEnabled -eq $false} | Select-Object Name, Category, IsEnabled | Export-Clixml -Path 'F:\SQLDBATools\Galaxy Migration\1.a.iii) Agent Jobs\DisabledJobs.xml'
Import-Clixml -Path 'F:\SQLDBATools\Galaxy Migration\1.a.iii) Agent Jobs\DisabledJobs.xml' | ft -AutoSize
# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.iv) Agent Operators
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.iv) Agent Operators\CreateOperators_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Operators = Get-ChildItem "$sqlInst\JobServer\Operators";
#$jobCategories | GM
foreach ($i in $Operators)
{    
        Write-Host "Scripting Operator $($i.Name)" -ForegroundColor DarkGreen;
        $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.iv) Agent Credentials
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.ix) Credentials\Create_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Collection = Get-ChildItem $sqlInst\Credentials;
foreach ($i in $Collection)
{    
        Write-Host "Scripting Cred $($i.Name)" -ForegroundColor DarkGreen;
        $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.v) Agent Proxy Accounts
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.v) Agent Proxy Accounts\Create_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Collection = Get-ChildItem $sqlInst\JobServer\ProxyAccounts;
foreach ($i in $Collection)
{    
        Write-Host "Scripting Proxy Account $($i.Name)" -ForegroundColor DarkGreen;
        $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.vi) Agent Shared Schedules
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.vi) Agent Shared Schedules\Create_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Collection = Get-ChildItem $sqlInst\JobServer\SharedSchedules;
foreach ($i in $Collection)
{    
        Write-Host "Scripting Schedule $($i.Name) with ID = $($i.ID)" -ForegroundColor DarkGreen;
        $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.vii) Backup Devices
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.vii) Backup Devices\Create_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Collection = Get-ChildItem $sqlInst\BackupDevices;
foreach ($i in $Collection)
{    
        Write-Host "Scripting backup device $($i.Name) " -ForegroundColor DarkGreen;
        $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;
# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.viii) Central Management Server
https://dba.stackexchange.com/questions/151533/list-the-cms-sql-server-instances-using-powershell/151716
#>

# Nothing here

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.x) Custom Errors
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.x) Custom Errors\AddMessages_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$sqlQuery = @"
SELECT 'EXEC master.sys.sp_addmessage @msgnum = ' + CAST(message_id AS VARCHAR(10)) + ', @severity = '
       + CAST(m.severity AS VARCHAR(10)) + ', @msgtext = ''' + m.text + '''' + ', @lang = ''' + s.name + ''''
       + ', @with_log = ''' + CASE
                                  WHEN m.is_event_logged = 1 THEN
                                      'True'
                                  ELSE
                                      'False'
                              END + '''' as AddScript
FROM sys.messages AS m
    INNER JOIN sys.syslanguages AS s
        ON m.language_id = s.lcid
WHERE m.message_id > 49999;
"@;

$Collection = Invoke-Sqlcmd -ServerInstance $GalaxyServer -Query $sqlQuery;
foreach ($i in $Collection)
{    
        $i.AddScript | Out-File -FilePath $outputPath -Append;
        
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xi) Database Mail
#>
$Collection_Accounts =  Get-ChildItem $sqlInst\Mail\Accounts;
$Collection_Accounts | gm
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.xi) Database Mail\1. MailAccounts_Script.sql";
foreach ($i in $Collection_Accounts)
{
    Write-Host "Scripting Account $($i.Name)..";
    $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;    
}
notepad.exe $outputPath;

$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.xi) Database Mail\2. Profiles_Script.sql";
$Collection_Profiles =  Get-ChildItem $sqlInst\Mail\Profiles;
foreach ($i in $Collection_Profiles)
{    
    Write-Host "Scripting Mail profile $($i.Name)..";
    $i.Script() | Out-File -FilePath $outputPath -Append;    
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;    
}
notepad.exe $outputPath;

$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.xi) Database Mail\3. ConfigurationValues_Script.sql";
$Collection_ConfigurationValues =  Get-ChildItem $sqlInst\Mail\ConfigurationValues;
foreach ($i in $Collection_ConfigurationValues)
{    
    Write-Host "Scripting Configuration $($i.Name)..";
    $i.Script() | Out-File -FilePath $outputPath -Append;    
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xii) Endpoints
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.xii) Endpoints\Create_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Collection = Get-ChildItem $sqlInst\Endpoints;
foreach ($i in $Collection)
{    
    $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xiv) Linked Servers
#>
# https://dbatools.io/functions/copy-dbalinkedserver/
Import-Module dbatools -DisableNameChecking;
Copy-DbaLinkedServer -Source $GalaxyServer -Destination $DestinationInstance;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xv) Logins
#>
# https://dbatools.io/functions/copy-dbalinkedserver/
Import-Module dbatools -DisableNameChecking;
Export-DbaLogin -SqlServer $GalaxyServer -FilePath "F:\SQLDBATools\Galaxy Migration\1.a.xv) Logins\$GalaxyServer-logins.sql";


# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xvii) Resource Governor
#>
#https://dbatools.io/functions/copy-dbaresourcegovernor/
Copy-DbaResourceGovernor -Source $GalaxyServer -Destination $DestinationInstance;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xviii) Server Triggers
#>
#https://dbatools.io/functions/copy-dbaservertrigger/
Copy-DbaServerTrigger -Source $GalaxyServer -Destination $DestinationInstance;

# or

$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.xviii) Server Triggers\Create_Script.sql";
$dropCreate = $false;
$pass = $false;
if([System.IO.File]::Exists($outputPath)) {
    Write-Host "File already exists. Pls check" -ForegroundColor DarkRed -BackgroundColor Yellow;
    if ($pass -eq $false) {
        return;
    }

    if ($dropCreate) {
        Remove-Item $outputPath;
    }
}

$Collection = Get-ChildItem $sqlInst\Triggers;
foreach ($i in $Collection)
{    
    $i.Script() | Out-File -FilePath $outputPath -Append;
    @"
GO
"@ | Out-File -FilePath $outputPath -Append;
    
}
notepad.exe $outputPath;

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xix) spConfigure
#>
$outputPath = "F:\SQLDBATools\Galaxy Migration\1.a.xix) spConfigure\Create_Script.sql";
Export-DbaSpConfigure $GalaxyServer "$outputPath";

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xx) spDataCollector
#>
# https://dbatools.io/functions/copy-dbasqldatacollector/
Copy-DbaSqlDataCollector -Source $GalaxyServer -Destination $DestinationInstance

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xxi) spPolicyManagement
#>
# https://dbatools.io/functions/copy-dbasqlpolicymanagement/
Copy-DbaSqlPolicyManagement -Source $GalaxyServer -Destination $DestinationInstance

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xxiii) SSIS Catalog
#>
# https://dbatools.io/functions/copy-dbassiscatalog/
Copy-DbaSsisCatalog -Source $GalaxyServer -Destination $DestinationInstance

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xxiv) sysDBUserObject
#>
# https://dbatools.io/functions/copy-dbasysdbuserobjects/
Copy-DbaSysDbUserObject -Source $GalaxyServer -Destination $DestinationInstance

# ------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------
<# 1.a.xxv) system database properties
#>

Get-ChildItem $sqlInst\databases