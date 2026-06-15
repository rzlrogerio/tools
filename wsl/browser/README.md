# WSL Browser Helper

Este diretório contém scripts para facilitar o uso de browsers dentro do WSL.

## Objetivo

O uso aqui é para facilitar a integração do ambiente WSL com navegadores executados no Windows, especialmente em fluxos que exigem autenticação e login automático.

## Como usar

O script `chrome-wrapper.sh` permite iniciar o browser a partir do WSL e interagir com solicitações de login de forma mais natural entre Linux e Windows.

## Configuração de ambiente

Para o correto funcionamento, adicione a variável de ambiente abaixo ao seu shell WSL:

```bash
export WSLBROWSER=1
```

Isso garante que o script e o ambiente WSL saibam que o fluxo de browser está ativo e possam redirecionar corretamente as solicitações de login.

## Benefícios

- melhora a integração entre WSL e browser do Windows
- facilita o uso automático de solicitações de login
- torna o fluxo de autenticação mais transparente dentro do WSL

## Exemplo

```bash
source ~/.bashrc
export WSLBROWSER=1
./chrome-wrapper.sh
```

> Com isso, é possível interagir de maneira automática com as solicitações de login, evitando passos manuais desnecessários dentro do WSL.
