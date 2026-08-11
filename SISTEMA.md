# Starchat — Documentação do Sistema

> Mapa completo de features, integrações, canais, APIs e arquitetura do projeto.

---

## Sumário

1. [Canais de Comunicação](#1-canais-de-comunicação)
2. [Feature Flags](#2-feature-flags)
3. [Integrações Externas](#3-integrações-externas)
4. [Cosmos (IA)](#4-cosmos-ia)
5. [Assignment (Atribuição)](#5-assignment-atribuição)
6. [Automações](#6-automações)
7. [Relatórios](#7-relatórios)
8. [Super Admin](#8-super-admin)
9. [API](#9-api)
10. [Jobs Background](#10-jobs-background)
11. [Webhooks](#11-webhooks)
12. [Autenticação](#12-autenticação)
13. [Configurações do Sistema](#13-configurações-do-sistema)

---

## 1. Canais de Comunicação

Modelos em `app/models/channel/` — cada canal tem controller próprio em `app/controllers/api/v1/accounts/channels/` e serviços em `app/services/{canal}/`.

| Canal | Modelo | Webhook de entrada | Observação |
|---|---|---|---|
| **Web Widget** | `channel/web_widget.rb` | — | Chat embeddable em sites |
| **Email (IMAP/SMTP)** | `channel/email.rb` | `app/services/imap/` | Gmail, Outlook, SMTP genérico |
| **API** | `channel/api.rb` | Configurável pelo usuário | Canal genérico via REST |
| **WhatsApp** | `channel/whatsapp.rb` | `webhooks/whatsapp_controller.rb` | Meta Business API + templates |
| **Evolution API** | `channel/evolution.rb` | `webhooks/evolution_controller.rb` | WhatsApp via Evolution (open source) |
| **Facebook** | `channel/facebook_page.rb` | `webhooks/` + `services/facebook/` | Facebook Messenger |
| **Instagram** | `channel/instagram.rb` | `webhooks/instagram_controller.rb` | Instagram Direct |
| **Telegram** | `channel/telegram.rb` | `webhooks/telegram_controller.rb` | Bot Telegram |
| **LINE** | `channel/line.rb` | `webhooks/line_controller.rb` | LINE Messaging API |
| **SMS (Twilio)** | `channel/twilio_sms.rb` | `webhooks/twilio/` | SMS e voz via Twilio |
| **SMS (Genérico)** | `channel/sms.rb` | `webhooks/sms_controller.rb` | SMS via providers genéricos |
| **Twitter/X** | `channel/twitter_profile.rb` | `twitter/callbacks_controller.rb` | Twitter DM |
| **TikTok** | `channel/tiktok.rb` | `webhooks/tiktok_controller.rb` | TikTok Shop Messaging |

### Configurar um canal novo
1. Ir em **Configurações → Inboxes → Novo inbox**
2. Escolher o tipo de canal
3. Configurar credenciais via UI ou `installation_config.yml`

---

## 2. Feature Flags

Arquivo: `config/features.yml`
Verificação no código: `account.feature_enabled?('nome_da_feature')`
Gestão via super admin: `/super_admin/accounts/{id}/edit` → campo **All Features**

### Todas as features

#### Canais
| Feature | O que habilita |
|---|---|
| `channel_email` | Canal de email |
| `channel_facebook` | Canal Facebook Messenger |
| `channel_website` | Web Widget |
| `channel_instagram` | Canal Instagram |
| `channel_voice` | Canal de voz (chamadas) |
| `channel_tiktok` | Canal TikTok |
| `inbound_emails` | Receber emails de entrada |

#### Comunicação e Atendimento
| Feature | O que habilita |
|---|---|
| `help_center` | Knowledge Base / Portal de ajuda |
| `canned_responses` | Respostas pré-gravadas |
| `macros` | Macros de atendimento |
| `campaigns` | Campanhas de mensagem |
| `whatsapp_campaign` | Campanhas WhatsApp |
| `voice_recorder` | Gravação de voz nas mensagens |
| `auto_resolve_conversations` | Fechar conversas automaticamente |

#### Agentes e Times
| Feature | O que habilita |
|---|---|
| `agent_management` | Gerenciar agentes |
| `team_management` | Gerenciar times |
| `custom_roles` | Perfis de permissão customizados |
| `agent_bots` | Bots de agentes |
| `assignment_v2` | Motor de atribuição v2 |
| `advanced_assignment` | Políticas avançadas de atribuição |

#### CRM e Dados
| Feature | O que habilita |
|---|---|
| `crm` | CRM básico de contatos |
| `crm_v2` | CRM v2 (versão melhorada) |
| `crm_integration` | Integração CRM externo (LeadSquared) |
| `companies` | Módulo de empresas |
| `custom_attributes` | Atributos customizados em conversas e contatos |
| `labels` | Etiquetas/tags |
| `ip_lookup` | Lookup de IP dos contatos |
| `conversation_unread_counts` | Contagem de mensagens não lidas |
| `inbox_view` | Visão de inbox personalizada |

#### Cosmos — IA
| Feature | O que habilita |
|---|---|
| `cosmos_integration` | Cosmos v1 — assistente IA |
| `cosmos_integration_v2` | Cosmos v2 — recursos avançados |
| `cosmos_tasks` | Tarefas IA (resumo, sugestão, reescrita) |
| `cosmos_custom_tools` | Tools customizadas para assistentes |
| `cosmos_document_auto_sync` | Sincronização automática de documentos |
| `cosmos_v1_action_classifier` | Classificador de ações v1 |
| `custom_tools` | Tools genéricas |
| `help_center_embedding_search` | Busca semântica no help center |

#### Relatórios e Busca
| Feature | O que habilita |
|---|---|
| `reports` | Relatórios básicos |
| `report_rollup` | Agregação de relatórios |
| `advanced_search` | Busca avançada em conversas |
| `search_with_gin` | Índice GIN no PostgreSQL para busca |
| `advanced_search_indexing` | Indexação para busca avançada |
| `csat_review_notes` | Notas nas avaliações CSAT |
| `audit_logs` | Logs de auditoria de ações |

#### Integrações
| Feature | O que habilita |
|---|---|
| `integrations` | Seção de integrações na UI |
| `shopify_integration` | Integração Shopify |
| `linear_integration` | Integração Linear |
| `notion_integration` | Integração Notion |

#### Segurança e Conformidade
| Feature | O que habilita |
|---|---|
| `saml` | Login via SAML SSO |
| `conversation_required_attributes` | Atributos obrigatórios antes de fechar conversa |
| `sla` | Políticas de SLA (tempo de resposta) |
| `disable_branding` | Remove branding Starchats da UI |

#### Email
| Feature | O que habilita |
|---|---|
| `custom_reply_email` | Email de resposta customizado por inbox |
| `custom_reply_domain` | Domínio customizado para reply |
| `email_continuity_on_api_channel` | Continuidade via email no canal API |
| `reply_mailer_migration` | Novo builder de email de resposta |

#### Outros
| Feature | O que habilita |
|---|---|
| `chatwoot_v4` | Interface v4 |
| `contact_starchats_support_team` | Contato com suporte |

---

## 3. Integrações Externas

### Shopify
Conecta lojas Shopify para ver pedidos e clientes dentro das conversas.
- **Controller**: `app/controllers/api/v1/accounts/integrations/shopify_controller.rb`
- **Callback OAuth**: `app/controllers/shopify/callbacks_controller.rb`
- **Webhook saída**: `app/controllers/webhooks/shopify_controller.rb`
- **Helper**: `app/helpers/shopify/integration_helper.rb`
- **Config**: `SHOPIFY_CLIENT_ID`, `SHOPIFY_CLIENT_SECRET` (`.env` ou super admin)
- **Feature**: `shopify_integration`
- **Fluxo**: Conta clica Connect → OAuth → access token salvo em `Integrations::Hook`

### Linear
Cria e linka issues do Linear diretamente nas conversas.
- **Controller**: `app/controllers/api/v1/accounts/integrations/linear_controller.rb`
- **Callback**: `app/controllers/linear/callbacks_controller.rb`
- **Serviços**: `app/services/linear/`
- **Config**: `LINEAR_CLIENT_ID`, `LINEAR_CLIENT_SECRET`
- **Feature**: `linear_integration`

### Notion
Salva conversas e dados em páginas do Notion.
- **Controller**: `app/controllers/api/v1/accounts/integrations/notion_controller.rb`
- **Callback**: `app/controllers/notion/callbacks_controller.rb`
- **Config**: `NOTION_CLIENT_ID`, `NOTION_CLIENT_SECRET`, `NOTION_VERSION`
- **Feature**: `notion_integration`

### Slack
Notificações bidirecionais — conversas aparecem em canais Slack.
- **Controller**: `app/controllers/api/v1/accounts/integrations/slack_controller.rb`
- **Jobs**: `app/jobs/send_on_slack_job.rb`, `app/jobs/update_slack_message_job.rb`
- **Config**: `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET`

### Dyte
Videoconferência integrada nas conversas.
- **Controller**: `app/controllers/api/v1/accounts/integrations/dyte_controller.rb`
- **Widget**: `app/controllers/api/v1/widget/integrations/dyte_controller.rb`

### Evolution API
Alternativa ao WhatsApp Business API oficial (self-hosted).
- **Canal**: `app/models/channel/evolution.rb`
- **Controller**: `app/controllers/api/v1/accounts/channels/evolution_channel_controller.rb`
- **Webhook**: `app/controllers/webhooks/evolution_controller.rb`
- **Serviços**: `app/services/evolution/` (send_message, incoming_message, contact_sync)
- **Jobs**: `app/jobs/evolution/`

### OpenAI (via Cosmos)
LLM para o módulo Cosmos — respostas IA, embeddings, classificação.
- **Config**: `COSMOS_OPEN_AI_API_KEY`, `COSMOS_OPEN_AI_MODEL` (padrão: `gpt-4.1-mini`), `COSMOS_OPEN_AI_ENDPOINT`
- **Serviços**: `starchat/app/services/cosmos/llm/`, `starchat/lib/cosmos/llm_service.rb`

### FireCrawl
Crawling de páginas web para alimentar documentos do Cosmos.
- **Config**: `COSMOS_FIRECRAWL_API_KEY`
- **Webhook**: `starchat/app/controllers/starchat/webhooks/firecrawl_controller.rb`
- **Jobs**: `starchat/app/jobs/cosmos/documents/crawl_job.rb`

### LeadSquared (CRM)
Sincronização de contatos com o CRM LeadSquared.
- **Serviços**: `app/services/crm/leadsquared/`
- **Feature**: `crm_integration`

### Google OAuth
Login via conta Google.
- **Config**: `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI`
- **Callback**: `app/controllers/google/callbacks_controller.rb`
- **Config flag**: `ENABLE_GOOGLE_OAUTH_LOGIN` (padrão: `true`)

### Microsoft OAuth
Login via conta Microsoft / inbox de email via Outlook.
- **Config**: `AZURE_APP_ID`, `AZURE_APP_SECRET`
- **Callback**: `app/controllers/microsoft/callbacks_controller.rb`

### Clearbit
Enriquecimento automático de dados de contatos.
- **Config**: `CLEARBIT_API_KEY`
- **Model**: `app/models/contact.rb` → `ip_lookup`

### Firebase/FCM
Push notifications para app mobile.
- **Config**: `FIREBASE_PROJECT_ID`, `FIREBASE_CREDENTIALS`
- **Job**: `app/jobs/notification/push_notification_job.rb`

### Langfuse / OpenTelemetry
Observabilidade de chamadas LLM do Cosmos.
- **Config**: `OTEL_PROVIDER`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_BASE_URL`
- **Verificação**: `StarchatsApp.otel_enabled?` em `lib/starchats_app.rb`

---

## 4. Cosmos (IA)

O módulo Cosmos é a camada de IA do sistema. Fica em `starchat/` e se integra com OpenAI.

### Arquitetura
```
starchat/
  app/
    models/cosmos/         — Modelos do banco
    controllers/api/v1/accounts/cosmos/  — Endpoints REST
    services/cosmos/       — Lógica de negócio
    services/cosmos/llm/   — Serviços LLM
    jobs/cosmos/           — Jobs background
  lib/cosmos/              — Core library (agent, tools, LLM)
```

### Assistants
O que é: Agente IA configurado para uma inbox — responde automaticamente conversas.
- **Model**: `starchat/app/models/cosmos/assistant.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/assistants_controller.rb`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/assistants/`
- **Endpoints**: `GET/POST/PUT/DELETE /accounts/{id}/cosmos/assistants`

### Documents
O que é: Documentos que alimentam o conhecimento do assistant (URLs, PDFs, texto).
- **Model**: `starchat/app/models/cosmos/document.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/documents_controller.rb`
- **Sync service**: `starchat/app/services/cosmos/documents/sync_service.rb`
- **Embedding**: `starchat/app/services/cosmos/llm/embedding_service.rb`
- **Jobs**: `cosmos/documents/perform_sync_job.rb`, `cosmos/documents/crawl_job.rb`
- **Feature**: `cosmos_document_auto_sync`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/documents/`

### Tools (Ferramentas)
O que é: Ações que o assistant pode executar durante uma conversa.

**Built-in tools** (`starchat/lib/cosmos/tools/`):
| Tool | O que faz |
|---|---|
| `faq_lookup_tool.rb` | Busca no knowledge base |
| `handoff_tool.rb` | Transfere para agente humano |
| `add_label_to_conversation_tool.rb` | Adiciona label |
| `add_private_note_tool.rb` | Adiciona nota privada |
| `update_priority_tool.rb` | Atualiza prioridade |
| `add_contact_note_tool.rb` | Adiciona nota no contato |
| `http_tool.rb` | Chamada HTTP genérica |

**Custom tools**: Configuradas por conta via UI
- **Model**: `starchat/app/models/cosmos/custom_tool.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/custom_tools_controller.rb`
- **Registry**: `starchat/app/services/cosmos/tool_registry_service.rb`
- **Feature**: `cosmos_custom_tools`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/tools/`

### Responses (Respostas Sugeridas)
O que é: Sugestões de resposta geradas pela IA para o agente humano.
- **Model**: `starchat/app/models/cosmos/assistant_response.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/assistant_responses_controller.rb`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/responses/`

### Scenarios
O que é: Cenários de atendimento específicos que o assistant reconhece e trata de forma diferente.
- **Model**: `starchat/app/models/cosmos/scenario.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/scenarios_controller.rb`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/assistants/scenarios/`

### Guidelines e Guardrails
O que é: Instruções de comportamento e limites para o assistant.
- Configurados no modelo do assistant
- **Service**: `starchat/app/services/cosmos/llm/system_prompts_service.rb`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/assistants/guidelines/` e `guardrails/`

### Inboxes (Vinculação)
O que é: Liga um assistant a uma inbox.
- **Model**: `starchat/app/models/cosmos_inbox.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/inboxes_controller.rb`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/assistants/inboxes/`

### Playground
O que é: Teste interativo de um assistant antes de ativar em produção.
- **Endpoint**: `POST /accounts/{id}/cosmos/assistants/{id}/playground`
- **UI**: `app/javascript/dashboard/routes/dashboard/cosmos/assistants/playground/`

### Copilot (Assistente para Agentes)
O que é: Chat IA auxiliar que ajuda agentes humanos durante atendimento.
- **Models**: `starchat/app/models/copilot_thread.rb`, `copilot_message.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/copilot_threads_controller.rb`
- **Service**: `starchat/app/services/cosmos/copilot/chat_service.rb`
- **Feature**: `cosmos_integration`

### Tasks (Tarefas IA)
O que é: Operações pontuais de IA acionadas pelo agente.

| Task | O que faz |
|---|---|
| `rewrite` | Reescrever a mensagem do agente |
| `summarize` | Resumir a conversa |
| `reply_suggestion` | Sugerir resposta |
| `label_suggestion` | Sugerir labels |
| `follow_up` | Gerar follow-up |

- **Controller**: `starchat/app/controllers/api/v1/accounts/cosmos/tasks_controller.rb`
- **Services**: `starchat/app/services/cosmos/llm/` (arquivo por task)

### Core LLM
- **Agent executor**: `starchat/lib/cosmos/agent.rb`
- **Interface OpenAI**: `starchat/lib/cosmos/llm_service.rb`
- **Chat principal**: `starchat/app/services/cosmos/llm/assistant_chat_service.rb`
- **Completion**: `starchat/app/services/cosmos/conversation_completion_service.rb`

---

## 5. Assignment (Atribuição)

Sistema que distribui conversas automaticamente para agentes.

### Políticas de Atribuição
- **Model**: `app/models/assignment_policy.rb`
- **Controller**: `app/controllers/api/v1/accounts/assignment_policies_controller.rb`
- **UI**: `app/javascript/dashboard/routes/dashboard/settings/assignmentPolicy/`

| Modo | Como funciona |
|---|---|
| `round_robin` | Fila circular — cada agente recebe na sua vez |
| `balanced` | Agente com menos conversas abertas recebe primeiro |
| `equal_distribution` | Distribui igualitariamente dentro de uma janela de tempo |

### Inbox Assignment Policy
Liga uma política a uma inbox específica.
- **Model**: `app/models/inbox_assignment_policy.rb`
- Sub-resource de `assignment_policies`

### Agent Capacity Policy
Limita quantas conversas simultâneas um agente pode ter.
- **Model**: `starchat/app/models/agent_capacity_policy.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/agent_capacity_policies_controller.rb`
- Sub-resources: `users`, `inbox_limits`

### Rate Limiter
Controla quantas atribuições um agente recebe por janela de tempo.
- **Service**: `app/services/auto_assignment/rate_limiter.rb`
- Config via `assignment_policy.fair_distribution_limit` e `fair_distribution_window`
- Armazenado no Redis com TTL

### Serviços
- **Core**: `app/services/auto_assignment/assignment_service.rb`
- **Starchat override**: `starchat/app/services/starchat/auto_assignment/assignment_service.rb`
- **Selectors**:
  - `starchat/app/services/starchat/auto_assignment/balanced_selector.rb`
  - `starchat/app/services/starchat/auto_assignment/equal_distribution_selector.rb`
  - `app/services/auto_assignment/round_robin_selector.rb`

### Jobs
- `app/jobs/auto_assignment/assignment_job.rb` — atribuição individual
- `app/jobs/auto_assignment/periodic_assignment_job.rb` — reatribuição periódica
- `app/jobs/inboxes/bulk_auto_assignment_job.rb` — atribuição em lote

---

## 6. Automações

Regras que disparam ações automaticamente com base em eventos.

- **Model**: `app/models/automation_rule.rb`
- **Controller**: `app/controllers/api/v1/accounts/automation_rules_controller.rb`
- **Listener**: `app/listeners/automation_rule_listener.rb`
- **Services**: `app/services/automation_rules/`
- **UI**: `app/javascript/dashboard/routes/dashboard/settings/automation/`

### Eventos
| Evento | Quando dispara |
|---|---|
| `conversation_created` | Nova conversa criada |
| `conversation_updated` | Conversa atualizada |
| `conversation_opened` | Conversa reaberta |
| `conversation_resolved` | Conversa resolvida |
| `message_created` | Nova mensagem recebida ou enviada |

### Ações
| Ação | O que faz |
|---|---|
| `send_message` | Envia mensagem automática |
| `add_label` / `remove_label` | Gerencia labels |
| `assign_agent` / `remove_assigned_agent` | Atribui/remove agente |
| `assign_team` / `remove_assigned_team` | Atribui/remove time |
| `change_status` | Muda status da conversa |
| `change_priority` | Muda prioridade |
| `send_email_to_team` | Envia email ao time |
| `send_webhook_event` | Dispara webhook externo |
| `add_private_note` | Adiciona nota privada |
| `send_email_transcript` | Envia transcript por email |
| `mute_conversation` | Muta conversa |
| `snooze_conversation` | Adia conversa |
| `send_attachment` | Envia arquivo |
| `resolve_conversation` | Resolve |
| `open_conversation` | Abre |
| `pending_conversation` | Coloca como pendente |

---

## 7. Relatórios

### API V1 (legado)
`app/controllers/api/v1/accounts/reports_controller.rb`

### API V2 (recomendada)
`app/controllers/api/v2/accounts/`

| Controller | Relatórios disponíveis |
|---|---|
| `reports_controller.rb` | Conversas, agentes, inboxes, labels, times, bot, tráfego, distribuição de tempo de resposta, outbound, matriz inbox-label, resumo |
| `summary_reports_controller.rb` | Summary por agente, time, inbox, label, canal |
| `live_reports_controller.rb` | Métricas em tempo real |

### CSAT
- **Model**: `app/models/csat_survey_response.rb`
- **Controller**: `app/controllers/api/v1/accounts/csat_survey_responses_controller.rb`
- **Endpoints**: index, metrics, download (CSV/PDF)
- **Config de template**: `app/controllers/api/v1/accounts/inbox_csat_templates_controller.rb`

### SLA
- **Model**: `starchat/app/models/sla_policy.rb`
- **Controller**: `app/controllers/api/v1/accounts/sla_policies_controller.rb`
- **Jobs**: `starchat/app/jobs/sla/trigger_slas_for_accounts_job.rb`, `process_applied_sla_job.rb`
- **Feature**: `sla`

### Audit Logs
- **Model**: `starchat/app/models/starchat/audit_log.rb`
- **Controller**: `app/controllers/api/v1/accounts/audit_logs_controller.rb`
- **Feature**: `audit_logs`

---

## 8. Super Admin

Painel de administração do sistema inteiro (não de uma conta).
URL: `/super_admin`

### O que pode fazer

| Seção | O que gerencia | Controller |
|---|---|---|
| **Accounts** | Criar, editar, deletar contas; seed; reset cache | `super_admin/accounts_controller.rb` |
| **Users** | Gerenciar super admins e avatars | `super_admin/users_controller.rb` |
| **Installation Configs** | Configurações globais (branding, integrações) | `super_admin/installation_configs_controller.rb` |
| **Agent Bots** | Bots globais de agente | `super_admin/agent_bots_controller.rb` |
| **Platform Apps** | Apps de integração da plataforma | `super_admin/platform_apps_controller.rb` |
| **Platform Banners** | Banners globais no sistema | `super_admin/platform_banners_controller.rb` |
| **Access Tokens** | Visualizar tokens de acesso | `super_admin/access_tokens_controller.rb` |
| **App Config** | Configuração de app (branding, URLs) | `super_admin/app_configs_controller.rb` |
| **Push Diagnostics** | Diagnosticar push notifications | `super_admin/push_diagnostics_controller.rb` |
| **Instance Status** | Status da instância | `super_admin/instance_statuses_controller.rb` |

### Ativar feature para uma conta
1. Ir em `/super_admin/accounts`
2. Clicar na conta → Editar
3. Campo **All Features**: marcar a feature desejada
4. Salvar

### Gerenciar configurações globais
1. Ir em `/super_admin/installation_configs`
2. Editar qualquer config (exceto as `locked: true`)

### Sidekiq (monitoramento de jobs)
URL: `/monitoring/sidekiq`

---

## 9. API

### Versões

| Versão | Base URL | Uso |
|---|---|---|
| **v1** | `/api/v1/` | API principal — estável |
| **v2** | `/api/v2/` | Reports avançados e live data |
| **Platform** | `/platform/api/v1/` | Para apps externas (gerenciar users/contas) |
| **Public** | `/public/api/v1/` | Sem autenticação — widget/contatos |
| **Starchat** | `/starchat/api/v1/` e `/starchat/api/v2/` | Endpoints específicos do Starchat |

### Autenticação
Header: `api_access_token: {token}` ou cookies de sessão

### Principais recursos da API v1

| Recurso | Endpoints | Arquivo |
|---|---|---|
| `conversations` | CRUD + assignee, labels, participants, messages | `conversations_controller.rb` |
| `contacts` | CRUD + conversations, notes, filter | `contacts_controller.rb` |
| `messages` | CRUD + attachments, reactions | `messages_controller.rb` |
| `inboxes` | CRUD + members, webhooks | `inboxes_controller.rb` |
| `agents` | CRUD | `agents_controller.rb` |
| `teams` | CRUD + team_members | `teams_controller.rb` |
| `labels` | CRUD | `labels_controller.rb` |
| `automation_rules` | CRUD + copy | `automation_rules_controller.rb` |
| `macros` | CRUD + run | `macros_controller.rb` |
| `canned_responses` | CRUD | `canned_responses_controller.rb` |
| `custom_attribute_definitions` | CRUD | `custom_attribute_definitions_controller.rb` |
| `webhooks` | CRUD | `webhooks_controller.rb` |
| `campaigns` | CRUD | `campaigns_controller.rb` |
| `companies` | CRUD | `companies_controller.rb` |
| `sla_policies` | CRUD | `sla_policies_controller.rb` |
| `assignment_policies` | CRUD | `assignment_policies_controller.rb` |
| `csat_survey_responses` | index, metrics, download | `csat_survey_responses_controller.rb` |
| `audit_logs` | index | `audit_logs_controller.rb` |
| `search` | conversas, mensagens, contatos, artigos | `search_controller.rb` |
| `notifications` | index, update, destroy | `notifications_controller.rb` |
| `portals` | CRUD + categories, articles | `portals_controller.rb` |
| `dashboard_apps` | CRUD | `dashboard_apps_controller.rb` |

### Endpoints Cosmos (IA) — `/accounts/{id}/cosmos/`

| Recurso | O que faz |
|---|---|
| `assistants` | CRUD de assistentes |
| `assistants/{id}/playground` | Testar assistant |
| `documents` | CRUD de documentos |
| `copilot_threads` | Chat copilot para agentes |
| `custom_tools` | CRUD de tools customizadas |
| `assistant_responses` | Respostas sugeridas |
| `scenarios` | Cenários de atendimento |
| `tasks/{action}` | rewrite, summarize, reply_suggestion, label_suggestion, follow_up |

---

## 10. Jobs Background

Processamento assíncrono via **Sidekiq**. Monitorar em `/monitoring/sidekiq`.

### Mensageria e Canais
| Job | O que faz |
|---|---|
| `send_reply_job.rb` | Envia respostas para os canais |
| `webhooks/facebook_events_job.rb` | Processa eventos Facebook |
| `webhooks/whatsapp_events_job.rb` | Processa eventos WhatsApp |
| `webhooks/telegram_events_job.rb` | Processa eventos Telegram |
| `webhooks/instagram_events_job.rb` | Processa eventos Instagram |
| `webhooks/evolution_events_job.rb` | Processa eventos Evolution |
| `webhooks/tiktok_events_job.rb` | Processa eventos TikTok |
| `webhooks/line_events_job.rb` | Processa eventos LINE |
| `webhooks/sms_events_job.rb` | Processa eventos SMS |
| `send_on_slack_job.rb` | Envia mensagem para Slack |
| `update_slack_message_job.rb` | Atualiza mensagem no Slack |
| `conversation_reply_email_job.rb` | Envia email de transcript |

### Notificações
| Job | O que faz |
|---|---|
| `notification/email_notification_job.rb` | Notificações por email |
| `notification/push_notification_job.rb` | Push notifications (Firebase) |
| `presence_broadcast_job.rb` | Broadcast de status online |

### Atribuição
| Job | O que faz |
|---|---|
| `auto_assignment/assignment_job.rb` | Atribuição de conversa |
| `auto_assignment/periodic_assignment_job.rb` | Reatribuição periódica |
| `inboxes/bulk_auto_assignment_job.rb` | Atribuição em lote |

### Dados e Manutenção
| Job | O que faz |
|---|---|
| `account/contacts_export_job.rb` | Exportar contatos (CSV) |
| `data_import_job.rb` | Importar dados |
| `contact_ip_lookup_job.rb` | Lookup de IP |
| `internal/process_stale_contacts_job.rb` | Limpar contatos inativos |
| `internal/remove_orphan_conversations_job.rb` | Remover conversas órfãs |
| `internal/trigger_daily_scheduled_items_job.rb` | Scheduler diário |
| `internal/trigger_hourly_scheduled_items_job.rb` | Scheduler horário |
| `webhook_job.rb` | Disparar webhooks de saída |

### Cosmos (IA)
| Job | O que faz |
|---|---|
| `cosmos/documents/perform_sync_job.rb` | Sincronizar documento |
| `cosmos/documents/crawl_job.rb` | Crawl de URL |
| `cosmos/inbox_pending_conversations_resolution_job.rb` | Resolver conversas via Cosmos |
| `starchat/messages/audio_transcription_job.rb` | Transcrição de áudio |

### SLA
| Job | O que faz |
|---|---|
| `sla/trigger_slas_for_accounts_job.rb` | Processar SLAs de todas as contas |
| `sla/process_applied_sla_job.rb` | Processar SLA individual |

### Onboarding
| Job | O que faz |
|---|---|
| `onboarding/help_center_article_generation_job.rb` | Gera artigos para o help center via IA |
| `portal/article_indexing_job.rb` | Indexa artigos para busca |

---

## 11. Webhooks

### Webhooks de Saída (account → sistemas externos)
- **Model**: `app/models/webhook.rb`
- **Controller**: `app/controllers/api/v1/accounts/webhooks_controller.rb`
- **Listener**: `app/listeners/webhook_listener.rb`
- **Job**: `app/jobs/webhook_job.rb`

#### Eventos disponíveis para assinar
```
conversation_status_changed
conversation_updated
conversation_created
contact_created
contact_updated
message_created
message_updated
webwidget_triggered
inbox_created
inbox_updated
conversation_typing_on
conversation_typing_off
conversation_sla_breached
```

#### Configurar
1. Configurações → Integrações → Webhooks
2. Adicionar URL + selecionar eventos

### Webhooks de Entrada (plataformas externas → sistema)
Cada canal tem seu próprio endpoint:

| Canal | URL | Controller |
|---|---|---|
| WhatsApp | `/webhooks/whatsapp` | `webhooks/whatsapp_controller.rb` |
| Evolution | `/webhooks/evolution` | `webhooks/evolution_controller.rb` |
| Facebook | `/webhooks/facebook` | (via `services/facebook/`) |
| Instagram | `/webhooks/instagram` | `webhooks/instagram_controller.rb` |
| Telegram | `/webhooks/telegram` | `webhooks/telegram_controller.rb` |
| LINE | `/webhooks/line` | `webhooks/line_controller.rb` |
| TikTok | `/webhooks/tiktok` | `webhooks/tiktok_controller.rb` |
| SMS | `/webhooks/sms` | `webhooks/sms_controller.rb` |
| Shopify | `/webhooks/shopify` | `webhooks/shopify_controller.rb` |
| FireCrawl | `/starchat/webhooks/firecrawl` | `starchat/webhooks/firecrawl_controller.rb` |

---

## 12. Autenticação

### Métodos disponíveis
- **Email/senha**: padrão, via Devise
- **Google OAuth**: `GOOGLE_OAUTH_CLIENT_ID` no `.env`
- **Microsoft OAuth**: `AZURE_APP_ID` no `.env`
- **SAML SSO**: feature `saml` + configuração por conta

### MFA (Autenticação de dois fatores)
- Endpoints: `GET/POST/DELETE /profile/mfa`
- Verificação: `POST /profile/mfa/verify`
- Backup codes: `POST /profile/mfa/backup_codes`

### Token de API
- Gerado automaticamente por usuário
- Header: `api_access_token: {token}`
- Ver tokens: `/super_admin/access_tokens`

### SAML
- **Model**: `starchat/app/models/account_saml_settings.rb`
- **Controller**: `starchat/app/controllers/api/v1/accounts/saml_settings_controller.rb`
- **Login endpoint**: `POST /auth/saml_login`
- **Feature**: `saml`

### Arquivos principais
```
app/controllers/devise_overrides/
  confirmations_controller.rb
  omniauth_callbacks_controller.rb
  passwords_controller.rb
  registrations_controller.rb
  sessions_controller.rb
```

---

## 13. Configurações do Sistema

Arquivo: `config/installation_config.yml`
Gerenciar via: `/super_admin/installation_configs`
Ou diretamente no `.env` (o `.env` tem precedência).

### Branding
| Config | O que faz | Padrão |
|---|---|---|
| `INSTALLATION_NAME` | Nome da instalação | `Starchats` |
| `BRAND_NAME` | Nome da marca | — |
| `BRAND_URL` | URL da marca | — |
| `LOGO` | Caminho do logo | — |
| `LOGO_DARK` | Logo dark mode | — |
| `LOGO_THUMBNAIL` | Favicon | — |
| `WIDGET_BRAND_URL` | URL no widget | — |

### Conta e Signup
| Config | O que faz | Padrão |
|---|---|---|
| `ENABLE_ACCOUNT_SIGNUP` | Permite criar contas na tela de login | `false` |
| `CREATE_NEW_ACCOUNT_FROM_DASHBOARD` | Criar contas pelo dashboard | — |
| `HCAPTCHA_SITE_KEY` / `HCAPTCHA_SERVER_KEY` | Proteção hCaptcha no signup | — |
| `WEBHOOK_TIMEOUT` | Timeout de webhooks em segundos | — |
| `MAXIMUM_FILE_UPLOAD_SIZE` | Tamanho máximo de upload (MB) | — |

### Email
| Config | O que faz |
|---|---|
| `MAILER_INBOUND_EMAIL_DOMAIN` | Domínio para emails de resposta (reply+) |
| `MAILER_SUPPORT_EMAIL` | Email de suporte exibido |
| `ACCOUNT_EMAILS_LIMIT` | Limite de emails por conta por dia |

### Canais Sociais
| Config | Canal |
|---|---|
| `FB_APP_ID`, `FB_APP_SECRET`, `FB_VERIFY_TOKEN` | Facebook |
| `IG_VERIFY_TOKEN`, `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET` | Instagram |
| `WHATSAPP_APP_ID`, `WHATSAPP_APP_SECRET`, `WHATSAPP_CONFIGURATION_ID` | WhatsApp |
| `TIKTOK_APP_ID`, `TIKTOK_APP_SECRET` | TikTok |
| `AZURE_APP_ID`, `AZURE_APP_SECRET` | Microsoft (email OAuth) |

### Cosmos (IA)
| Config | O que faz | Padrão |
|---|---|---|
| `COSMOS_OPEN_AI_API_KEY` | Chave OpenAI | — |
| `COSMOS_OPEN_AI_MODEL` | Modelo LLM | `gpt-4.1-mini` |
| `COSMOS_OPEN_AI_ENDPOINT` | Endpoint customizado | — |
| `COSMOS_EMBEDDING_MODEL` | Modelo de embeddings | — |
| `COSMOS_FIRECRAWL_API_KEY` | Chave FireCrawl | — |
| `COSMOS_DOCUMENT_AUTO_SYNC_INTERVALS` | Intervalos de sync | — |

### Integrações
| Config | Integração |
|---|---|
| `SHOPIFY_CLIENT_ID`, `SHOPIFY_CLIENT_SECRET` | Shopify |
| `LINEAR_CLIENT_ID`, `LINEAR_CLIENT_SECRET` | Linear |
| `NOTION_CLIENT_ID`, `NOTION_CLIENT_SECRET`, `NOTION_VERSION` | Notion |
| `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET` | Slack |
| `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_REDIRECT_URI` | Google OAuth |
| `CLEARBIT_API_KEY` | Clearbit |

### Observabilidade (Cosmos)
| Config | O que faz |
|---|---|
| `OTEL_PROVIDER` | Provider OpenTelemetry (ex: `langfuse`) |
| `LANGFUSE_PUBLIC_KEY` | Chave pública Langfuse |
| `LANGFUSE_SECRET_KEY` | Chave secreta Langfuse |
| `LANGFUSE_BASE_URL` | URL do servidor Langfuse |

### Push / Firebase
| Config | O que faz |
|---|---|
| `FIREBASE_PROJECT_ID` | ID do projeto Firebase |
| `FIREBASE_CREDENTIALS` | JSON de credenciais |

### UI / Customização
| Config | O que faz | Padrão |
|---|---|---|
| `LOGOUT_REDIRECT_LINK` | Para onde redirecionar após logout | `/app/login` |
| `DISABLE_USER_PROFILE_UPDATE` | Bloqueia edição de perfil pelo usuário | — |
| `WIDGET_TOKEN_EXPIRY` | Expiração do token do widget (dias) | `180` |
| `DASHBOARD_SCRIPTS` | Scripts JS injetados no dashboard | — |

---

## Estrutura de Diretórios Resumida

```
starchat_app/
├── app/
│   ├── models/
│   │   └── channel/          ← 13 tipos de canal
│   ├── controllers/
│   │   ├── api/v1/accounts/  ← API principal
│   │   ├── api/v2/accounts/  ← Reports avançados
│   │   ├── webhooks/         ← Webhooks de entrada
│   │   └── super_admin/      ← Painel admin
│   ├── services/             ← Lógica de negócio
│   ├── jobs/                 ← Background jobs (~86)
│   └── listeners/            ← Event listeners
├── starchat/                 ← Engine de features enterprise
│   ├── app/
│   │   ├── models/cosmos/    ← IA — assistants, docs, tools
│   │   ├── controllers/api/v1/accounts/cosmos/
│   │   ├── services/cosmos/  ← LLM, embeddings, tools
│   │   └── jobs/             ← Jobs específicos
│   └── lib/cosmos/           ← Core library
├── config/
│   ├── features.yml          ← 64 feature flags
│   ├── installation_config.yml ← 70+ configurações globais
│   └── routes.rb             ← Todas as rotas
└── app/javascript/
    └── dashboard/            ← Frontend Vue.js
        └── routes/dashboard/
            ├── cosmos/       ← UI do Cosmos
            └── settings/     ← Configurações
```
