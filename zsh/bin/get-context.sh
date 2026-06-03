#!/bin/bash -
#===============================================================================
#
#          FILE: get-context.sh
#
#         USAGE: ./get-context.sh
#
#   DESCRIPTION:
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Rogério de Araújo Rodrigues (),
#  ORGANIZATION:
#       CREATED: 04/02/2025 10:43
#      REVISION:  ---
#===============================================================================

set -o nounset # Treat unset variables as an error

fileKube="$HOME/.kube/config"
vanilla="seu-vanilla" # exemplo de contexto vanilla, ajuste conforme necessário
prodAccount="112233434" # exemplo de ID de conta prod, ajuste conforme necessário  
fileStat="/tmp/prfsts"

runMagic() {
  # Get current context and namespace via kubectl (more reliable than grepping kubeconfig)
  contextString=$(kubectl config current-context 2>/dev/null || true)
  context=$(echo "$contextString" | sed 's/"//g' | awk -F'/' '{ print $NF }')
  account=$(echo "$contextString" | cut -f5 -d":")

  if [ -z "$context" ]; then
    exit
  fi

  # Use jsonpath to get the active namespace for the current context
  namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || true)

  color=""
  nc="\033[0m" # Reset color

  # Primeiro verifica se é prod por conta ou pelo contexto vanilla
  if [[ "$context" == "$vanilla" ]] || [[ "$account" == "$prodAccount" ]] || [[ "$context" == *"-prod"* ]]
  then
    color="\033[31m" # Red text
    environment="Prod:"
  elif [[ "$context" == *"-hlg*" || "$context" == *"-dev"* || "$context" == *"-qa"* || "$context" == *"-sandbox"* || "$context" == *"minikube"* ]]
  then
    color="\033[32m" # Green text
    environment="QA:"
  else
    color="\033[33m" # Yellow text
    environment="Ainda não definido :("
  fi

  if [ -n "$context" ]
  then
    echo -e "${color}${environment} $context (${namespace:-default}) ${nc}"
  fi
}

# main
if [ ! -e "$fileKube" ]
then
  exit
else
  runMagic
fi
