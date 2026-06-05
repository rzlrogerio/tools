#!/bin/sh

# Application Alerts
# Network Alerts
# Storage Alerts
# Todos os itens que sao core (DataStore e Hypervisor) sao verificados no mesmo script
# Author: Rogerio de Araujo Rodrigues

# Importamos todos os modulos do VMWare para este script
& "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

# Abrimos as conexoes
Connect-OMServer seu-vcops -User apiuser -Password suasenha
Connect-VIServer seu-vcenter -User apiuser -Password suasenha

# O vCops e o seu Zabbix proxy
$VCOPS = "seu-vcops"
$PRX = "seu zabbix / zabbix proxy"

################################################################################
########
########
### Aqui trabalhamos com os alertas das VMs
########
########

$TYPE_ALERTS = @("Application Alerts","Network Alerts","Storage Alerts","Virtualization/Hypervisor Alerts")

# Rotina para gerar a primeira base de envio
ForEach ($ALERT in $TYPE_ALERTS)
        {

         # Tratando para remover os espacos
	 $BASE_CONSULT = $ALERT | % {$_ -replace ' ','-'} | % {$_ -replace '/','-'}

         Get-OMAlert -status active | Where-Object {$_.Type -match "$ALERT"} | select Resource | Select-Object -Skip 1 | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | % {$_ -replace '"',''}  | Select-String -notmatch "VCOPS"  | Select-String -notmatch "self-service" > $BASE_CONSULT

         $content = [System.IO.File]::ReadAllText("$BASE_CONSULT")
         $content = $content.Trim()
         [System.IO.File]::WriteAllText("$BASE_CONSULT", $content)

         $RESOURCES = @(get-content $BASE_CONSULT)

         $TTL = Get-Content $BASE_CONSULT | Measure-Object -line | select Lines

         if ( $TTL.Lines -gt 0 )
                {
                 $MSG = Get-Content $BASE_CONSULT
                 #write-host "cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VCOPS -k Alert.Virtualization.$BASE_CONSULT -o "1_ALERT $MSG""
                 cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VCOPS -k Alert.Virtualization.$BASE_CONSULT -o "1_ALERT $MSG"
                }
                 else
                        {
                         #write-host "cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VCOPS -k Alert.Virtualization.$BASE_CONSULT -o 0_ALERT"
                         cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VCOPS -k Alert.Virtualization.$BASE_CONSULT -o 0_ALERT
                        }

	 # Remove qualquer coisa antiga
	 del $BASE_CONSULT

        }

########
########
################################################################################

################################################################################
########
########
### Aqui trabalhamos com os alertas do que eh Core (Datastore e Hypervisor)
########
########

# Diretorio para receber os resultados
mkdir c:\scripts\vcops\base
$DIR = "c:\scripts\vcops\base"

##########################################################################################
##########################################################################################
###
###
### Rotina para verificar alarmes nos ESXI
###
###
##########################################################################################
##########################################################################################


# Gerando a lista de ESXi - Esta lista sempre eh dinamica, ou seja, ESXi novo automaticamente
# tera os itens monitorados

$ESXIS = Get-VMHost | Select NAME

ForEach($ESXI in $ESXIS)
	{
	 $VMHOST = $ESXI.Name
	 $STATUS = Get-OMAlert -Status active -Resource $VMHOST | Select Name
         echo $STATUS.Name > $DIR/$VMHOST

	 $content = [System.IO.File]::ReadAllText("$DIR/$VMHOST")
         $content = $content.Trim()
         [System.IO.File]::WriteAllText("$DIR/$VMHOST", $content)

         $RESOURCES = @(get-content $DIR/$VMHOST)


         $TTL = Get-Content $DIR/$VMHOST | Measure-Object -line | select Lines

         if ( $TTL.Lines -gt 0 )
                {
                 $MSG = Get-Content $DIR/$VMHOST
                 #write-host "cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VMHOST -k Alert.Virtualization.Core $VMHOST -o "1_ALERT $MSG""
		 cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VMHOST -k Alert.Virtualization.Core $VMHOST -o "1_ALERT $MSG"
                }
                 else
                        {
                         #write-host "cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VMHOST -k Alert.Virtualization.Core $VMHOST -o 0_ALERT"
                         cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $VMHOST -k Alert.Virtualization.Core $VMHOST -o 0_ALERT
			}

         # Remove qualquer coisa antiga
         del $DIR/$VMHOST
	}

