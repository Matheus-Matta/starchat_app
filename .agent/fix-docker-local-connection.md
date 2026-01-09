# 🔧 Guia: Rodar Sidekiq/Rails Localmente com Docker

## ⚠️ Problema Atual

Você está rodando:

- ✅ **PostgreSQL** no Docker (porta `5434`)
- ✅ **Redis** no Docker (porta `6379`)
- ✅ **Evolution API** no Docker (porta `8080`)
- ❌ **Sidekiq** localmente (host)

Mas o `.env` está configurado para conexão **dentro** do Docker (`postgres:5432`), causando erro de conexão.

---

## ✅ Solução

### Opção 1: Ajustar .env para Localhost (RECOMENDADO)

Edite seu arquivo `.env` na raiz do projeto com estas configurações:

```bash
# ===== DATABASE =====
# Usar localhost:5434 (porta mapeada do Docker)
POSTGRES_HOST=localhost
POSTGRES_PORT=5434
POSTGRES_DATABASE=chatwoot_dev
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=<sua_senha>

# ===== REDIS =====
# Usar localhost:6379 (porta mapeada do Docker)
REDIS_URL=redis://:<sua_senha>@localhost:6379/0
REDIS_PASSWORD=<sua_senha>

# ===== EVOLUTION API =====
# Evolution está no Docker porta 8080
EVOLUTION_BASE_URL=http://localhost:8080
=<sua_api_key>

# ===== RAILS =====
RAILS_ENV=production
RAILS_MAX_THREADS=5
SECRET_KEY_BASE=<sua_secret_key>

# ===== OUTROS =====
FRONTEND_URL=http://localhost:3000
ACTIVE_STORAGE_SERVICE=local
RAILS_LOG_TO_STDOUT=true
LOG_LEVEL=info
```

### Comandos para Verificar

```bash
# 1. Verificar containers rodando
docker ps

# 2. Testar conexão Postgres
psql -h localhost -p 5434 -U postgres -d chatwoot_dev

# 3. Testar conexão Redis
redis-cli -h localhost -p 6379 -a <sua_senha> ping

# 4. Testar Rails console
bundle exec rails console

# 5. Rodar Sidekiq
bundle exec sidekiq -e production -C config/sidekiq.yml
```

---

### Opção 2: Rodar TUDO no Docker

Se preferir rodar tudo no Docker (mais simples):

```bash
# Parar Sidekiq local
# Ctrl+C no terminal do Sidekiq

# Ajustar docker-compose para incluir Sidekiq e Rails
# Usar docker-compose.prod.yml
cd /home/matheus/starchat_app
docker-compose -f docker-compose.prod.yml up -d
```

---

## 🔍 Diagnóstico Rápido

### Erro atual:

```
could not translate host name "postgres" to address
```

**Causa:** `.env` tem `POSTGRES_HOST=postgres` mas você está rodando fora do Docker.

**Solução:** Mudar para `POSTGRES_HOST=localhost` e `POSTGRES_PORT=5434`

---

### Verificar Configurações Atuais

```bash
# Ver qual host está configurado
cat .env | grep POSTGRES_HOST

# Deve mostrar: POSTGRES_HOST=localhost (para rodar local)
# OU: POSTGRES_HOST=postgres (para rodar no Docker)
```

---

## 📝 Arquivo .env Correto para Rodar LOCAL

Copie e cole no seu `.env`:

```bash
# DATABASE - Conectar no Docker via localhost
POSTGRES_HOST=localhost
POSTGRES_PORT=5434
POSTGRES_DATABASE=chatwoot_dev
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=senha123

# REDIS - Conectar no Docker via localhost
REDIS_URL=redis://:senha123@localhost:6379/0
REDIS_PASSWORD=senha123

# EVOLUTION API
EVOLUTION_BASE_URL=http://localhost:8080
AUTHENTICATION_API_KEY=c8Ishl6dVDZTORfquwzLIKIMB

# RAILS
RAILS_ENV=production
SECRET_KEY_BASE=$(rake secret)
RAILS_MAX_THREADS=5

# OUTROS
FRONTEND_URL=http://localhost:3000
ACTIVE_STORAGE_SERVICE=local
RAILS_LOG_TO_STDOUT=true
LOG_LEVEL=info
```

---

## ⚡ Quick Fix (Linha de Comando)

Execute isso no terminal:

```bash
cd /home/matheus/starchat_app

# Backup do .env atual
cp .env .env.backup

# Ajustar POSTGRES_HOST
sed -i 's/POSTGRES_HOST=postgres/POSTGRES_HOST=localhost/g' .env

# Ajustar POSTGRES_PORT (se necessário)
grep -q "POSTGRES_PORT" .env || echo "POSTGRES_PORT=5434" >> .env
sed -i 's/POSTGRES_PORT=5432/POSTGRES_PORT=5434/g' .env

# Ajustar REDIS_URL
sed -i 's|redis://redis:6379|redis://localhost:6379|g' .env
sed -i 's|redis://:.*@redis:|redis://:senha123@localhost:|g' .env

# Verificar
echo "=== POSTGRES CONFIG ==="
cat .env | grep POSTGRES

echo "=== REDIS CONFIG ==="
cat .env | grep REDIS

# Tentar novamente
bundle exec sidekiq -e production -C config/sidekiq.yml
```

---

## 🎯 Resumo

| O que         | Onde está    | Como acessar do HOST |
| ------------- | ------------ | -------------------- |
| PostgreSQL    | Docker       | `localhost:5434`     |
| Redis         | Docker       | `localhost:6379`     |
| Evolution API | Docker       | `localhost:8080`     |
| Sidekiq       | HOST (local) | N/A                  |
| Rails         | HOST (local) | `localhost:3000`     |

**.env deve usar `localhost` para conectar nos containers!**

---

## 🚨 Se nada funcionar

```bash
# 1. Parar tudo
docker-compose -f docker/develop/docker-compose.yml down

# 2. Subir só o necessário
docker-compose -f docker/develop/docker-compose.yml up -d postgres redis evolution

# 3. Verificar portas
docker ps

# 4. Verificar conectividade
nc -zv localhost 5434  # Postgres
nc -zv localhost 6379  # Redis
nc -zv localhost 8080  # Evolution

# 5. Se tudo OK, ajustar .env e tentar Sidekiq
```

---

**Data:** 2026-01-06  
**Projeto:** Starchat App  
**Branch:** change-base64-evolution
