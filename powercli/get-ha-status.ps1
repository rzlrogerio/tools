$clusterName = 'CLUSTER'
 
Get-Cluster -Name $clusterName | Get-VMHost |
Select Name,@{N='State';E={$_.ExtensionData.Runtime.DasHostState.State}}
 
