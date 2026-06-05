## Documentação rápida

- [Git tools](git/README.md)
- [Kubernetes tools](k8s/README.md)
- [Zsh tools](zsh/README.md)
- [PowerCLI tools](powercli/README.md)
- [Configuração Zsh](zsh/rc/README.md)
- [get-restart](k8s/get-restart/README.md)
- [socorro](k8s/socorro/README.md)

## Uso

1. Navegue até o subdiretório desejado.
2. Abra o `README.md` correspondente.
3. Siga as instruções específicas para cada script ou configuração.

# Ferramentas

Este repositório contém utilitários e configurações úteis para Git, Kubernetes, PowerCLI e Zsh.

## Estrutura principal

- [`git/`](git/README.md)
  - [`change-branch`](git/change-branch) — script para selecionar e trocar de branch usando `git` + `fzf`
  - [`change-branch.png`](git/change-branch.png) — imagem ilustrativa do script
  - [`README.md`](git/README.md) — descrição do script e instruções básicas

- [`k8s/`](k8s/README.md)
  - [`get-restart/`](k8s/get-restart/README.md)
    - [`get-restart.sh`](k8s/get-restart/get-restart.sh) — busca pods que reiniciaram recentemente em um cluster Kubernetes
    - [`README.md`](k8s/get-restart/README.md) — documentação do script
  - [`socorro/`](k8s/socorro/README.md)
    - [`README.md`](k8s/socorro/README.md) — instruções e exemplos de uso do helper de comandos `kubectl`

- [`zsh/`](zsh/README.md)
  - [`README.md`](zsh/README.md) — documentação de configuração e ferramentas Zsh
  - [`bin/get-context.sh`](zsh/bin/get-context.sh) — script para exibir contexto Kubernetes no prompt
  - [`rc/install.sh`](zsh/rc/install.sh) — instalador da configuração Zsh
  - [`rc/README.md`](zsh/rc/README.md) — documentação do instalador e da configuração Zsh
  - [`theme/rogerio.png`](zsh/theme/rogerio.png) — screenshot do tema Zsh
  - [`theme/rogerio.zsh-theme`](zsh/theme/rogerio.zsh-theme) — tema personalizado para Oh My Zsh

- [`powercli/`](powercli/README.md)
  - [`README.md`](powercli/README.md) — documentação de scripts PowerCLI para vSphere/ESXi
  - Scripts PowerShell para automação de infraestrutura VMware

## Resultados

<img src="./git/change-branch.png" alt="change-branch" width="720" />

<img src="./zsh/theme/rogerio.png" alt="rogerio theme" width="720" />

## Observações

- A imagem `git/change-branch.png` está incluída para exibição no modo web do GitHub.
- Os arquivos de documentação estão organizados por diretório para facilitar a leitura.

- **Recomendação:** use `kubectx` para alternar rapidamente entre contexts/namespaces do Kubernetes.

- **Links úteis:**
  - [Oh My Zsh](https://ohmyz.sh/) — gerenciador de temas e plugins para Zsh
  - [kubectl](https://kubernetes.io/docs/reference/kubectl/) — documentação oficial do cliente Kubernetes
  - [fzf](https://github.com/junegunn/fzf) — fuzzy finder usado por scripts interativos
