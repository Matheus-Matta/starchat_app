# Guia: Automação de Docker e Versionamento com GitHub Actions

Este guia descreve como configurar qualquer repositório GitHub para construir automaticamente imagens Docker e criar Releases sempre que uma nova tag de versão (ex: `v1.0.0`) for enviada.

## 📋 Pré-requisitos

1.  Ter um **Dockerfile** válido na raiz do projeto.
2.  O repositório deve estar no **GitHub**.
3.  Opcional: Para Docker Hub, configurar Secrets. Este guia foca no **GitHub Container Registry (GHCR)**.

---

## 🛠️ Como Testar (Antes de Enviar)

Antes de criar uma tag e disparar o processo oficial, recomenda-se testar se o build está funcionando na sua máquina ou via Pull Request.

### 1. Teste Local (Na sua máquina)

Rode este comando no terminal para garantir que o Dockerfile não tem erros:

```bash
docker build -t teste-local .
```

Se terminar com sucesso, está seguro para enviar.

### 2. Teste via Pull Request (Automático)

Com a configuração de produção abaixo, sempre que você abrir um **Pull Request** para a branch `main`, o GitHub vai rodar o build **sem fazer o upload** da imagem. Isso serve para validar o código antes de integrar.

---

## 🚀 Configuração de Produção (Resumo)

Basta criar um único arquivo no seu projeto com o conteúdo abaixo.

**Caminho do arquivo:** `.github/workflows/docker-publish.yml`

### Template do Arquivo (Produção com Cache e PR Checks)

```yaml
name: Build & Push (GHCR)

on:
  push:
    branches: ['main']
    tags: ['v*']
  pull_request:
    branches: ['main']

permissions:
  contents: write
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Metadata (Tags)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest,enable=${{ startsWith(github.ref, 'refs/tags/') }}
            type=ref,event=branch
            type=ref,event=tag
            type=sha,format=long

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v6
        with:
          context: .
          # Só faz push se NÃO for um Pull Request
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          # Cache inteligente do GitHub Actions para builds rápidos
          cache-from: type=gha
          cache-to: type=gha,mode=max

  release:
    needs: build
    runs-on: ubuntu-latest
    # Só roda release se for uma TAG de versão (v...)
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
```

---

## 🤖 Prompt para IA (Para pedir isso no futuro)

Se você quiser pedir para uma IA configurar isso para você em outro projeto, use o seguinte prompt atualizado:

> "Configure um workflow do GitHub Actions de nível de produção para Docker.
>
> **Requisitos:**
>
> 1. O build deve rodar em pushes na main, tags (v\*) e em Pull Requests.
> 2. **Pull Requests:** Devem apenas fazer o build (teste), SEM fazer push para o registro.
> 3. **Push/Tags:** Devem fazer o build E o push para o **GitHub Container Registry (ghcr.io)**.
> 4. Use **Docker Buildx Cache (gha)** para acelerar o processo.
> 5. A imagem deve ter tags para a versão (ex: v1.0.0), branch, sha longo e 'latest' (apenas releases).
> 6. Se for uma tag de release, crie automaticamente uma **GitHub Release** com notas."

---

## 📦 Como Lançar uma Versão

1.  **Trabalhe no código e envie para a main:**

    ```bash
    git add .
    git commit -m "feat: novas funcionalidades"
    git push origin main
    ```

2.  **Lançar Versão:**

    ```bash
    git tag -a v1.0.1 -m "Versão 1.0.1"
    git push origin v1.0.1
    ```

3.  **Resultado:**
    - Imagem no GHCR: `ghcr.io/seu-usuario/seu-repo:v1.0.1` e `:latest`.
    - Release criada no GitHub com changelog.
