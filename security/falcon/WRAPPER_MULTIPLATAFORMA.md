# Script Wrappers - Suporte Multiplataforma

Este diretório contém múltiplos wrappers para executar o scanner de imagens Docker com CrowdStrike Falcon, funcionando em **Windows, macOS e Linux**.

## Escolha seu wrapper

### 🐧 Linux / macOS - Recomendado

```bash
# Opção 1: Shell script POSIX portável (recomendado para Unix)
./scan_local_image.sh <image_id> [options]

# Opção 2: Python wrapper universal (funciona em qualquer SO)
./scan_local_image_universal <image_id> [options]
# ou (em alguns sistemas)
python3 ./scan_local_image_universal <image_id> [options]

# Opção 3: Executar diretamente
python3 scan_local_image.py <image_id> [options]
```

### 🪟 Windows - Recomendado

```batch
REM Opção 1: Batch script (recomendado para Windows)
scan_local_image.bat <image_id> [options]

REM Opção 2: Python wrapper universal (multiplataforma)
python scan_local_image_universal <image_id> [options]

REM Opção 3: Executar diretamente
python scan_local_image.py <image_id> [options]

REM Opção 4: PowerShell
powershell -Command "python .\scan_local_image.py <image_id> [options]"
```

### 🍎 macOS (Intel/Apple Silicon)

Mesmas opções que Linux. O script funciona em ambas as arquiteturas.

## Scripts Disponíveis

| Script | SO | Tipo | Descrição |
|--------|-----|------|-----------|
| `scan_local_image` | Linux/macOS | Bash | Shell script legado |
| `scan_local_image.sh` | Linux/macOS | Shell (POSIX) | Shell script portável e robusto |
| `scan_local_image_universal` | Todos | Python | Wrapper Python multiplataforma |
| `scan_local_image_runner.py` | Todos | Python | Wrapper Python alternativo |
| `scan_local_image.bat` | Windows | Batch | Batch script para Windows |
| `scan_local_image.py` | Todos | Python | Script principal (use via wrappers) |

## Exemplos de Uso

### Linux/macOS
```bash
# Scan básico
./scan_local_image.sh 6da180ef5035

# Com opções
./scan_local_image.sh nginx:latest --minimum-severity high --fcs-timeout 1200

# Via Python universal
./scan_local_image_universal gcr.io/k8s-minikube/kicbase:v0.0.50
```

### Windows (PowerShell/CMD)
```batch
# Scan básico
scan_local_image.bat 6da180ef5035

# Com opções
scan_local_image.bat nginx:latest --minimum-severity high

# Via Python
python scan_local_image.py 6da180ef5035

# Via PowerShell
python .\scan_local_image.py 6da180ef5035
```

## Instalação para diferentes SOs

### Linux
```bash
cd scripts/
chmod +x scan_local_image.sh scan_local_image_universal
./scan_local_image.sh <image_id>
```

### macOS
```bash
cd scripts/
chmod +x scan_local_image.sh scan_local_image_universal
./scan_local_image.sh <image_id>
```

### Windows (Git Bash)
```bash
cd scripts/
./scan_local_image.sh <image_id>    # Funciona com Git Bash instalado
```

### Windows (PowerShell/CMD)
```batch
cd scripts
scan_local_image.bat <image_id>
```

## Requisitos

### Todos os SOs
- Python 3.8+
- Docker ou Podman
- AWS CLI configurado (para credenciais)

### Específicos do SO
- **Linux**: bash (geralmente pré-instalado)
- **macOS**: bash ou zsh (pré-instalado)
- **Windows**: Python instalado via https://www.python.org (ou Windows Store)

## Saída

Todos os scripts geram um relatório Markdown em `~/Documents/scan-image/`:
```
scan-6da180ef5035-20260429-112804.md   (18 KB)
```

## Notas de Segurança

✓ Credenciais do Falcon obtidas automaticamente do AWS Secrets Manager
✓ Variáveis sensíveis zeradas após o scan
✓ Arquivos JSON temporários deletados
✓ Apenas Markdown é retido como saída final

## Troubleshooting

### "Python not found"
- **Windows**: Instale de https://www.python.org (marque "Add Python to PATH")
- **macOS**: `brew install python3`
- **Linux**: `apt install python3` ou `yum install python3`

### "Permission denied" (Linux/macOS)
```bash
chmod +x scan_local_image.sh scan_local_image_universal
```

### Batch file not recognized (Windows)
- Use PowerShell em vez de CMD
- Ou execute: `python scan_local_image.py <args>`

### Shell script in Windows
- Use Git Bash: https://gitforwindows.org
- Ou use a versão batch: `scan_local_image.bat`
