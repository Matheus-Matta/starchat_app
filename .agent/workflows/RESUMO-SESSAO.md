# 🚨 Configuração Simplificada para Desenvolvimento

**Problema:** PostgreSQL não aceita a senha configurada.

**Solução Rápida:** Configure o `.env` corretamente OU ajuste `pg_hba.conf`.

## ✅ Solução Mais Simples

Execute isso no terminal:

```bash
# 1. Pare tudo
pkill -f sidekiq
pkill -f rails

# 2. Configure senha do postgres
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"

# 3. Teste conexão
PGPASSWORD=postgres psql -h localhost -U postgres -d postgres -c "SELECT version();"

# 4. Se funcionar, configure .env
cat > .env.temp << 'EOF'
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot_dev
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=postgres
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=
RAILS_ENV=development
EOF

# 5. Backup e substitua
cp .env .env.backup.final
cat .env.temp >> .env
rm .env.temp

# 6. Criar banco
bundle exec rails db:create db:migrate

# 7. Rodar Sidekiq
bundle exec sidekiq -C config/sidekiq.yml
```

## 🎯 Resumo do que fizemos hoje

### ✅ Completado:

1. ✅ Criou branch `change-base64-evolution`
2. ✅ Criou testes para `SendMessageService`
3. ✅ Criou testes para `MediaAttach`
4. ✅ Criou documentação completa
5. ✅ Instalou Redis localmente
6. ✅ Configurou `.env` para serviços nativos

### ⏸️ Pendente (problema de conexão Postgres):

- Configurar autenticação PostgreSQL
- Criar banco de dados
- Rodar migrações
- Testar Sidekiq

## 💡 Próximos Passos

**Opção 1: Resolver Postgres (mais trabalhoso)**

- Ajustar `pg_hba.conf`
- Recarregar PostgreSQL
- Tentar novamente

**Opção 2: Usar Docker apenas para Postgres/Redis (RECOMENDO)**

```bash
# Subir só Postgres e Redis no Docker
cd docker/develop
docker-compose up -d postgres redis

# Ajustar .env para localhost:5434 (já temos o script)
cd ../..
./script/fix-env-for-local.sh

# Criar banco
bundle exec rails db:create db:migrate

# Rodar Sidekiq localmente
bundle exec sidekiq -C config/sidekiq.yml
```

**Opção 3: Tudo no Docker (mais simples)**

```bash
cd docker/develop
docker-compose up -d
# Tudo roda dentro do Docker
```

---

## 📊 Status do Projeto

```
Projeto: Starchat App
Branch: change-base64-evolution
Status: 🟡 Testes criados, aguardando setup de DB

Arquivos Criados/Modificados:
✅ spec/services/evolution/send_message_service_spec.rb
✅ spec/services/evolution/media_attach_spec.rb
✅ .agent/change-base64-evolution-plan.md
✅ .agent/fix-docker-local-connection.md
✅ script/fix-env-for-local.sh
✅ script/use-native-services.sh

Próxima ação: Decidir entre Opção 1, 2 ou 3 acima
```
