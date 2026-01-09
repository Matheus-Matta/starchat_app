# Starchats

O **Starchats** é uma plataforma open-source de atendimento ao cliente, projetada para empresas que buscam centralizar a comunicação com seus clientes em diversos canais como WhatsApp, Telegram, Messenger e outros, em uma única interface moderna e eficiente.

Este projeto é uma evolução (fork) independente de plataformas de chat open-source, focado em alta performance, design premium e integração nativa com IA e API Evolution.

## 🚀 Principais Funcionalidades

- **Omnichannel**: Centralize WhatsApp, Facebook, Twitter, Email e mais.
- **Visual Premium**: Design moderno, tema violeta nativo e modo escuro otimizado.
- **Alta Performance**: Otimizações no backend e frontend para carregamento rápido.
- **Docker Ready**: Imagens oficiais hospedadas no GHCR para fácil deploy.
- **API Evolution**: Integração robusta para envio de mensagens e automação.

## 🛠️ Instalação com Docker

A maneira mais recomendada de rodar o Starchats é utilizando Docker.

1. **Baixe a imagem oficial:**

   ```bash
   docker pull ghcr.io/matheus-matta/starchat_app:latest
   ```

2. **Configure o arquivo `.env`**:
   Copie o arquivo de exemplo e ajuste suas variáveis de ambiente (Banco de dados, Redis, etc).

   ```bash
   cp .env.example .env
   ```

3. **Inicie os serviços**:
   Utilize o `docker-compose` para subir toda a stack.
   ```bash
   docker-compose up -d
   ```

## 📦 Releases

As versões são geradas automaticamente. Acompanhe as novidades na aba [Releases](https://github.com/Matheus-Matta/starchat_app/releases).

## 📄 Licença

Este projeto é distribuído sob a licença MIT. Consulte o arquivo `LICENSE` para mais detalhes.

---

**Starchats** - Transformando o atendimento ao cliente.
