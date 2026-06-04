# Auto Assignment — Round Robin

## Visão Geral

O sistema de atribuição automática distribui conversas sem atribuição entre agentes disponíveis. Existem **duas versões**:

| Versão | Condição de ativação | Serviço principal |
|---|---|---|
| **Legacy** | Feature `assignment_v2` desabilitada | `AutoAssignment::AgentAssignmentService` |
| **V2 (atual)** | Feature `assignment_v2` habilitada na conta | `AutoAssignment::AssignmentService` + módulo `Starchat` |

---

## Arquivos Principais

```
app/
  jobs/auto_assignment/
    assignment_job.rb               → Job de atribuição por inbox
    periodic_assignment_job.rb      → Job periódico (scheduled_jobs)
  services/auto_assignment/
    assignment_service.rb           → Orquestrador principal (V2)
    agent_assignment_service.rb     → Orquestrador legacy
    inbox_round_robin_service.rb    → Gerencia a fila Redis
    round_robin_selector.rb         → Adapter para o InboxRoundRobinService
    rate_limiter.rb                 → Controle de rate limit por agente
  models/
    assignment_policy.rb            → Política de atribuição (order, priority, limits)
    concerns/
      auto_assignment_handler.rb    → Gatilho after_save na conversa
      inbox_agent_availability.rb   → Filtra agentes online

starchat/app/services/starchat/auto_assignment/
    assignment_service.rb           → Override Starchat: capacity, exclusions, balanced
    balanced_selector.rb            → Modo de seleção balanceado (menor carga)
    capacity_service.rb             → Verifica capacidade por inbox/agente
```

---

## 1. Gatilho de Execução

Definido em `AutoAssignmentHandler` (`app/models/concerns/auto_assignment_handler.rb`).

Dispara toda vez que uma conversa muda de status para `open`, desde que:
1. `inbox.enable_auto_assignment?` seja `true`
2. A conversa não tenha atribuído, ou o atribuído não seja membro da inbox

```ruby
# V2 → enfileira o job (assíncrono)
AutoAssignment::AssignmentJob.perform_later(inbox_id: inbox.id)

# Legacy → executa inline (síncrono)
AutoAssignment::AgentAssignmentService.new(...).perform
```

Além do gatilho por evento, `PeriodicAssignmentJob` executa periodicamente na fila `scheduled_jobs`, varrendo todas as inboxes com `assignment_policy` ativa.

---

## 2. A Fila Round-Robin no Redis

Gerenciada por `AutoAssignment::InboxRoundRobinService`.

**Chave Redis:** `ROUND_ROBIN_AGENTS[inbox_id]` (Redis List)

Cada item da lista é um `user_id` de membro da inbox.

### Operações de manutenção

| Operação | Quando ocorre |
|---|---|
| `add_agent_to_queue` (`LPUSH`) | Agente adicionado à inbox |
| `remove_agent_from_queue` (`LREM`) | Agente removido da inbox |
| `reset_queue` | Fila inválida (membros divergem da lista Redis) |
| `validate_queue?` | Antes de toda seleção |

### Lógica de seleção — ciclo circular

```
1. Busca fila atual via LRANGE
2. Faz intersecção com IDs dos agentes disponíveis (online + dentro dos limites)
3. Seleciona o ÚLTIMO da intersecção (.pop → mais antigo na fila = menos recente)
4. Remove o agente selecionado (LREM)
5. Reinsere no INÍCIO da fila (LPUSH)
```

Resultado: quem recebeu a última conversa vai para o início da fila e só será selecionado novamente depois de todos os outros.

---

## 3. Pipeline de Filtros (V2 com Starchat)

Antes de um agente ser elegível para receber uma conversa, ele passa por três filtros em cascata:

```
inbox.available_agents
         │
         ▼
  Filtro 1: ONLINE
  (OnlineStatusTracker — apenas status "online", não "busy")
         │
         ▼
  Filtro 2: RATE LIMIT
  (RateLimiter — fair_distribution_limit / janela de tempo)
         │
         ▼
  Filtro 3: CAPACITY
  (CapacityService — limite de conversas abertas por inbox)
         │
         ▼
  Seleção: RoundRobin ou Balanced
```

### Filtro 1 — Status Online

Arquivo: `app/models/concerns/inbox_agent_availability.rb`

- Consulta `OnlineStatusTracker.get_available_users(account_id)` no Redis
- Retorna apenas membros com valor `"online"` (exclui `"busy"`)

### Filtro 2 — Rate Limit

Arquivo: `app/services/auto_assignment/rate_limiter.rb`

- Configurado via `AssignmentPolicy` nos campos:
  - `fair_distribution_limit` — número máximo de atribuições (padrão: **100**)
  - `fair_distribution_window` — janela de tempo em segundos (padrão: **3600s = 1h**)
- Rastreia cada atribuição como uma chave Redis com TTL igual à `window`
- Se `current_count >= limit`, o agente é **excluído** da rodada

