# Diagramas Graphviz — graph_as_a_code

Resumo

- Repositório com diagramas em Graphviz (.dot) usados pelo projeto "Crawler documentos públicos".
- Arquivos principais:
  - `horin.dot` — grafo com orientação horizontal (rankdir=LR).
  - `verti.dot` — grafo com orientação vertical (rankdir=TB).
  - `roteiro.md` — notas e escopo do projeto.
  - `LICENSE` — licença do projeto (GPLv3).

Pré-requisitos

- Acesso a um terminal Linux.
- Instalar Graphviz (programa `dot`).

Instalação do Graphviz

- Debian / Ubuntu:

```sh
sudo apt update
sudo apt install graphviz
```

- Fedora:

```sh
sudo dnf install graphviz
```

- Arch Linux:

```sh
sudo pacman -S graphviz
```

- macOS (Homebrew):

```sh
brew install graphviz
```

- Windows (Chocolatey):

```ps1
choco install graphviz
```

Verificar instalação:

```sh
dot -V
# Exemplo: dot - graphviz version 3.0.0 (2025-...)
```

Gerar gráficos a partir dos arquivos .dot

### Gerar PNG individuais:

```sh
dot -Tpng horin.dot -o horin.png
```

![Gráfico Horizontal](horizontal.png)

```sh
dot -Tpng verti.dot -o verti.png
```

![Gráfico Vertical](vertical.png)

### Gerar SVG:

```sh
dot -Tsvg horin.dot -o horin.svg
dot -Tsvg verti.dot -o verti.svg
```

### Gerar PDF:

```sh
dot -Tpdf horin.dot -o horin.pdf
dot -Tpdf verti.dot -o verti.pdf
```

Gerar todos os .dot do diretório (Linux / macOS):

```sh
for f in *.dot; do
  dot -Tpng "$f" -o "${f%.dot}.png"
done
```

Gerar em outro formato (ex.: svg) para todos:

```sh
for f in *.dot; do
  dot -Tsvg "$f" -o "${f%.dot}.svg"
done
```

Usar diferentes motores/layout (quando apropriado)

- dot (hierárquico) — padrão para diagrams direcionados.
- neato, fdp, sfdp, twopi, circo — experimente se o layout não ficar bom:

```sh
neato -Tpng horin.dot -o horin-neato.png
fdp   -Tpng horin.dot -o horin-fdp.png
```

Dicas e resolução de problemas

- Se o arquivo .dot especifica \`rankdir\` e estilos, o \`dot\` respeita essas opções.
- Mensagem de erro comum: "syntax error" — abra o .dot e verifique ponto-e-vírgula e chaves.
- Para ver o resultado rapidamente: xdg-open (Linux) / open (macOS):

```sh
xdg-open horin.png
```

- Se precisar de saída em resolução maior, gere SVG ou aumente DPI via imagem rasterizadora (ex.: convert).

Estrutura sugerida para saída em diretório separado:

```sh
mkdir -p out
for f in *.dot; do
  dot -Tpng "$f" -o "out/${f%.dot}.png"
done
```

Referências

- Manual Graphviz: https://graphviz.org/documentation/
- Comandos \`dot\` e opções: \`man dot\` ou \`dot -?\`

Licença

- Ver arquivo \`LICENSE\` no repositório.
