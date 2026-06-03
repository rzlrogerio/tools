# Kubernetes Tools

Este diretório agrupa utilitários relacionados ao Kubernetes.

## Subdiretórios

- `get-restart/`
  - `get-restart.sh` — script para localizar pods que reiniciaram recentemente
  - `README.md` — documentação detalhada do script
- `socorro/`
  - `README.md` — documentação de um helper de comandos `kubectl`

## Propósito

Fornecer ferramentas simples para inspeção e suporte de clusters Kubernetes.

## Como usar

1. Acesse o subdiretório desejado:
   - `cd k8s/get-restart`
   - `cd k8s/socorro`
2. Leia o `README.md` específico de cada subdiretório.

## Requisitos comuns

- `kubectl` instalado e configurado
- Para `get-restart.sh`: `jq` instalado

## Observações

- `get-restart.sh` é útil para identificar pods com reinícios recentes dentro de um intervalo de horas.
- `socorro/README.md` descreve exemplos de uso de um script auxiliar para comandos `kubectl`.
