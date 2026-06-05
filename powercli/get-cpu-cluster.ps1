Get-VMHost | Sort Name | Get-View | Select Name, @{N=“Cluster“;E={Get-Cluster -VMHost (Get-VMHost $_.Name)}},@{N=“CPU“;E={$_.Hardware.CpuPkg[0].Description}}
