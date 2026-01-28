# 🐛 Bug Fix: Validação de vínculo ContactInbox & Nova Configuração

## Resumo

Ajustado o serviço `Contacts::ContactableInboxesService`, a renderização da API e introduzida uma nova configuração de conta para garantir que apenas vínculos reais (com histórico) sejam utilizados.

## Problema Identificado

### Issue Inicial (Vínculos Fantasmas)

A tela de detalhes do contato mostrava inboxes vinculadas onde o contato nunca teve interação real. Isso acontecia porque o sistema listava qualquer canal "compatível" como um vínculo.

### Comportamento Invertido (Corrigido)

Em uma tentativa anterior, inboxes com conversas foram acidentalmente ocultadas em alguns cenários e canais de Voz (Twilio) sumiram. A lógica foi corrigida para ser robusta e inclusiva para todos os tipos de canais.

## Solução Implementada

### 1. Configuração na Conta

Adicionada uma nova opção nas configurações da conta (seção Resolver Automaticamente):

- **Chave**: `require_contact_inbox_messaging`
- **Interface**: "Bloquear envio de mensagens para contatos sem vínculo real"
- **Efeito**: Quando ativa, restringe o sistema a utilizar apenas canais onde já houve interação real (inbound/conversa).

### 2. Filtragem de Exibição (API)

O JBuilder de contatos agora filtra a lista de `contact_inboxes` retornada:

- Se `require_contact_inbox_messaging` estiver ON → Retorna apenas inboxes que já possuem conversas vinculadas.
- Isso remove os "links fantasmas" da tela de detalhes do contato.

### 3. Restrição de Envio (MessageBuilder)

Implementada validação no `Messages::MessageBuilder`:

- Se a conta exige vínculo real, o sistema bloqueia o envio de mensagens de saída (outgoing) para contatos que nunca interagiram previamente naquele canal (sem histórico inbound).
- Retorna um erro amigável para o agente.

### 4. Robustez do Serviço

O `ContactableInboxesService` agora:

- Suporta todos os meios do Twilio (incluindo Voz).
- Possui dois modos: `default` (todas compatíveis) e `only_existing` (vínculos reais).
- Honra automaticamente a nova configuração da conta.

## Uso no Sistema

### Endpoint `/contactable_inboxes`

O frontend agora pode solicitar especificamente o modo restrito:

```javascript
// Exemplo no Dashboard (ContactAPI)
getContactableInboxes(id, { only_existing: true });
```

### Comportamento dos Modos

| Modo         | Parâmetro              | Config Conta ON | Retorno                                     |
| ------------ | ---------------------- | --------------- | ------------------------------------------- |
| **Padrão**   | `only_existing: false` | OFF             | Todas as inboxes compatíveis (email/phone). |
| **Padrão**   | `only_existing: false` | **ON**          | **Apenas inboxes com histórico real.**      |
| **Vínculos** | `only_existing: true`  | (Qualquer)      | **Apenas inboxes com histórico real.**      |

---

## Arquivos Modificados

### Backend

- `app/models/account.rb`: Adicionada nova configuração.
- `app/builders/messages/message_builder.rb`: Validação de envio.
- `app/services/contacts/contactable_inboxes_service.rb`: Lógica de filtragem.
- `app/views/api/v1/models/_contact.json.jbuilder`: Filtragem de API.
- `config/locales/pt_BR.yml`: Traduções de erro.

### Frontend

- `app/javascript/dashboard/api/contacts.js`: Suporte a parâmetros.
- `app/javascript/dashboard/store/modules/contacts/actions.js`: Uso do novo filtro.
- `app/javascript/dashboard/routes/dashboard/settings/account/components/AutoResolve.vue`: Toggle na interface.
- `app/javascript/dashboard/i18n/locale/pt_BR/generalSettings.json`: Traduções da interface.

## Validação Acadêmica (Testes)

```bash
bundle exec rspec spec/services/contacts/contactable_inboxes_service_spec.rb
# 9 examples, 0 failures ✅
```

---

### 🎯 Status Final

✅ Vínculos fantasmas removidos da interface  
✅ Inversão de comportamento corrigida  
✅ Nova configuração de conta implementada  
✅ Bloqueio de envio para canais não vinculados funcional  
✅ Suporte robusto para Twilio (SMS/Voz/WhatsApp)
ndo normalmente

- ✅ Conversas antigas mantêm seus vínculos
- ✅ Frontend não precisa de alteração (já usa a API `/contactable_inboxes`)

## Próximos Passos (Opcional)

Se houver ContactInboxes criados indevidamente (sem conversas associadas), pode ser útil executar uma limpeza:

```ruby
# Identificar ContactInboxes órfãos (sem conversas)
ContactInbox.left_joins(:conversations)
  .where(conversations: { id: nil })
  .where('contact_inboxes.created_at < ?', 30.days.ago)
  .count

# Limpar (CUIDADO: validar antes em staging/dev)
# ContactInbox.stale_without_conversations(30.days.ago).destroy_all
```

**Nota:** O modelo `ContactInbox` já possui o scope `stale_without_conversations` para essa finalidade.

---

### 📊 Resumo da Correção

| Aspecto                  | Antes                                     | Depois                                 |
| ------------------------ | ----------------------------------------- | -------------------------------------- |
| **Lógica**               | Mostra todas as inboxes compatíveis       | Mostra apenas inboxes com vínculo real |
| **Critério**             | `contact.email` ou `contact.phone_number` | `contact.contact_inboxes` existente    |
| **Vínculos Fantasmas**   | ❌ Sim                                    | ✅ Não                                 |
| **Clareza para Agentes** | ❌ Baixa                                  | ✅ Alta                                |
| **Risco Operacional**    | ⚠️ Alto                                   | ✅ Baixo                               |
