# Mudanças de Base64 para URL na Evolution API

## Branch: `change-base64-evolution`

## 📋 Objetivo

Modificar o sistema de envio e recebimento de arquivos na integração Evolution API para:

- **PRIORIZAR** uso de URLs diretas ao invés de base64
- **MANTER** base64 como fallback para compatibilidade
- **MELHORAR** performance reduzindo overhead de codificação/decodificação

## 🎯 Benefícios

1. **Performance**: Reduz tamanho das requisições HTTP
2. **Memória**: Evita carregar arquivos completos em memória para codificação
3. **Compatibilidade**: Mantém base64 como fallback caso URLs falhem
4. **Escalabilidade**: Reduz carga no servidor para arquivos grandes

## 📝 Mudanças Propostas

### 1. `send_message_service.rb` - Envio de Mensagens

**Comportamento Atual:**

```ruby
# Codifica blob em base64 antes de enviar
audio_b64 = encode_blob_base64(att.file.blob)
client.send_whatsapp_audio(instance, audio: audio_b64)
```

**Comportamento Novo:**

```ruby
# Envia URL diretamente, com base64 como fallback
url = active_storage_url(att.file.blob)

# Tentar enviar URL primeiro
begin
  client.send_whatsapp_audio(instance, audio: url)
rescue => e
  # Fallback para base64 se URL falhar
  audio_b64 = encode_blob_base64(att.file.blob)
  client.send_whatsapp_audio(instance, audio: audio_b64)
end
```

**Métodos Afetados:**

- Envio de áudio (`send_whatsapp_audio`)
- Envio de mídia (`send_media` para image/video/document)

**Base64 como Fallback:**

- Mantém método `encode_blob_base64`
- Usa quando URL generation falha
- Usa quando API rejeita URL

---

### 2. `media_attach.rb` - Recebimento de Webhooks

**Comportamento Atual:**

```ruby
# Prioriza base64 no payload
if b64.present?
  blob = download_for_base64(b64, ...)
  return attach_blob!(message, blob)
end

# Fallback para URL + mediaKey
if url.present? && media_key.present?
  blob = download_for_whatsapp_enc(...)
  return attach_blob!(message, blob)
end
```

**Comportamento Novo:**

```ruby
# PRIORIZA URL + mediaKey (mais eficiente)
if url.present? && media_key.present?
  Rails.logger.info "[MediaAttach] Processing via URL (.enc): #{url}"
  blob = download_for_whatsapp_enc(...)
  return attach_blob!(message, blob)
end

# FALLBACK para base64 (se não houver URL)
if b64.present?
  Rails.logger.info "[MediaAttach] Fallback to Base64 processing"
  blob = download_for_base64(b64, ...)
  return attach_blob!(message, blob)
end
```

**Base64 como Fallback:**

- Mantém processamento de base64 completo
- Usa quando webhook não tem URL
- Usa quando download de URL falha
- Mantém compatibilidade com payloads antigos

---

## 🧪 Testes Criados

### `send_message_service_spec.rb`

Testa:

- ✅ Envio de imagem via URL (prioritário)
- ✅ Envio de áudio via URL
- ✅ Envio de documento com URL + filename
- ✅ Fallback para base64 quando URL falha
- ✅ Mensagens de texto (sem mudanças)
- ✅ Quoted messages (responder)
- ✅ Ordenação de anexos
- ✅ Tratamento de erros

### `media_attach_spec.rb`

Testa:

- ✅ Priorização de URL + mediaKey sobre base64
- ✅ Fallback para base64 quando não há URL
- ✅ Comportamento quando payload tem ambos
- ✅ Diferentes tipos de mídia (image/video/audio/document)
- ✅ Extração de base64 de diferentes campos
- ✅ Tratamento de erros

---

## 🔧 Configuração Necessária

### Variáveis de Ambiente

```bash
# Tempo de expiração das URLs do ActiveStorage
EVOLUTION_MEDIA_URL_TTL_SECONDS=900  # 15 minutos (padrão)

# timeouts HTTP (já existentes)
EVOLUTION_HTTP_OPEN_TIMEOUT=10
EVOLUTION_HTTP_READ_TIMEOUT=60
EVOLUTION_HTTP_WRITE_TIMEOUT=30
EVOLUTION_HTTP_MEDIA_READ_TIMEOUT=180
```

### ActiveStorage

Certifique-se que o ActiveStorage está configurado corretamente:

- URLs públicas acessíveis pela Evolution API
- CORS configurado se usando S3/Cloud Storage
- `DIRECT_UPLOADS_ENABLED` se necessário

---

## 📊 Comparação de Performance

### Envio de Imagem 1MB

**Com Base64:**

- Payload HTTP: ~1.4MB (Base64 aumenta 33%)
- Tempo de codificação: ~50ms
- Memória: Arquivo completo em RAM

**Com URL:**

- Payload HTTP: ~200 bytes (apenas URL)
- Tempo de codificação: 0ms
- Memória: Mínima

### Webhook com Vídeo 10MB

**Base64 prioritário (atual):**

- Processa 13.3MB de base64
- Decodifica e salva
- ~200ms processamento

