# Git Tools

Este diretório contém um utilitário para facilitar a troca de branches em repositórios Git.

## Arquivos

- `change-branch` — script Bash para selecionar e trocar de branch usando `git` e `fzf`
- `change-branch.png` — imagem ilustrativa relacionada ao script
- `adjust_repo_protection.sh` — aplica proteções de branch e recursos de segurança em repositórios GitHub

## Descrição do script `change-branch`

O script faz o seguinte:

- Verifica se o `git` está instalado
- Verifica se o `fzf` está instalado
- Confirma se o usuário está dentro de um repositório Git
- Lista branches locais e remotas ordenadas por data de commit
- Permite selecionar uma branch com `fzf`
- Alterna para a branch selecionada ou cria uma branch local para rastrear uma remota

## Uso

```bash
./change-branch
```

ou

```bash
./change-branch nome-da-branch
```

## Requisitos

- `git`
- `fzf`

## Script `adjust_repo_protection.sh`

O script usa o GitHub CLI (`gh`) para configurar um repositório ou todos os repositórios não arquivados de um usuário ou organização.

### Uso

```bash
./adjust_repo_protection.sh <owner> --all
./adjust_repo_protection.sh <owner> <repo>
./adjust_repo_protection.sh <owner>/<repo>
./adjust_repo_protection.sh --help
```

Exemplos:

```bash
./adjust_repo_protection.sh octocat --all
./adjust_repo_protection.sh octocat hello-world
./adjust_repo_protection.sh octocat/hello-world
```

### O que configura

- Protege a branch padrão exigindo que alterações sejam integradas por pull request.
- Permite merge sem aprovação obrigatória, para que o proprietário possa gerenciar o repositório individualmente.
- Bloqueia bypass de administradores, force-push e exclusão da branch padrão.
- Exige a resolução de conversas de revisão antes do merge.
- Ativa a exclusão automática da branch após o merge.
- Ativa alertas de vulnerabilidades, atualizações de segurança do Dependabot e relatórios privados de vulnerabilidades.
- Ativa secret scanning e proteção contra push de segredos, quando disponíveis para o repositório.

### Requisitos e observações

- Bash e GitHub CLI (`gh`) instalados.
- Autenticação válida no `gh` com permissões administrativas nos repositórios selecionados.
- A proteção de branches e alguns recursos de segurança podem depender do plano do GitHub e da visibilidade do repositório.
- O script continua processando os demais itens quando uma configuração falha e termina com código diferente de zero se houve falhas. Consulte as mensagens exibidas para identificar recursos não disponíveis ou permissões insuficientes.
- `--all` lista até 1000 repositórios não arquivados do proprietário indicado.

## Observações

- O script funciona melhor em repositórios Git com histórico recente de commits.
- A imagem `change-branch.png` pode ser usada como referência visual para o funcionamento.
