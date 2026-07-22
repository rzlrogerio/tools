# Ferramentas Úteis

Este repositório contém uma coleção de scripts utilitários desenvolvidos para facilitar tarefas cotidianas no terminal.

## Estrutura do Repositório

Cada utilitário possui um diretório dedicado contendo o respectivo script e instruções detalhadas de configuração e uso:

*   [**Dicas (dicas.sh)**](dicas/README.md): Atalho para visualização e edição rápida de anotações e dicas de comandos de terminal de forma interativa.
*   [**Certificados (valida-cert.sh)**](certificados/README.md): Utilitário de terminal rápido para consultar e validar datas de expiração e emissores de certificados SSL de domínios públicos.

---

## Disponibilizar os Scripts Globalmente (PATH)

Para executar qualquer um dos scripts de qualquer lugar no seu terminal, crie links simbólicos deles dentro de `~/bin`:

```bash
# Garantir que o diretório ~/bin existe
mkdir -p ~/bin

# Adicionar o script dicas
ln -sf "$(pwd)/dicas/dicas.sh" ~/bin/dicas
chmod +x ~/bin/dicas

# Adicionar o script valida-cert
ln -sf "$(pwd)/certificados/valida-cert.sh" ~/bin/valida-cert
chmod +x ~/bin/valida-cert
```

Certifique-se de que o diretório `~/bin` esteja no seu `$PATH` (configurado em seu `~/.bashrc` ou `~/.zshrc`):

```bash
export PATH="$HOME/bin:$PATH"
```
