# Validador de Certificados SSL

Script prático para consultar e validar informações básicas de certificados SSL de domínios na internet.

## Pré-requisitos

O script utiliza o utilitário `openssl` para conectar e extrair os dados do certificado. Certifique-se de que ele está instalado em seu sistema (geralmente já vem pré-instalado na maioria das distribuições Linux).

## Como Utilizar

Execute o script passando o domínio desejado como argumento (sem o protocolo `https://`).

### Exemplo 1: Google

```bash
./valida-cert.sh google.com
```

#### Exemplo de Saída:
```text
Connecting to 172.217.29.46
depth=2 C=US, O=Google Trust Services LLC, CN=GTS Root R1
verify return:1
depth=1 C=US, O=Google Trust Services, CN=WR2
verify return:1
depth=0 CN=*.google.com
verify return:1
DONE
issuer=C=US, O=Google Trust Services, CN=WR2
subject=CN=*.google.com
notBefore=Jun 29 08:37:25 2026 GMT
notAfter=Sep 21 08:37:24 2026 GMT
```

### Exemplo 2: Microsoft

```bash
./valida-cert.sh microsoft.com
```

#### Exemplo de Saída:
```text
Connecting to 20.112.52.29
depth=2 C=IE, O=Baltimore, OU=CyberTrust, CN=Baltimore CyberTrust Root
verify return:1
depth=1 C=US, O=Microsoft Corporation, CN=Microsoft Azure TLS Issuing CA 01
verify return:1
depth=0 CN=microsoft.com
verify return:1
DONE
issuer=C=US, O=Microsoft Corporation, CN=Microsoft Azure TLS Issuing CA 01
subject=CN=microsoft.com
notBefore=Oct 15 18:20:10 2025 GMT
notAfter=Oct 15 18:20:10 2026 GMT
```

---

## Disponibilizar Script Globalmente (PATH)

Para executar o script `valida-cert` de qualquer local do terminal sem precisar digitar o caminho completo `./valida-cert.sh`, você pode adicioná-lo ao diretório `~/bin` do seu usuário:

1. Garanta que o diretório `~/bin` existe:
   ```bash
   mkdir -p ~/bin
   ```
2. Crie um link simbólico ou copie o script para `~/bin` (dando permissão de execução):
   ```bash
   ln -sf "$(pwd)/valida-cert.sh" ~/bin/valida-cert
   chmod +x ~/bin/valida-cert
   ```
3. Certifique-se de que o diretório `~/bin` está no seu `$PATH` (geralmente configurado no seu `~/.bashrc` ou `~/.zshrc` por padrão em muitas distribuições Linux):
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```
