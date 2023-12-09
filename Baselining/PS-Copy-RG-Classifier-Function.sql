[CmdletBinding()]
Param (
# Accept Parameters
[String[]]$SqlInstance = 'dbsql1234',
[String]$Database = 'DBA',
[String]$FunctionName = "fn_classifier",
[String]$InventoryServer = 'dbinventory.contso.com'
)

# Loop each SqlInstance
foreach($srv in $SqlInstance)
{
    # Find Resource Governor Qualifier Function
    $QFName = (Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query 'select OBJECT_NAME(classifier_function_id) as name from sys.dm_resource_governor_configuration').name;
    # Validate existence of QF
    if([String]::IsNullOrEmpty($QFName)){
        Write-Warning "No Qualifier function found."
        Continue;
    }
    $FilePath = (Join-Path 'C:\Temp\' "$SqlInstance`__$FunctionName.sql")

    # Remove ScriptFile if existing
    if(Test-Path $FilePath) { Remove-Item $FilePath | Out-Null }
    $ScriptOut = Get-DbaDbUdf -SqlInstance $SqlInstance -Database master | Where-Object { $_.Name -eq $QFName } | Export-DbaScript -FilePath $FilePath -Passthru
    if(-not [String]::IsNullOrEmpty($Matches)){ $Matches.Clear() }

    # Build/Modify Function Definition
    @"
USE [$Database]
GO

"@ | Out-File -FilePath $FilePath -Force -Append
    foreach($line in $ScriptOut)
    {
        #$line = $line.Replace('WITH SCHEMABINDING','');
        if($line -match ".*(?'Definition'CREATE.*FUNCTION.*\[dbo\]\.\[$QFName\]\(\s*\)).*") {
            $FunctionDefinition = $Matches['Definition']
            $line = $line.Replace($FunctionDefinition,"ALTER FUNCTION [dbo].[$FunctionName] (@login_name nvarchar(256), @program_name nvarchar(256))");
            $line = @"
IF OBJECT_ID('dbo.$FunctionName') IS NULL
    EXEC ('CREATE FUNCTION $FunctionName() RETURNS INT AS BEGIN RETURN 1 END')
GO

"@ + $line    
        }
        $line = $line.Replace('APP_NAME()','@program_name')
        $line = $line.Replace('ORIGINAL_LOGIN()','@login_name')
        $line | Out-File -FilePath $FilePath -Force -Append
    }

    # Compile function 
    Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -File $FilePath

    # Read CREATE FUNCTION code
    $query = Get-Content -Path $FilePath
    $query = $query.Replace($FunctionName,"$FunctionName`_$($srv.ToLower())")
    $query = $query -join '
'
    # Compile function on CentralServer
    Invoke-DbaQuery -SqlInstance $InventoryServer -Database $Database -Query $query
    $query
}
