$server = 'someProdServer'
$dbname = 'facebook';

$query = @"
SET NOCOUNT ON;
if OBJECT_ID('tempdb..#TableSize') is not null
	drop table #TableSize;
create table #TableSize (
    [name] varchar(255),
    [rows] bigint,
    reserved varchar(255),
    [data] varchar(255),
    index_size varchar(255),
    unused varchar(255));

if OBJECT_ID('tempdb..#ConvertedSizes') is not null
	drop table #ConvertedSizes;
create table #ConvertedSizes (
    [table_name] varchar(255),
    [rows] bigint,
    reservedKb int,
    dataKb int,
    reservedIndexSize int,
    reservedUnused int,
	reservedMB as cast(reservedKb/1024.0 as numeric(20,2)),
	reservedGB as cast(reservedKb/1024.0/1024.0 as numeric(20,2)),
	dataMB as cast(dataKb/1024.0 as numeric(20,2)),
	)

EXEC sp_MSforeachtable @command1="insert into #TableSize
EXEC sp_spaceused '?'";
--exec sp_helptext 'sp_spaceused'

insert into #ConvertedSizes ([table_name], [rows], reservedKb, dataKb, reservedIndexSize, reservedUnused)
select [name], [rows], 
		SUBSTRING(reserved, 0, LEN(reserved)-2), 
		SUBSTRING(data, 0, LEN(data)-2), 
		SUBSTRING(index_size, 0, LEN(index_size)-2), 
		SUBSTRING(unused, 0, LEN(unused)-2)
from #TableSize

select [table_name], [rows], reservedMB, dataMB, reservedIndexSize, reservedUnused
from #ConvertedSizes
where reservedMB > 5.0 
	--and ltrim(rtrim(table_name)) in ('spn_iattr_user_stg','cattr_latest','data_mismatch_audit','iattr_latest','spn_cattr_user_stg','security_cache_stats','hierarchy_dbo','pre_tdbl_nm_cattr','rattr_latest','hierarchy_old','spn_cattr_temporal_stg','backup_spn_universe','spn_iattr_temporal_stg','pre_tdbl_nm_iattr','_td_bl_mult_udlys')
order by reservedKb desc;
"@


cls
$size_MB_filter = 5120 # 5 gb
$rs = Invoke-DbaQuery -SqlInstance $server -Database $dbname -Query $query
$rs = $rs | Where-Object {$_.reservedMB -gt $size_MB_filter} | Sort-Object -Property reservedMB -Descending;
$rs.Count;
$rs | ft -AutoSize | Out-String
