$SourceServer = 'SourceServer'
$DestinationServer = 'TargetServer'
$Database = 'SrcDb'
$TableName = 'dbo.facebook'
$DbaDatabase = 'dustbin'

# Create Copy in dustbin on Destination
Copy-DbaDbTableData -SqlInstance $SourceServer `
                    -Destination $DestinationServer `
                    -Database $Database `
                    -Table $TableName `
                    -DestinationDatabase $DbaDatabase `
                    -AutoCreateTable `
                    -NotifyAfter 500 `
                    -Verbose

$dbaDbTable = Get-DbaDbTable -SqlInstance $SourceServer -Database $Database -Table $TableName
$identity = @()
$identity += $dbaDbTable.Columns | Where-Object {$_.Identity}
$columnsInsertString = $dbaDbTable.Columns -join ','

$joinColumns = @()
if($dbaDbTable.HasPrimaryClusteredIndex) {
    $joinColumns += ($dbaDbTable.Indexes | Where-Object {$_.IndexKeyType -like '*PrimaryKey*' -and $_.IsUnique}).IndexedColumns | Select-Object -ExpandProperty Name
}
else {
    $joinColumns += $dbaDbTable.Indexes | Where-Object {$_.IsUnique} | ForEach-Object -Begin {$index = @(); $col_counts = 10} `
                        -Process {if($_.IndexedColumns.Count -le $col_counts){$index = $_.IndexedColumns; $col_counts = $_.IndexedColumns.Count}} -End {$index} | Select-Object -ExpandProperty Name
}
#$dbaDbTable.Indexes | Select-Object Name,IndexType,IndexKeyType,IndexedColumns,IsUnique

cls
if($joinColumns.Count -gt 0)
{
$tsql = @"
use [$Database]
go
$( if($identity.Count -gt 0){
"
SET IDENTITY_INSERT $TableName ON 
GO"
} )

insert [$Database].$TableName
($columnsInsertString)

select s.*
from $DbaDatabase.$TableName s
left join [$Database].$TableName t
on 1 = 1
$( foreach($col in $joinColumns){ "  and s.$col = t.$col" } )
where t.$($joinColumns[0]) is null;
go

$( if($identity.Count -gt 0){
"
SET IDENTITY_INSERT $TableName OFF 
GO
"
} )
"@
    $tsql
}
else {
    "No Unique key constraint found on Table to copy b/w Source & Destination"
}
