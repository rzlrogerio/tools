#!/bin/bash -
#===============================================================================
#
#          FILE: get-aws-account.sh
#
#         USAGE: ./get-aws-account.sh [--update]
#
#   DESCRIPTION: Obtem o numero da conta AWS e retorna o nome do profile
#                Usa cache em /tmp/.account.log para performance
#
#       OPTIONS: --update para forçar atualização do cache
#  REQUIREMENTS: aws cli, jq
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (),
#  ORGANIZATION:
#       CREATED: 12/12/2024 10:43
#      REVISION:  ---
#===============================================================================

set -o nounset # Treat unset variables as an error

fileAwsConfig="$HOME/.aws/config"
cacheFile="/tmp/.account.log"

updateCache() {
  # Verifica se há profile salvo pelo awslogin
  profileArg=""
  if [ -f "/tmp/prfsts" ]; then
    profile=$(cat /tmp/prfsts 2>/dev/null)
    if [ -n "$profile" ] && [ "$profile" != "null" ]; then
      profileArg="--profile $profile"
    fi
  fi

  # Obtem o numero da conta AWS atual
  accountId=$(aws sts get-caller-identity $profileArg --output json 2>/dev/null | jq -r '.Account' 2>/dev/null)

  if [ -z "$accountId" ] || [ "$accountId" == "null" ]
  then
    # Se não está logado, remove o cache
    [ -f "$cacheFile" ] && rm -f "$cacheFile"
    return
  fi

  # Procura o profile name no arquivo config baseado no account ID
  profileName=""
  if [ -f "$fileAwsConfig" ]
  then
    # Busca por linhas que contenham o account ID e pega o profile correspondente
    profileLine=$(grep -B 10 "$accountId" "$fileAwsConfig" | grep -E "^\[profile " | tail -1)
    if [ -n "$profileLine" ]
    then
      profileName=$(echo "$profileLine" | sed 's/\[profile //' | sed 's/\]//')
    fi
  fi

  # Define cores baseado no tipo de ambiente
  if [[ "$profileName" == *"prod"* ]] # || [[ "$accountId" == "seu outro match" ]]
  then
    color="\033[31m" # Red text
    environment="Prod:"
  elif [[ "$profileName" == *"dev"* ]] || [[ "$profileName" == *"qa"* ]] || [[ "$profileName" == *"sandbox"* ]] || [[ "$profileName" == *"hml"* ]]
  then
    color="\033[32m" # Green text
    environment="QA:"
  else
    color="\033[33m" # Yellow text
    environment="AWS:"
  fi

  # Salva no cache
  if [ -n "$accountId" ]
  then
    if [ -n "$profileName" ]
    then
      echo -e "${color}${environment} $profileName ($accountId) \033[0m" > "$cacheFile"
    else
      echo -e "${color}${environment} $accountId \033[0m" > "$cacheFile"
    fi
  fi
}

readCache() {
  if [ -f "$cacheFile" ]
  then
    cat "$cacheFile"
  fi
}

# main
if [[ "${1:-}" == "--update" ]]
then
  updateCache
else
  # Verifica se o cache existe e não é muito antigo (5 minutos)
  if [ ! -f "$cacheFile" ] || [ $(find "$cacheFile" -mmin +5 2>/dev/null | wc -l) -gt 0 ]
  then
    updateCache
  fi
  readCache
fi