**URL prioritário (novo):**

- Faz download direto do WhatsApp CDN
- Descriptografa com mediaKey
- ~150ms processamento
- Fallback para base64 se necessário

---

## 🚀 Plano de Implementação

### Fase 1: Testes (✅ CONCLUÍDO)

- [x] Criar `send_message_service_spec.rb`
- [x] Criar `media_attach_spec.rb`
- [ ] Executar testes para validar baseline

### Fase 2: Modificação com Fallback

- [ ] Modificar `send_message_service.rb`:
  - Tentar URL primeiro
  - Fallback para base64 em caso de erro
  - Manter método `encode_blob_base64`
  - Adicionar logs de qual método foi usado
- [ ] Modificar `media_attach.rb`:
  - Inverter ordem de prioridade
  - URL + mediaKey primeiro
  - Base64 como fallback
  - Log de qual método foi usado

### Fase 3: Validação

- [ ] Executar testes unitários
- [ ] Testar em ambiente de desenvolvimento
- [ ] Monitorar logs para ver qual método é mais usado
- [ ] Validar com Evolution API real

### Fase 4: Deploy Gradual

- [ ] Deploy em staging
- [ ] Monitorar métricas:
  - Taxa de sucesso URL vs base64
  - Tempo de resposta
  - Erros de API
- [ ] Ajustar timeouts se necessário
- [ ] Deploy em produção

### Fase 5: Limpeza (FUTURO - após validação)

- [ ] Se base64 raramente usado, considerar remover depois
- [ ] Remover código deprecated após 2-3 releases
- [ ] Atualizar documentação

---

## ⚠️ Riscos e Mitigações

### Risco 1: Evolution API quer base64

**Mitigação:** Manter base64 como fallback funcional

### Risco 2: URLs do ActiveStorage expiram

**Mitigação:** TTL configurável via ENV, padrão 15min

### Risco 3: CORS bloqueia download pela Evolution

**Mitigação:** Configurar CORS no S3/Storage, fallback para base64

### Risco 4: Arquivos muito grandes

**Mitigação:** Timeouts aumentados para mídia, retry logic

---

## 📈 Métricas para Monitorar

Após deploy, monitorar:

```ruby
# Adicionar aos logs
Rails.logger.info "[Evolution] Media sent via URL successfully"
Rails.logger.warn "[Evolution] Media URL failed, using base64 fallback"
Rails.logger.info "[Evolution] Webhook media downloaded via URL (.enc)"
Rails.logger.warn "[Evolution] Webhook URL failed, using base64"
```

**Dashboards:**

- Taxa de sucesso URL vs base64
- Tempo médio de envio de mídia
- Erros de API Evolution
- Tamanho médio de payloads

---

## 🔍 Como Executar Testes

```bash
# Testes específicos do Evolution
bundle exec rspec spec/services/evolution/

# Apenas send_message_service
bundle exec rspec spec/services/evolution/send_message_service_spec.rb

# Apenas media_attach
bundle exec rspec spec/services/evolution/media_attach_spec.rb

# Com coverage
COVERAGE=true bundle exec rspec spec/services/evolution/
```

---

## 📝 Notas de Desenvolvimento

### Ordem de Implementação

1. ✅ Criar testes primeiro (TDD)
2. Implementar mudanças com fallback
3. Executar testes
4. Testar manualmente
5. Code review
6. Deploy staging
7. Validação
8. Deploy produção

### Commits Sugeridos

```bash
# Commit 1
git add spec/services/evolution/
git commit -m "test: add comprehensive tests for Evolution media handling

- Tests for SendMessageService with URL priority
- Tests for MediaAttach with URL/base64 fallback
- Cover all media types and edge cases"

# Commit 2 (após implementação)
git add app/services/evolution/send_message_service.rb
git commit -m "feat: prioritize URL over base64 for media sending

- Use ActiveStorage URL directly when possible
- Keep base64 as fallback for compatibility
- Reduces payload size and improves performance
- BREAKING: None (backward compatible)"

# Commit 3
git add app/services/evolution/media_attach.rb
git commit -m "feat: prioritize URL downloads in webhooks

- Download from WhatsApp CDN URL first
- Use base64 as fallback
- Better performance for large files
- Maintains full backward compatibility"
```

---

## ✅ Checklist Pré-Merge

- [ ] Todos os testes passando
- [ ] Cobertura de testes > 90%
- [ ] Testado manualmente em desenvolvimento
- [ ] Logs adicionados para monitoramento
- [ ] ENV variables documentadas
- [ ] README atualizado se necessário
- [ ] Code review aprovado
- [ ] Testado em staging
- [ ] Métricas monitoradas por 24h em staging
- [ ] Aprovação do time

---

## 📚 Referências

- Evolution API Docs: https://doc.evolution-api.com/
- ActiveStorage Guide: https://edgeguides.rubyonrails.org/active_storage_overview.html
- WhatsApp Media Encryption: https://github.com/sigalor/whatsapp-web-reveng

---

**Data de Criação:** 2026-01-06  
**Branch:** `change-base64-evolution`  
**Status:** 🟡 Em Desenvolvimento (Fase 1 Completa)
