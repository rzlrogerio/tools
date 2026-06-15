# Azure Cloud Tools

Este diretório contém utilitários para autenticação e gerenciamento de clusters AKS no Azure.

## Subdiretórios

- `azlogin/` — script para selecionar subscriptions Azure e registrar credenciais de clusters AKS no `kubeconfig`.

## Conteúdo

- `azlogin/README.md` — documentação do script `azlogin`
- `azlogin/azlogin.sh` — script principal de login e cadastro de AKS

## Objetivo

Fornecer uma forma simples de:

- listar subscriptions do Azure
- permitir seleção interativa de subscriptions com `fzf`
- registrar clusters AKS no `kubeconfig`
- evitar duplicação de contextos e clusters
- manter um backup local do `kubeconfig`
