#!/bin/sh

Add-PSSnapin VMware.VimAutomation.Core

Connect-VIServer vcenter.seudom -User svc_adm_ucs@pci.intra -Password suasenha 

# Script para ajustar os parametros de CPU e Memoria das VM conforme o configurado.
# O script verificar quais VMs estao com o parametro unlimited (-1) e executa.
# Podemos ajustar e usar para cluster especificos mudando o inicio para:

# Neste exemplo estamos "setando" para 1GHz por vCPU

# removendo os arquivos anteriores
rm prov.csv
rm sem-limit.csv

# get-cluster NOME_CLUSTER | get-vm
get-vm | Get-VMResourceConfiguration | Where-Object {$_.CpuLimitMhz -eq '-1' -or $_.MemLimitMB -eq '-1'} | select VM | Export-CSV -NoTypeInformation prov.csv
gc prov.csv | % {$_ -replace '"',''} > sem-limit.csv

$content = @(get-content sem-limit.csv)

ForEach ($vmname in $content)
    {
     # Para CPU fazemos o calculo 
     $VM = get-vm $vmname

     $Mhz = 1024
     $CoreQTD = ($VM).NumCPU

     $CPUNew = [Math]::Round($Mhz*$CoreQTD)

     # Aplicar para Memoria
     $MemVM = ($VM).MemoryMB

     # Para obter todos os possiveis campos passiveis de alteracao
     # get-vm $VM | Get-VMResourceConfiguration | fl
     $VM | Get-VMResourceConfiguration | Set-VMResourceConfiguration -MemLimitMB $MemVM -CpuLimitMhz $CPUNew
    }