####
####
#### Fim da rotina dos ESXi
####
##########################################################################################
##########################################################################################

##########################################################################################
##########################################################################################
###
###
### Rotina para verificar alarmes nos DATASTORE
###
###
##########################################################################################
##########################################################################################

# Gerando a lista de DATASTORE - Esta lista sempre eh dinamica, ou seja, DATASTORE novo automaticamente
# tera os itens monitorados

$DATASTORES = Get-Datastore | Where-Object {$_.Type -eq "NFS"} | select Name  

ForEach($DATASTORE in $DATASTORES)
        {
         $DS = $DATASTORE.Name
         $STATUS = Get-OMAlert -Status active -Resource $DS | Select Name 
         echo $STATUS.Name > $DIR/$DS

	 $content = [System.IO.File]::ReadAllText("$DIR/$DS")
         $content = $content.Trim()
         [System.IO.File]::WriteAllText("$DIR/$DS", $content)

         $RESOURCES = @(get-content $DIR/$DS)

         $TTL = Get-Content $DIR/$DS | Measure-Object -line | select Lines

         if ( $TTL.Lines -gt 0 )
                {
                 $MSG = Get-Content $DIR/$DS
                 #write-host "cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $DS -k Alert.Virtualization.Core $DS -o "1_ALERT $MSG""
                 cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $DS -k Alert.Virtualization.Core $DS -o "1_ALERT $MSG"
                }
                 else
                        {
                         #write-host "cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $DS -k Alert.Virtualization.Core $DS -o 0_ALERT"
                         cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $DS -k Alert.Virtualization.Core $DS -o 0_ALERT
                        }

         # Remove qualquer coisa antiga
         del $DIR/$DS

        }

####
####
#### Fim da rotina dos DATASTORE
####
##########################################################################################
##########################################################################################

##########################################################################################
##########################################################################################
###
###
### Rotina para verificar o espaco ocupado dos DS (%)
###
###
##########################################################################################
##########################################################################################

$DS = Get-DataStore | Where-Object {$_.Type -eq "NFS"} | select Name

foreach($DSTORE in $DS)
	{
	 $CONNECT = get-datastore $DSTORE.Name -refresh | Select FreeSpaceGB, CapacityGB

	  #####################
	  #
          # Rotina para coleta do uso dos DS
	  #
	  #####################

	  $DS_FREE = $CONNECT.FreeSpaceGB
	  $DS_CAPAC = $CONNECT.CapacityGB

	  $DS_USED = [Math]::Round($DS_CAPAC-$DS_FREE)

	  $PERC_DS_USED = [Math]::Round($DS_USED/$DS_CAPAC*100,0)

	  cmd /C c:\zabbix\bin\win64\zabbix_sender.exe  -z $PRX -s $DSTORE.Name -k Hypervisor.Datastore -o $PERC_DS_USED
	}


## Tratativa de nomes ruins
$DSWNAME = Get-DataStore | where-object {$_.NAME -match "FAS3270*"}

foreach($DSTOREWNAME in $DSWNAME)
	{
	 $CONNECT = get-datastore $DSTOREWNAME | Select Name, FreeSpaceGB, CapacityGB

	 $NAMEWR = $CONNECT.Name

         $N1= $NAMEWR -replace '\(', '_'
         $NOMETRAT= $N1 -replace '\)', '_'

	 echo $NOMETRAT

	 #####################
	 #
         # Rotina para coleta do uso dos DS
	 #
	 #####################

	 $DS_FREE = $CONNECT.FreeSpaceGB
	 $DS_CAPAC = $CONNECT.CapacityGB

	 $DS_USED = [Math]::Round($DS_CAPAC-$DS_FREE)

	 $PERC_DS_USED = [Math]::Round($DS_USED/$DS_CAPAC*100,0)

	 cmd /C c:\zabbix\bin\win64\zabbix_sender.exe -z $PRX -s $NOMETRAT -k Hypervisor.Datastore -o $PERC_DS_USED
	}

####
####
#### Fim da rotina que verifica o espaco ocupado do  DATASTORE
####
##########################################################################################
##########################################################################################

Disconnect-OMServer -confirm:$false
Disconnect-VIServer -confirm:$false
