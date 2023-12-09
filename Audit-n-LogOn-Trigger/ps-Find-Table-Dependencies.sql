$tables = @('Table01','Table02','Table03')
$SqlInstance = 'ServerNameHere'
$DbName = 'DatabaseNameHere'

$tableObj = (Get-DbaDatabase -SqlInstance $SqlInstance -Database $DbName).tables | Where-Object Name -In $tables
$DbaDependency = $tableObj | Get-DbaDependency
#$DbaDependency | ogv

$DbaDependency | Write-DbaDbTableData -SqlInstance $SqlInstance -Table 'tempdb.dbo.dba_table_dependencies' -AutoCreateTable -Truncate;

$resultDependency = Invoke-Sqlcmd -ServerInstance $SqlInstance -Query "select * from tempdb.dbo.dba_table_dependencies where Type <> 'Trigger'"

$file = "C:\Users\Public\Documents\Logs\table_dependencies.txt"
foreach($row in ($resultDependency | Where-Object {$_.Type -eq 'View'}) )
{
    #$dependentName = "[$($row.Owner)].[$($row.Dependent)]"
    $dependentName = $row.Object

    @"
add (SELECT ON $dependentName BY public),
add (INSERT ON $dependentName BY public),
add (UPDATE ON $dependentName BY public),
add (DELETE ON $dependentName BY public),
"@ | Out-File -FilePath $file -Append
}

foreach($row in ($resultDependency | Where-Object {$_.Type -eq 'StoredProcedure'}) )
{
    #$dependentName = "[$($row.Owner)].[$($row.Dependent)]"
    $dependentName = $row.Object

    @"
ADD (EXECUTE ON OBJECT::$dependentName BY [public]);
"@ | Out-File -FilePath $file -Append
}

notepad $file