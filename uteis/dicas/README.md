# Dicas

Script simples para leitura e edição rápida de dicas/anotações de comandos utilizando o utilitário `less`.

## Configuração Inicial

O script faz referência a um diretório e arquivo localizados em `~/1-dicas/1-dicas.txt`. Antes de executar o script pela primeira vez, crie essa estrutura executando o seguinte comando no terminal:

```bash
mkdir -p ~/1-dicas && touch ~/1-dicas/1-dicas.txt
```

## Como Utilizar

### 1. Modo de Leitura

Para abrir suas dicas cadastradas no modo de visualização rápida, execute o script:

```bash
./dicas.sh
```

Isso abrirá o arquivo com o utilitário `less`, permitindo que você navegue pelo arquivo (usando as setas do teclado ou `Page Up`/`Page Down`) e pesquise por termos de forma rápida e insensível a maiúsculas/minúsculas (graças ao parâmetro `-i`).

### 2. Modo de Edição (Adicionando Novos Comandos)

Enquanto estiver visualizando o arquivo dentro do `less`, você pode entrar diretamente no modo de edição pressionando a tecla:

```text
v
```

O `less` abrirá o arquivo no editor de texto padrão do seu terminal (geralmente `vi`/`vim` ou `nano`).

#### Salvando e Saindo no Editor

##### Se o editor aberto for o Vi/Vim:
1. Pressione `Esc` para garantir que está no modo de comandos.
2. Digite `:wq` (ou `:x`) e pressione `Enter` para salvar e sair (ou pressione `Shift + Z + Z` / `ZZ`).

##### Se o editor aberto for o Nano:
1. Pressione `Ctrl + O` e confirme com `Enter` para salvar as alterações.
2. Pressione `Ctrl + X` para sair do editor.

### 3. Visualizando o Resultado

Após salvar e sair do editor, você retornará automaticamente para a tela de visualização do `less`. O novo comando ou anotação que você adicionou já estará visível na tela e pronto para ser pesquisado na nova busca.

Para sair completamente do `less` e voltar ao terminal, pressione a tecla:

```text
q
```

---

## Exemplo Prático de Uso (Fluxo Completo)

Imagine que você precisou descobrir os cabeçalhos HTTP de uma URL e descobriu que o `curl` pode te ajudar. Você executou o comando no terminal:

```bash
curl -I https://google.com
```

E obteve a seguinte resposta:

```text
HTTP/2 301 
location: https://www.google.com/
content-type: text/html; charset=UTF-8
content-security-policy-report-only: object-src 'none';base-uri 'self';script-src 'nonce-VDLGjPy7AcfnQ0pMZfs0nA' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp
date: Wed, 22 Jul 2026 07:50:02 GMT
expires: Fri, 21 Aug 2026 07:50:02 GMT
cache-control: public, max-age=2592000
server: gws
content-length: 220
x-xss-protection: 0
x-frame-options: SAMEORIGIN
alt-svc: h3=":443"; ma=2592000,h3-29=":443"; ma=2592000
```

Como este é um comando muito útil e difícil de memorizar completamente, você decide salvá-lo no seu arquivo de dicas para consultas futuras:

1. **Abra o visualizador:**
   ```bash
   ./dicas.sh
   ```
2. **Entre no modo de edição:** Pressione a tecla `v`.
3. **Escreva sua nova dica** (no editor de texto que abrir):
   ```text
   # Como descobrir os cabeçalhos de uma URL usando curl:
   curl -I https://google.com
   ```
4. **Salve e saia** (usando `:wq` no vi/vim ou `Ctrl+O` e `Ctrl+X` no nano).
5. **Pronto!** Na próxima vez que você rodar `./dicas.sh`, basta buscar por `curl` ou `cabeçalho` usando a barra (`/`) dentro do `less` para visualizar o comando salvo instantaneamente.

---

## Disponibilizar Script Globalmente (PATH)

Para executar o script `dicas` de qualquer local do terminal sem precisar digitar o caminho completo `./dicas.sh`, você pode adicioná-lo ao diretório `~/bin` do seu usuário:

1. Garanta que o diretório `~/bin` existe:
   ```bash
   mkdir -p ~/bin
   ```
2. Crie um link simbólico ou copie o script para `~/bin` (dando permissão de execução):
   ```bash
   ln -sf "$(pwd)/dicas.sh" ~/bin/dicas
   chmod +x ~/bin/dicas
   ```
3. Certifique-se de que o diretório `~/bin` está no seu `$PATH` (geralmente configurado no seu `~/.bashrc` ou `~/.zshrc` por padrão em muitas distribuições Linux):
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```
