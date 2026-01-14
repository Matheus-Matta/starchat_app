# 🧹 Limpeza de Cache e Variáveis de Ambiente

Este documento explica como evitar problemas com cache de variáveis de ambiente no WSL/Linux.

## 🔴 Problema

O Rails/Ruby cacheia variáveis de ambiente do `.env` em diversos lugares:

- `tmp/cache` - Cache do Rails
- `tmp/bootsnap*` - Cache do Bootsnap
- `.bundle/cache` - Cache do Bundler
- Variáveis ENV do shell atual
- Spring preloader (se ativo)

Isso pode causar:

- `.env` atualizado mas Rails usando valores antigos
- Erro de conexão com banco mesmo com credenciais corretas
- Redis/PostgreSQL não conectando

## ✅ Solução Automática

### 1. Limpeza Manual (quando necessário)

```bash
# Limpar TUDO de uma vez
./script/clear-all-cache.sh
```

### 2. Configuração Permanente

```bash
# Configurar limpeza automática no login
./script/setup-env-cleanup.sh

# Ativar agora
source ~/.bashrc
```

### 3. Alias Útil

Depois de configurar, você pode usar:

```bash
# De qualquer pasta
clear-rails-cache
```

---

## 📝 Scripts Disponíveis

### `script/clear-all-cache.sh`

Limpa:

- ✅ tmp/cache, tmp/pids, tmp/sockets
- ✅ Bundle cache
- ✅ Spring (se rodando)
- ✅ Bootsnap cache
- ✅ Variáveis ENV do shell
- ✅ Cache do rbenv
- ✅ Logs antigos (>7 dias)

### `script/setup-env-cleanup.sh`

Configura:

- ✅ Limpeza automática de ENV ao fazer login
- ✅ Alias `clear-rails-cache`
- ✅ Adiciona ao `~/.bashrc`

---

## 🚀 Workflow Recomendado

### Quando alterar `.env`:

```bash
# 1. Edite o .env
nano .env

# 2. Limpe todo cache
./script/clear-all-cache.sh

# 3. Recarregue o shell (opcional mas recomendado)
exec bash

# 4. Teste a conexão
bundle exec rails console
```

### Alternativa Rápida:

```bash
# Limpar e recarregar de uma vez
clear-rails-cache && exec bash
```

---

## 🔍 Verificar Configuração Atual

```bash
# Ver variáveis ENV carregadas
env | grep -E "(POSTGRES|REDIS)"

# Ver o que está no .env
grep -E "^(POSTGRES|REDIS)" .env | grep -v "^#"

# Testar conexão PostgreSQL
PGPASSWORD=sua_senha psql -h localhost -p 5432 -U postgres -d starchat_production -c "SELECT version();"

# Testar conexão Redis
redis-cli -h localhost -p 6379 -a sua_senha ping
```

---

## ⚠️ Troubleshooting

### Problema: Rails ainda usa valores antigos

```bash
# Solução 1: Limpar cache + matar processos
./script/clear-all-cache.sh
pkill -f "rails server"
pkill -f sidekiq

# Solução 2: Recarregar shell completamente
exec bash

# Solução 3: Reiniciar terminal WSL
exit
# Abrir novo terminal
```

### Problema: Bootsnap causando cache

```bash
# Desabilitar temporariamente
DISABLE_BOOTSNAP=1 bundle exec rails console

# Ou remover completamente
rm -rf tmp/bootsnap*
```

### Problema: Spring não para

```bash
# Forçar parada
pkill -9 -f spring
rm -rf tmp/pids/spring*

# Desabilitar permanentemente
echo "DISABLE_SPRING=1" >> ~/.bashrc
```

---

## 📊 Checklist Pós-Alteração .env

- [ ] Editei o `.env`
- [ ] Rodei `./script/clear-all-cache.sh`
- [ ] Recarreguei o shell com `exec bash` ou `source ~/.bashrc`
- [ ] Verifiquei com `env | grep POSTGRES`
- [ ] Testei conexão manual: `PGPASSWORD=... psql ...`
- [ ] Testei com Rails: `bundle exec rails console`
- [ ] Tudo funcionando? ✅

---

## 🎯 Boas Práticas

1. **Sempre limpar cache após editar `.env`**
2. **Usar `exec bash` para recarregar shell completamente**
3. **Verificar variáveis ENV antes de rodar Rails**
4. **Manter apenas UM arquivo `.env` (sem `.env.local`, `.env.development`)**
5. **Documentar mudanças em `.env.example`**

---

## 📚 Arquivos Relacionados

```
script/
├── clear-all-cache.sh          # Limpa todo cache
├── setup-env-cleanup.sh        # Configura limpeza automática
├── fix-env-for-local.sh        # Ajusta .env para Docker
└── use-native-services.sh      # Ajusta .env para serviços nativos

.env                            # Configuração principal (NÃO commitar)
.env.example                    # Template (commitar)
```

---

**Última atualização:** 2026-01-06  
**Autor:** Configuração automática Starchat App
