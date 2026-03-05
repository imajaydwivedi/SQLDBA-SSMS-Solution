/* ~~~~~~~~ AG Node Down ~~~~~~~~~~ */
-- step 01: Remove node from cluster (run on cluster owner node)
Remove-ClusterNode -Name AgHost-1B -Force
Get-ClusterNode

-- step 02: Completely clear cluster config on down node
Stop-Service ClusSvc -Force
Clear-ClusterNode -Force

-- step 03: Re-add down node to Cluster
Add-ClusterNode -Name AgHost-1B
Get-ClusterNode

