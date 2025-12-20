# Implementação de Evento de Violação de SLA (Conversation SLA Breached)

## Resumo da Funcionalidade

Esta implementação adiciona um novo evento de webhook chamado `conversation_sla_breached`. Esse evento permite que integrações externas sejam notificadas automaticamente sempre que ocorre uma violação de SLA (Service Level Agreement) em uma conversa.

## O Que Foi Feito

### 1. Backend

- **Modelo `Webhook` (`app/models/webhook.rb`)**:

  - Adicionado `conversation_sla_breached` à lista `ALLOWED_WEBHOOK_EVENTS`. Isso registra o evento como um tipo válido de assinatura para webhooks.

- **Modelo `SlaEvent` (`starchat/app/models/sla_event.rb`)**:

  - Adicionado um callback `after_create_commit :dispatch_create_event`.
  - Implementado o método privado `dispatch_create_event` que utiliza o `Rails.configuration.dispatcher` para disparar o evento interno `conversation.sla_breached` sempre que um novo registro de evento de SLA (FRT, NRT ou RT) é criado.

- **Listener `WebhookListener` (`app/listeners/webhook_listener.rb`)**:
  - Adicionado o método `conversation_sla_breached(event)`.
  - Este método captura o evento disparado, extrai os dados da conversa e do evento de SLA específico, e enfileira o envio do webhook (`WebhookJob`) para as URLs configuradas que assinaram este evento.
  - O payload enviado inclui os dados da conversa e um objeto `sla_events` contendo detalhes da violação (tipo do evento, metadados, timestamp).

### 2. Frontend

- **Formulário de Webhook (`app/javascript/dashboard/routes/dashboard/settings/integrations/Webhooks/WebhookForm.vue`)**:

  - Incluído `'conversation_sla_breached'` na lista `SUPPORTED_WEBHOOK_EVENTS`. Isso faz com que a opção apareça como um checkbox no formulário de criação/edição de webhook.

- **Traduções (`app/javascript/dashboard/i18n/locale/en/integrations.json` e `pt_BR/integrations.json`)**:
  - Adicionadas chaves de tradução para o novo evento:
    - **EN**: "Conversation SLA Breached"
    - **PT-BR**: "SLA da conversa violado"

## Como Usar

1.  Acesse o painel do Starchat.
2.  Vá para **Configurações** -> **Integrações** -> **Webhooks**.
3.  Clique em **Adicionar novo webhook** (ou edite um existente).
4.  No formulário, você verá uma nova opção de evento chamada **"SLA da conversa violado"**.
5.  Marque essa opção e salve o webhook.
6.  A partir de agora, sempre que uma política de SLA aplicada a uma conversa for violada (Tempo de Primeira Resposta, Próxima Resposta ou Resolução), o endpoint configurado receberá um payload JSON com o evento `conversation_sla_breached`.

## Exemplo de Payload

```json
{
  "event": "conversation_sla_breached",
  "id": 14,
  "inbox_id": 4447,
  "status": "open",
  "applied_sla": {
    "id": 87,
    "sla_id": 118,
    "sla_status": "active_with_misses",
    "sla_name": "alertas",
    "sla_first_response_time_threshold": 60.0
  },
  "sla_events": {
    "id": 36,
    "event_type": "nrt", // nrt = Next Response Time, frt = First Response Time, rt = Resolution Time
    "meta": {
      "message_id": 8135
    },
    "created_at": 1766258717
  }
  // ... outros dados da conversa
}
```
