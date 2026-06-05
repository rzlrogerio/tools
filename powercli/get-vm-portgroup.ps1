$CLUSTER = "CLUSTER_NAME" 

get-cluster $CLUSTER | get-vmhost  | Get-vm | get-networkadapter |  Select-Object @{E={$_.NetworkName}},@{N="VM";E={$_.Parent.Name}} | export-csv relatorio-vm-redes-$CLUSTER.csv
