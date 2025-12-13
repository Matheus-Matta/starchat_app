#!/bin/bash

echo "🔄 Reiniciando serviços para recarregar .env..."

# Verificar se há processos Rails rodando
if pgrep -f "rails s" > /dev/null; then
    echo "⚠️  Rails ainda está rodando. Por favor, pare-o com Ctrl+C primeiro."
fi

# Verificar se há processos Sidekiq rodando
if pgrep -f "sidekiq" > /dev/null; then
    echo "⚠️  Sidekiq ainda está rodando. Por favor, pare-o com Ctrl+C primeiro."
fi

echo ""
echo "📋 Variáveis Evolution carregadas:"
grep "EVOLUTION" .env | head -10

echo ""
echo "✅ Para aplicar as mudanças, execute em terminais separados:"
echo "   Terminal 1: bundle exec rails s -p 3001 -b 127.0.0.1"
echo "   Terminal 2: bundle exec sidekiq -e production -C config/sidekiq.yml"
