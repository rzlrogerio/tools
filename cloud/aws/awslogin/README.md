# AWS Login Tools

Este diretório contém os scripts de login AWS SSO e a rotina de identificação de conta para uso no prompt e na alteração de contexto.

## Arquivos

- `awslogin.sh` — script principal que realiza login via AWS SSO, recupera clusters EKS e atualiza o `kubeconfig`.
- `get-aws-account.sh` — script auxiliar que determina o ID da conta AWS atual e exibe uma linha de status formatada.

## Como funciona

- `awslogin.sh` limpa variáveis de ambiente AWS conflitantes e faz logout do SSO anterior.
- Seleciona o profile AWS a partir de `~/.aws/config` ou a partir do parâmetro passado.
- Executa `aws sso login --profile <profile>`.
- Usa `aws eks list-clusters` para encontrar clusters EKS nas regiões configuradas.
- Atualiza o `kubeconfig` com os clusters encontrados e mantém backups em `~/.kube/config-aws`.
- Remove contextos não-AWS do `kubeconfig` antes de registrar os clusters.

## Pré-requisitos

- AWS CLI
- jq
- kubectl
- fzf
- (opcional) kubectx

## Uso

```bash
./awslogin.sh <nome-do-profile>
```

## Notas

- O script também usa um arquivo temporário `/tmp/prfsts` para armazenar o profile atual.
- O `get-aws-account.sh` é usado para mostrar o account ID e o nome do profile no prompt ou status.
