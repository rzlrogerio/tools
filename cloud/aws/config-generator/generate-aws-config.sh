#!/bin/bash - 
#===============================================================================
#
#          FILE: generate-aws-config.sh
# 
#         USAGE: ./generate-aws-config.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 06/12/2026 11:45
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
IFS=$'\n\t'

SSO_START_URL_DEFAULT="https://seu-tenant.awsapps.com/start#/"
SSO_REGION_DEFAULT="us-east-1"
SSO_ROLE_NAME_DEFAULT="sua_role"
REGION_DEFAULT="us-east-1"

SSO_START_URL="${SSO_START_URL:-$SSO_START_URL_DEFAULT}"
SSO_REGION="${SSO_REGION:-$SSO_REGION_DEFAULT}"
SSO_ROLE_NAME="${SSO_ROLE_NAME:-$SSO_ROLE_NAME_DEFAULT}"
REGION="${REGION:-$REGION_DEFAULT}"

OUT_FILE="${OUT_FILE:-$HOME/.aws/config.novo}"
FORCE="false"

usage() {
	cat <<EOF
Usage: $(basename "$0") [options]

Options:
	-o FILE    Definir arquivo de saída (padrão: $HOME/.aws/config.novo)
	-y         Substituir config atual sem pedir confirmação
	-h         Mostrar esta ajuda

Ambiente também suporta: SSO_START_URL, SSO_REGION, SSO_ROLE_NAME, REGION
EOF
}

while getopts ":o:yh" opt
do
  case $opt in
    o) OUT_FILE="$OPTARG" ;;
    y) FORCE="true" ;;
    h) usage; exit 0 ;;
    :) echo "Opção -$OPTARG requer um argumento." >&2; usage; exit 1 ;;
    ?) echo "Opção inválida: -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

for cmd in aws jq mktemp
do
  if ! command -v "$cmd" >/dev/null 2>&1
  then
    echo "Erro: '$cmd' não encontrado. Instale-o e tente novamente." >&2
    exit 2
  fi
done

tmpfile=$(mktemp /tmp/aws-config.XXXXXX)
trap 'rm -f "$tmpfile"' EXIT

echo "Consultando contas na Organizations..."
if ! aws_output=$(aws organizations list-accounts --output json 2>/dev/null)
then
  echo "Erro ao chamar 'aws organizations list-accounts'. Verifique suas credenciais/permissões." >&2
  exit 3
fi

echo "Gerando arquivo temporário: $tmpfile"

printf '%s' "$aws_output" | jq -r \
	--arg sso_start "$SSO_START_URL" \
	--arg sso_region "$SSO_REGION" \
	--arg sso_role "$SSO_ROLE_NAME" \
	--arg region "$REGION" \
	'.Accounts[]
	 | select(.Status=="ACTIVE")
	 | ("[profile " + (.Name | gsub("[^A-Za-z0-9]+"; "-") | ascii_downcase) + "]\n" 
			+ "sso_start_url = " + $sso_start + "\n"
			+ "sso_region = " + $sso_region + "\n"
			+ "sso_account_id = " + (.Id|tostring) + "\n"
			+ "sso_role_name = " + $sso_role + "\n"
			+ "region = " + $region + "\n")' > "$tmpfile"

if [[ ! -s "$tmpfile" ]]
then
  echo "Nenhuma conta ACTIVE encontrada ou erro ao gerar o arquivo." >&2
  exit 4
fi

echo "Arquivo gerado em: $tmpfile"

if [[ -f "$OUT_FILE" ]]
then
  if [[ "$FORCE" == "true" ]]
  then
    mv -f "$OUT_FILE" "$OUT_FILE.bak.$(date +%s)"
    echo "Backup do arquivo anterior em: $OUT_FILE.bak.$(date +%s)"
  else
    read -r -p "Arquivo $OUT_FILE já existe. Substituir? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]
    then
      mv "$OUT_FILE" "$OUT_FILE.bak.$(date +%s)"
      echo "Backup criado em: $OUT_FILE.bak.$(date +%s)"
    else
      echo "Saindo sem modificar $OUT_FILE. Arquivo temporário: $tmpfile"
      exit 0
    fi
  fi
fi

mv "$tmpfile" "$OUT_FILE"
trap - EXIT

echo "Arquivo final salvo em: $OUT_FILE"
echo "Revise e mova para ~/.aws/config se desejar. (ou rode com -y para substituir automaticamente)"
