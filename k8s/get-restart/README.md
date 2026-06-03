# get-restart.sh

Este script Bash tem como objetivo identificar pods do Kubernetes que tiveram reinícios recentes, dentro de um intervalo de tempo especificado.

## Uso

```sh
./get-restart.sh <intervalo_em_horas>
```

- `<intervalo_em_horas>`: Número de horas para considerar na busca por reinícios recentes. Exemplo: `./get-restart.sh 24` irá listar pods que reiniciaram nas últimas 24 horas.

## Descrição

O script executa os seguintes passos:

1. Obtém todos os pods do cluster Kubernetes usando `kubectl get pods -o json`.
2. Filtra os pods que tiveram pelo menos um restart.
3. Para cada pod, verifica a data/hora do último restart.
4. Exibe os pods cujo último restart ocorreu dentro do intervalo informado.

## Requisitos

- `kubectl` configurado e autenticado no cluster desejado.
- `jq` instalado para manipulação de JSON.

## Exemplo de saída

```
Pod: meu-pod-123, reinicio: 2025-10-29T10:15:00Z - UTC
```

## Observações

- O script considera o horário UTC para comparação.
- É necessário permissão para listar pods no cluster Kubernetes.

## Autor

Adapte o campo de autor conforme necessário.
