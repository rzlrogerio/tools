#!/bin/bash

### Script para enviar alarmes do Zabbix baseados em grupos para o
### Telegram

### Author Rogerio de Araujo Rodrigues
### 09/02/2017

$TOKEN="SEU_TOKEN"
$CHATID="SEU_CHATID"

$telegram = "https://api.telegram.org/bot$TOKEN/sendMessage"

$PROXY = "http://px.seudom:3128"

$resource = "http://seu-zabbix/zabbix/api_jsonrpc.php"
$jsonauth = '{"jsonrpc": "2.0","method": "user.login","params": {"user": "user-zabbix","password": "senha"}, "id": 1, "auth": null}'
$auth = (Invoke-RestMethod -Method Post -uri $resource -ContentType "application/json-rpc" -Body $jsonauth).result


# The service list for notification
$content = @(get-content C:\scripts\rotinas\zabbix\telegram\CI-servicos-core.csv)

Foreach ($GROUP in $content)
        {
	 # Na sequencia precisamos saber qual eh o ID do grupo para consultar seus alertas
         $jsongetgrp = '{
				"jsonrpc": "2.0",
				"method": "hostgroup.get",
				"params": {
					"output": "extend",
						"filter": {
            						"name": [
                		 				 "' + $GROUP + '"
								]
        					}
					},
       				"auth": "' + $auth + '",
				"id": 1 
			}'

	 $GROUPID = (Invoke-RestMethod -Method Post -Uri $resource -Body $jsongetgrp -ContentType "application/json").result
	
         $idgroup = $GROUPID.groupid

	 $jsonalert = '{
				"jsonrpc": "2.0",
				"method": "trigger.get",
				"params": {
					"output": [
						"host.name",
						"triggerid",
						"description",
						"extend",
						"lastchange",
						"status",
						"priority"
					],
				"monitored": true,
				"expandDescription": 1,
				"only_true": true,
				"withLastEventUnacknowledged": true,
				"groupids": ' + $idgroup + '
				}, 
                                "auth": "' + $auth + '",
                                "id": 1
                        }'

         $ALERTS = (Invoke-RestMethod -Method Post -Uri $resource -Body $jsonalert -ContentType "application/json").result
    	
 	 $DESC = $ALERTS.description
	
         $TTCHT = $DESC.Length
	
	 if ( $TTCHT -gt 0 ) 
		{
		 write-host $GROUP
		 write-host $DESC

		 $MSG = "$GROUP - $DESC"
		 write-host $MSG
		
		 Invoke-WebRequest -Proxy $PROXY -Method Post -Uri "$telegram" -ContentType "application/json;charset=utf-8" -Body (ConvertTo-Json -Compress -InputObject @{chat_id=$CHATID; text="$MSG"})
    		}

        } 
