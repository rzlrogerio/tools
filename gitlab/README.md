# GitLab no k3s

Este diretório contém `bootstrap-devops-k3s.sh`, que configura GitLab CE,
Container Registry, GitLab Runner e Kubernetes Agent no cluster k3s existente.
O Vault existente é configurado e preservado pelo script.

## Pré-requisitos

- k3s ativo e acessível pelo `kubectl`;
- volume `/general-use` montado;
- diretório de dados do k3s configurado em `/general-use/1-lab/k8s/k3s`;
- StorageClass `local-path` apontando para
  `/general-use/1-lab/k8s/k3s/storage`;
- Vault inicializado, com o Secret `vault-credentials` no namespace `vault`;
- `kubectl`, `helm`, `jq`, `curl`, `openssl`, `findmnt`, `ip` e `hostname`.

## Instalação ou retomada

Execute a partir deste diretório:

```bash
./bootstrap-devops-k3s.sh --recreate-gitlab
```

`--recreate-gitlab` remove e cria novamente o namespace `gitlab`. Isso apaga
os recursos e dados armazenados nos volumes desse namespace. O Vault não é
removido.

Se uma execução parar depois de instalar o GitLab, corrija a causa e retome
sem recriar o namespace:

```bash
./bootstrap-devops-k3s.sh --resume-gitlab
```

Ao terminar, o script informa os endereços do GitLab, Registry e Vault. Por
padrão, os endereços usam o IP do host com `nip.io`; o IP e o domínio podem ser
ajustados pelas variáveis `DEVOPS_HOST_IP` e `DEVOPS_DOMAIN`.

## Acesso ao GitLab

- **Web do GitLab:** [http://gitlab.192.168.68.116.nip.io](http://gitlab.192.168.68.116.nip.io)
- **Container Registry:** [http://registry.192.168.68.116.nip.io](http://registry.192.168.68.116.nip.io)
- **Vault:** [http://vault.192.168.68.116.nip.io](http://vault.192.168.68.116.nip.io)
- **Usuário inicial:** `root`
- **Senha inicial:** gerada aleatoriamente pelo script e guardada em um Secret
  Kubernetes. Não copie a senha para este README nem a versione em texto puro.

O script deriva o domínio padrão do IP do host. Se o IP mudar, o endereço pode
ser diferente; consulte os endereços impressos ao final da execução ou defina
`DEVOPS_HOST_IP` / `DEVOPS_DOMAIN` antes de executar o script.

### Configurar o arquivo hosts

Se os endereços `nip.io` não resolverem na sua rede, adicione o IP do servidor
e os domínios do **Web do GitLab, Container Registry e Vault** ao arquivo
`hosts` do computador cliente:

```bash
echo "192.168.68.116 gitlab.192.168.68.116.nip.io registry.192.168.68.116.nip.io vault.192.168.68.116.nip.io" \
  | sudo tee -a /etc/hosts
```

No Windows, abra o Bloco de Notas como administrador e edite
`C:\Windows\System32\drivers\etc\hosts`, adicionando esta linha:

```text
192.168.68.116 gitlab.192.168.68.116.nip.io registry.192.168.68.116.nip.io vault.192.168.68.116.nip.io
```

Se o IP do servidor mudar, atualize o IP e os três domínios para corresponder
aos endereços informados pelo script.

Recupere a senha inicial no terminal com:

```bash
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

Esse comando mostra a senha inicial armazenada no cluster. Se a senha do
usuário `root` tiver sido alterada posteriormente no GitLab, a senha atual
deverá ser usada; o Secret contém somente a senha inicial.

Os tokens de bootstrap, Runner e Agent também ficam em Secrets Kubernetes e
não devem ser copiados para este README.

## Verificação

```bash
kubectl get pods -n gitlab
kubectl get pv
```

Os pods dos serviços devem estar prontos (ou os jobs concluídos), e os PVs do
GitLab devem usar caminhos abaixo de
`/general-use/1-lab/k8s/k3s/storage`.
