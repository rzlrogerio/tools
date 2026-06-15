# AWS Inventory Tools

Este diretório contém utilitários para descoberta e identificação de contas AWS, bem como para a construção de informações de contexto no prompt.

## Arquivos

- `aws-config-search` — ferramenta para buscar recursos AWS por região, tipo e texto de filtro.
- `get-aws-account.sh` — script para obter o ID da conta AWS atual e identificar o profile correspondente no `~/.aws/config`.

## Como funciona

- `get-aws-account.sh` executa `aws sts get-caller-identity` para recuperar o ID da conta.
- Opcionalmente usa `--profile` se o arquivo `/tmp/prfsts` estiver presente.
- Busca no `~/.aws/config` por um profile que contenha o mesmo account ID.
- Exibe um prompt colorido com base no nome do profile (prod, dev, qa, sandbox).

## Pré-requisitos

- AWS CLI
- jq

## Uso

```bash
./get-aws-account.sh --update
```

- `--update` força atualização do cache de conta.

## Observações

- O script usa cache em `/tmp/.account.log` para melhorar performance.
- Se não estiver logado, o cache é limpo.
