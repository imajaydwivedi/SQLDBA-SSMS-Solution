USE SQLDBATools
go

-- Distinct Errors
select distinct Cmdlet from [Staging].[CollectionErrors] as e with(nolock)

-- Server not Reachable
select 'Server Unreachable' as Category, * from [Staging].[CollectionErrors] as e with(nolock) where e.Command like '%Test-Connection%'

-- Server not Reachable
select 'PSRemoting (WinRM)' as Category, * from [Staging].[CollectionErrors] as e with(nolock) where e.Command like '%Invoke-Command%'

-- SQL Login Failed
select 'Login Failed' as Category, * from [Staging].[CollectionErrors] as e with(nolock) where e.Error like '%Login failed for user%'

-- Get-ClusterInfo
select 'Get-ClusterInfo' as Category, * from [Staging].[CollectionErrors] as e with(nolock) where e.Cmdlet = 'Get-ClusterInfo'
