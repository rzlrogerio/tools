# AWS Config Generator

Ferramenta para gerar arquivos de configuração AWS SSO (`~/.aws/config`) a partir de contas ativadas na AWS Organizations.

## Arquivos

- `generate-aws-config.sh` — script que consulta `aws organizations list-accounts` e gera perfis SSO para todas as contas ACTIVE.
- `teste` — versão de teste do script com o mesmo propósito.

## Como funciona

- Executa `aws organizations list-accounts --output json`.
- Cria um arquivo de saída com seções `profile <nome>`, usando o nome da conta transformado para um formato válido.
- Para cada conta ACTIVE, escreve:
  - `sso_start_url`
  - `sso_region`
  - `sso_account_id`
  - `sso_role_name`
  - `region`

## Uso

```bash
./generate-aws-config.sh -o ~/.aws/config.novo
```

### Opções
- `-o FILE` — define o arquivo de saída.
- `-y` — sobrescreve o arquivo de saída sem pedir confirmação.
- `-h` — exibe ajuda.

## Pré-requisitos

- AWS CLI
- jq

## Observações

- O script usa um arquivo temporário seguro e remove-o ao final.
- Caso o arquivo de saída já exista, são criados backups antes da substituição.
