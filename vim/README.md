# Vim como IDE no Debian e Ubuntu

Este diretório automatiza a configuração do Vim a partir do `.vimrc` usado
neste ambiente. O setup mantém as opções e os plugins configurados para
Python, Go, Rust, shell, YAML, Terraform, Kubernetes, Markdown, LaTeX e Git.

## Instalação

Em Debian, Ubuntu ou derivados, clone este repositório e execute:

```bash
cd tools/vim
./setup-vim.sh
```

O script:

1. Confere a distribuição e o suporte `+spell` do Vim.
2. Instala `vim-nox` ou `git` via APT somente quando necessário. Pode solicitar
   a senha do `sudo`.
3. Instala a configuração versionada como `~/.vimrc`. Se já houver outro
   `.vimrc`, preserva uma cópia com o nome `~/.vimrc.backup.*` antes de
   substituí-lo.
4. Instala a sintaxe YAML personalizada em `~/.vim/yaml.vim`.
5. Reaproveita o dicionário português do Vim existente. Se não existir,
   instala `hunspell-pt-br` e gera `~/.vim/spell/pt.utf-8.spl`.
6. Instala o Vundle e os plugins declarados no `.vimrc`.
7. Informa quais ferramentas opcionais de lint e desenvolvimento não foram
   encontradas.

O setup precisa de acesso à rede para baixar os plugins. Ele não instala
automaticamente todas as ferramentas de linguagem: `flake8`, `yamllint`,
`shellcheck`, `go`, `gopls`, `kubectl`, `terraform`, `terragrunt` e o linter
personalizado `~/bin/camelcase_linter.sh` são opcionais e dependem das
linguagens que você usa. O plugin YouCompleteMe também pode precisar de
compilação ou de configuração adicional depois da instalação.
Se a instalação de plugins falhar, o setup mostra o log salvo em
`~/.vim/vundle-install.log` e o log detalhado do Vim em
`~/.vim/vundle-install.verbose.log`.

## Verificação

```bash
./setup-vim.sh --check
```

Esse modo não altera arquivos nem instala pacotes. Verifica o Vim com suporte
ortográfico, o `.vimrc`, o Vundle e o dicionário português.

No Vim, `:set spell?` mostra se a correção está ativa. `]s` e `[s` navegam
entre palavras sinalizadas; `z=` apresenta sugestões e `zg` adiciona a palavra
sob o cursor ao dicionário pessoal.

## O que a configuração habilita

- Numeração absoluta e relativa, destaque de linha/coluna, busca incremental,
  divisões e navegação entre janelas.
- Dobras de código e indentação configurada para Python, JavaScript, HTML,
  CSS e YAML.
- Correção ortográfica em português (`pt_br`), incluindo Markdown, texto e
  LaTeX.
- Cabeçalho automático ao criar arquivos Python, Perl, Ruby, Go, Java e Rust.
  Python, Perl e Ruby também recebem um shebang apropriado. Personalize o nome
  do autor definindo `g:vim_header_author` no `.vimrc`.
- Plugins de navegação de arquivos, Git, autocomplete, lint, sintaxe,
  formatação e suporte às linguagens listadas no `.vimrc`.

## Pacotes verificados neste ambiente

Na máquina em que o script foi preparado, foi encontrado Vim 9.2 com `+spell`,
o pacote `vim-nox`, Vundle e o plugin YouCompleteMe. O arquivo de dicionário
`~/.vim/spell/pt.utf-8.spl` já estava instalado e foi validado pelo Vim.
Também estavam instalados `aspell` e o dicionário Hunspell de inglês, mas não
o pacote `hunspell-pt-br`; por isso, o script só instala esse pacote se não
encontrar o dicionário português do Vim.

## Arquivos

- `.vimrc`: configuração versionada baseada no `.vimrc` existente.
- `yaml.vim`: sintaxe YAML personalizada carregada pela configuração.
- `setup-vim.sh`: instalação, configuração e verificação.
