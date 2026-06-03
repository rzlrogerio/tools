# Git Tools

Este diretório contém um utilitário para facilitar a troca de branches em repositórios Git.

## Arquivos

- `change-branch` — script Bash para selecionar e trocar de branch usando `git` e `fzf`
- `change-branch.png` — imagem ilustrativa relacionada ao script

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

## Observações

- O script funciona melhor em repositórios Git com histórico recente de commits.
- A imagem `change-branch.png` pode ser usada como referência visual para o funcionamento.