### Filtro 3 — Capacity por Inbox

Arquivo: `starchat/app/services/starchat/auto_assignment/capacity_service.rb`

- Requer `AgentCapacityPolicy` vinculada ao `AccountUser`
- Verifica `InboxCapacityLimit#conversation_limit` para a inbox específica
- Conta conversas `open` atribuídas ao agente naquela inbox
- Se `current_count >= conversation_limit`, o agente é **excluído**

> Se não existir `InboxCapacityLimit` para aquela inbox, o agente tem capacidade ilimitada nela.

---

## 4. Prioridade de Conversas

Controlada pelo campo `conversation_priority` de `AssignmentPolicy`.

| Valor | Ordenação SQL | Comportamento |
|---|---|---|
| `earliest_created` *(padrão)* | `created_at ASC` | Conversa mais antiga criada primeiro |
| `longest_waiting` | `last_activity_at ASC, created_at ASC` | Conversa sem atividade há mais tempo primeiro |

---

## 5. Modo de Seleção do Agente

Controlado pelo campo `assignment_order` de `AssignmentPolicy`.

| Modo | Classe | Lógica |
|---|---|---|
| `round_robin` *(padrão)* | `AutoAssignment::RoundRobinSelector` | Fila Redis circular |
| `balanced` *(Premium)** | `Starchat::AutoAssignment::BalancedSelector` | Agente com **menos** conversas abertas no momento |

O `BalancedSelector` **ignora** a fila Redis e usa `min_by` sobre o count de conversas abertas:

```ruby
agent_users.min_by { |user| assignment_counts[user.id] || 0 }
```

---

## 6. Regras de Exclusão de Conversas

Definidas em `AgentCapacityPolicy#exclusion_rules` e aplicadas pelo módulo Starchat.

| Regra | Efeito |
|---|---|
| `excluded_labels` | Pula conversas que possuam determinadas labels |
| `exclude_older_than_hours` | Pula conversas criadas há mais de N horas |

---

## 7. Limite Legado por Inbox (`max_assignment_limit`)

Configurado via JSON `auto_assignment_config` diretamente na Inbox.

- Exclui agentes que já possuem `>= max_assignment_limit` conversas abertas naquela inbox
- É o mecanismo de capacidade disponível antes do `AgentCapacityPolicy`

---

## 8. Auditoria

Toda atribuição automática registra um `Starchat::AuditLog` com os seguintes campos:

| Campo | Descrição |
|---|---|
| `assignee_id` | `[nil, agent.id]` — antes e depois |
| `assignment_source` | `auto_assignment_v2` ou `auto_assignment_legacy` |
| `queue_before` / `queue_after` | Snapshot da fila Redis (até 50 itens) |
| `queue_before_size` / `queue_after_size` | Tamanho da fila antes e depois |
| `available_agent_user_ids` | IDs dos agentes elegíveis naquela rodada |
| `inbox_id` / `conversation_display_id` | Identificadores da conversa |

---

## 9. Fluxo Completo (V2)

```
Conversa muda para status "open"
    │
    ▼
AutoAssignmentHandler#run_auto_assignment
    │
    ▼
AssignmentJob enfileirado (queue: default)
    │
    ▼
AssignmentService#perform_bulk_assignment (limite: 100 ou ENV AUTO_ASSIGNMENT_BULK_LIMIT)
    │
    ▼
Para cada conversa sem atribuição (ordenada por conversation_priority):
    │
    ├─ assignable? → status == "open" && assignee_id == nil
    │
    ▼
find_available_agent
    ├─ Filtra por online
    ├─ Filtra por rate limit
    └─ Filtra por capacity
         │
         ├─ Nenhum disponível? → pula conversa
         │
         ▼
    round_robin_selector.select_agent(agents)
         ├─ Valida fila Redis (reset se divergente)
         ├─ Intersecta fila com agentes disponíveis
         └─ Rotaciona fila (pop + push)
              │
              ▼
    assign_conversation(conversation, agent)
         ├─ conversation.update!(assignee: agent)
         ├─ rate_limiter.track_assignment(conversation)
         ├─ log_assignment_audit(...)
         └─ dispatch ASSIGNEE_CHANGED event
```

---

## 10. Configuração Resumida

```
AssignmentPolicy
  ├── assignment_order        → round_robin | balanced
  ├── conversation_priority   → earliest_created | longest_waiting
  ├── fair_distribution_limit → máx. atribuições por agente na janela (padrão: 100)
  └── fair_distribution_window → janela em segundos (padrão: 3600)

AgentCapacityPolicy (por AccountUser)
  └── InboxCapacityLimit (por inbox)
        ├── conversation_limit  → máx. conversas abertas simultâneas
        └── exclusion_rules
              ├── excluded_labels
              └── exclude_older_than_hours

Inbox.auto_assignment_config (legado)
  └── max_assignment_limit    → máx. conversas abertas por agente naquela inbox
```
