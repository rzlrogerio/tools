# SRE Tools - Zsh Configuration

Este diretório contém ferramentas e configurações personalizadas para o shell Zsh, desenvolvidas especificamente para facilitar o trabalho de SRE (Site Reliability Engineering) com clusters Kubernetes.

## Estrutura do Diretório

```
zsh/
├── bin/
│   └── get-context.sh        # Script para obter contexto do Kubernetes
├── theme/
│   ├── rogerio.png           # Screenshot do tema Zsh
│   └── rogerio.zsh-theme     # Tema personalizado para Zsh (renomeie para SEU_USER.zsh-theme)
└── README.md                 # Este arquivo
```

## Componentes

### 1. Script `get-context.sh`

**Localização:** `bin/get-context.sh`

**Propósito:** Extrai e exibe informações sobre o contexto atual do Kubernetes configurado em `~/.kube/config`.

**Funcionalidades:**

- Identifica o contexto Kubernetes ativo
- Determina o ambiente (Prod, QA, Sandbox)
- Mostra o namespace atual
- Aplica cores baseadas no tipo de ambiente:
  - 🟢 **Verde**: Ambientes de desenvolvimento, QA ou sandbox
  - 🔴 **Vermelho**: Ambiente de produção
  - **Padrão**: Outros ambientes

**Uso:**

```bash
./bin/get-context.sh
```

**Exemplo de saída:**

```
QA: my-cluster-dev (default)
Prod: vanilla (production)
```

### 2. Tema Zsh `rogerio.zsh-theme`

**Localização:** `theme/rogerio.zsh-theme`

**Nota:** Este é um tema de exemplo. Você pode renomeá-lo para o seu nome de usuário ou usar como está.

**Screenshot do tema:** `theme/rogerio.png`

**Propósito:** Tema personalizado para Oh My Zsh que fornece um prompt rico em informações para SREs.

**Características do Prompt:**

#### Linha Superior:

- **Virtual Environment**: Mostra ambiente Python ativo (se houver)
- **Diretório Atual**: Caminho do diretório de trabalho
- **Data/Hora**: Timestamp atual
- **Informações Git**:
  - Branch atual
  - Status (✔ limpo / ✘ modificado)
  - Commit hash
  - Contador de arquivos modificados
- **Contexto Kubernetes**: Integração com `get-context.sh`
- **Emoji**: 🐧 (Tux) e ¯\\_(ツ)_/¯

#### Linha Inferior:

- **Código de Retorno**: Mostra erros do comando anterior
- **Prompt Character**: 🔶

**Exemplo visual:**

```
╭─ ~/projects/sretools 🗓️ Tue, 29 Oct 2024 14:30 | git: main ✔ abc1234 (2 files changed) ¯\_(ツ)_/¯ Prod: prod-cluster (production) 🐧
╰─🔶
```

## Instalação e Configuração

### Pré-requisitos

1. **Oh My Zsh** instalado
2. **kubectl** configurado com acesso aos clusters
3. **Git** para funcionalidades do tema

### Configuração do Tema

1. Copie o arquivo de tema para o diretório de temas do Oh My Zsh:

```bash
# Opção 1: Manter o nome original
cp theme/rogerio.zsh-theme ~/.oh-my-zsh/themes/

# Opção 2: Renomear para seu próprio nome de usuário
cp theme/rogerio.zsh-theme ~/.oh-my-zsh/themes/TROQUE_SEU_USER.zsh-theme
```

2. Edite seu `~/.zshrc` para usar o tema:

```bash
# Se manteve o nome original
ZSH_THEME="rogerio"

# Se renomeou para seu usuário
ZSH_THEME="TROQUE_SEU_USER"
```

3. Recarregue o terminal:

```bash
source ~/.zshrc
```

### Configuração do Script get-context.sh

1. Torne o script executável:

```bash
chmod +x bin/get-context.sh
```

2. Adicione o diretório `bin` ao seu PATH no `~/.zshrc`:

```bash
export PATH="$PATH:/path/to/sretools/zsh/bin"
```

## Personalização

### Modificando Cores

No arquivo `rogerio.zsh-theme`, você pode personalizar as cores alterando os códigos FG (foreground):

```bash
# Exemplos de cores disponíveis
$FG[226]  # Amarelo
$FG[135]  # Roxo
$FG[040]  # Verde
$FG[202]  # Laranja
$FG[033]  # Azul claro
```

### Adicionando Novos Ambientes

No script `get-context.sh`, você pode adicionar novos padrões de ambiente:

```bash
if [[ "$context" == *"-staging"* ]]
then
    color="\033[33m" # Yellow text
    environment="Staging:"
fi
```

## Troubleshooting

### Problemas Comuns

1. **Script não executa**: Verifique se o arquivo tem permissões de execução
2. **Tema não carrega**: Confirme se o arquivo está no diretório correto de temas
3. **Contexto K8s não aparece**: Verifique se o arquivo `~/.kube/config` existe e está válido
4. **Cores não funcionam**: Certifique-se de que o terminal suporta cores ANSI

### Debug

Para debugar o script `get-context.sh`, adicione modo verbose:

```bash
bash -x bin/get-context.sh
```

## Contribuição

Para contribuir com melhorias:

1. Teste as modificações em ambiente não-produtivo
2. Mantenha compatibilidade com versões anteriores
3. Documente mudanças significativas
4. Considere impacto em performance do prompt

## Suporte

Para dúvidas ou problemas, consulte:

- Documentação do Oh My Zsh
- Documentação do kubectl
