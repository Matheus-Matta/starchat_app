# Guia de Políticas de Atribuição de Conversas

> **Pré-requisito:** A feature `assignment_v2` deve estar habilitada na conta.

---

## Onde fica na plataforma

**Settings → Agent Assignment** (menu lateral, seção Settings)

A tela tem duas seções:
- **Assignment Policy** — define *como* e *para qual agente* as conversas são roteadas dentro de um inbox
- **Agent Capacity Policy** — define *quantas* conversas cada agente pode ter ao mesmo tempo

---

## Conceito: duas camadas de roteamento

O mercado de CRMs e helpdesks organiza a distribuição de conversas em duas camadas:

| Camada | Pergunta respondida | Onde configurar |
|---|---|---|
| **Roteamento (triagem)** | Para qual inbox/fila a conversa vai? | Regras de criação de conversa / canais |
| **Atribuição** | Para qual agente dentro daquele inbox? | **Assignment Policy** ← estamos aqui |

---

## Parte 1 — Assignment Policy (Política de Atribuição)

### O que é

Define as regras de atribuição de conversas para um ou mais inboxes. Sem política configurada, o sistema usa **Round Robin puro** (comportamento padrão).

### Como criar

**Settings → Agent Assignment → Assignment Policy → "New policy"**

| Campo | O que acontece quando preenchido |
|---|---|
| **Nome** | Identifica a política na lista |
| **Descrição** | Texto de referência, não afeta o comportamento |
| **Status** | Inativo = o inbox vinculado volta ao round-robin padrão |
| **Modo de operação** | Define o algoritmo de atribuição (ver abaixo) |
| **Inboxes vinculados** | Inboxes para os quais esta política se aplica (uma política por inbox) |

---

## Parte 2 — Modos de Operação

O campo **"Modo de operação"** unifica em uma escolha as opções de como as conversas são distribuídas. Há 4 modos predefinidos:

---

### 🔄 Round Robin (padrão)

Distribui em sequência circular entre agentes disponíveis: A → B → C → A → B → C…

**Configuração predefinida (sem parâmetros extras):**
- Ordem de chegada: conversa mais antiga primeiro
- Sem limite de janela de tempo
- Sem limite de conversas por agente

**Quando usar:**
- Times pequenos com volume previsível
- Quando a equidade de turno é mais importante que o equilíbrio de carga
- Vendas e leads (todos devem receber oportunidades iguais em sequência)

**Exemplo:** Equipe de 3 agentes, 9 conversas → cada um recebe 3, em ordem.

---

### 📊 Equal Distribution (Distribuição Igualitária)

Atribui ao **agente com menos conversas dentro de uma janela de tempo**. Se a carga já estiver equilibrada (diferença abaixo do limiar), usa round-robin como fallback.

**Parâmetros configuráveis ao selecionar este modo:**

| Parâmetro | Padrão | O que faz |
|---|---|---|
| **Janela de tempo (horas)** | 24h | Conta apenas conversas abertas nas últimas N horas para calcular a carga. `0` = conta todas as conversas abertas. |
| **Limiar de desequilíbrio (%)** | 20% | % mínima de diferença entre agentes para ativar a distribuição igualitária. Abaixo disto, usa round-robin. |

**Exemplo:** Ana tem 12 conversas, Bruno tem 8, Carla tem 10 (janela 24h).
- Diferença máx: (12-8)/12 × 100 ≈ 33% → acima do limiar de 20%
- Próxima conversa vai para **Bruno** (menor carga)

**Quando usar:**
- Suporte com casos de tamanhos diferentes onde a sequência pura seria injusta
- Times com picos de demanda onde um agente pode ficar sobrecarregado
- Quando você quer equilíbrio de carga dentro de um turno/dia

---

### ⚖️ Balanced (Equilibrado)

Sempre atribui ao **agente com menos conversas abertas** no momento, sem janela de tempo.

**Configuração predefinida:**
- Considera todas as conversas abertas (sem janela)
- Sempre escolhe o menos carregado, sem fallback para round-robin

**Diferença para Equal Distribution:**
- Equal Distribution usa uma janela e respeita um limiar (tem fallback para RR)
- Balanced é absoluto: sempre o menos carregado, sem exceção

**Quando usar:**
- Suporte técnico com tickets de tamanhos muito diferentes
- Times onde evitar sobrecarga é mais importante do que sequência
- SLAs apertados onde cada agente deve ter carga equilibrada

---

### ⚙️ Custom (Personalizado) — Enterprise

Expõe todos os controles granulares para configuração manual:

| Campo | Opções | Descrição |
|---|---|---|
| **Assignment order** | `Round Robin`, `Balanced` | Algoritmo base de seleção do agente |
| **Conversation priority** | `Earliest created`, `Longest waiting` | Qual conversa da fila é atribuída primeiro |
| **Fair distribution limit** | Número inteiro (padrão: 100) | Máximo de conversas por agente dentro da janela |
| **Fair distribution window** | Minutos ou horas (padrão: 60 min) | Duração da janela para o limite acima |

**Quando usar:**
- Regras específicas que os modos predefinidos não cobrem
- Ex.: Round Robin mas priorizando quem espera há mais tempo
- Ex.: limite de 50 conversas por agente por hora com Balanced

---

## Parte 3 — Vinculação de Inboxes

Após criar a política, vincule um ou mais inboxes na aba de edição da policy.

> **Regra:** Cada inbox pode estar vinculado a apenas **uma** política de atribuição.
> Se um inbox já vinculado for adicionado a outra política, ele é automaticamente desvinculado da anterior.

**O que acontece ao vincular um inbox:**
- A política passa a controlar a atribuição de **todas** as novas conversas daquele inbox
- Conversas existentes não são reatribuídas
- Se a política for desativada (Status = Inativo), o inbox volta ao round-robin padrão

---

## Parte 4 — Agent Capacity Policy

### O que é

Define um **limite de conversas simultâneas** por inbox para cada agente, além de **regras de exclusão** que determinam quais conversas não contam para a capacidade.

### Como criar

**Settings → Agent Assignment → Agent Capacity Policy → "New policy"**

### Configurações disponíveis

#### Limites por inbox

| Campo | Comportamento |
|---|---|
| **Inbox** | Inbox ao qual o limite se aplica |
| **Max conversations** | Agentes vinculados a esta policy não recebem mais conversas deste inbox quando já atingiram o limite |

> Se não houver limite configurado para um inbox, agentes podem receber conversas sem restrição de quantidade.

#### Regras de exclusão

Definem quais conversas **não contam** para a capacidade do agente:

| Regra | Efeito |
|---|---|
| **Excluir conversas com etiqueta X** | Conversas com a etiqueta informada não são contadas no limite |
| **Excluir conversas com mais de N horas** | Conversas abertas há mais de N horas não são contadas |

**Exemplo prático:** Agente tem limite de 10 conversas no inbox Suporte. Porém, conversas marcadas como "VIP" não contam. Se o agente tem 9 conversas normais + 3 VIP = 9 de capacidade usada, então pode receber mais 1 conversa normal.

---

## Parte 5 — Cenários de uso comuns

### Cenário 1: Time pequeno de vendas

- **Modo:** Round Robin
- **Motivo:** Equidade de oportunidades entre vendedores; todos recebem leads em sequência.

### Cenário 2: Suporte com picos de demanda

- **Modo:** Equal Distribution (janela 8h, limiar 25%)
- **Motivo:** Evita sobrecarregar quem chegou cedo e já tem muitas conversas abertas.

### Cenário 3: Agentes júnior e sênior

- **Modo:** Custom (Balanced + Conversation priority: Longest waiting)
- **Capacity Policy:** Limite diferente por agente via políticas separadas
- **Motivo:** Sênior recebe conversas mais antigas; capacidade maior.

### Cenário 4: Atendimento fora do horário comercial

- **Modo:** Round Robin (padrão)
- **Capacity Policy:** Excluir conversas com mais de 8h
- **Motivo:** Conversas abertas no dia anterior não "poluem" a contagem do próximo turno.

### Cenário 5: Fila com grande backlog

- **Modo:** Equal Distribution (janela 0h = todas abertas, limiar 15%)
- **Motivo:** Com muitas conversas acumuladas, a janela de 24h seria insuficiente; contar todas garante que ninguém fique sobrecarregado.

### Cenário 6: Priorizar quem espera há mais tempo

- **Modo:** Custom (Round Robin + Longest waiting)
- **Motivo:** A ordem de chegada dos agentes é sequencial, mas dentro da fila, a conversa mais antiga é atribuída primeiro.

---

## Referência rápida

| Objetivo | Modo | Parâmetros principais |
|---|---|---|
| Equidade de turno, volume previsível | Round Robin | — |
| Equilíbrio de carga por turno/dia | Equal Distribution | Janela 8–24h, Limiar 20% |
| Nunca sobrecarregar ninguém | Balanced | — |
| Regras específicas | Custom | Order + Priority + Fair distribution |
| Limitar conversas simultâneas | Agent Capacity Policy | Inbox + Max conversations |
| Ignorar conversas antigas na contagem | Agent Capacity Policy | Excluir conversas > N horas |

---

## Apêndice técnico

### Fluxo de decisão do backend (assignment_service.rb)

```
Nova conversa chega ao inbox
        ↓
╔════════════════════════════════╗
║ Inbox tem política vinculada?  ║
╚════════════════════════════════╝
     Sim ↓                   Não → Round Robin (padrão Starchats)
         ↓
╔═══════════════════════════════════════╗
║ policy.equal_distribution? (modo ED) ║
╚═══════════════════════════════════════╝
     Sim → EqualDistributionSelector(policy.window_hours, policy.balance_threshold)
     Não ↓
╔═══════════════════════════╗
║ policy.balanced? (Balanced)║
╚═══════════════════════════╝
     Sim → BalancedSelector (menor carga total)
     Não → RoundRobinSelector (fila circular Redis)
```

### Modelos de dados relevantes

```
AssignmentPolicy
  ├── name, description, enabled
  ├── assignment_order: enum(round_robin, balanced, equal_distribution)
  ├── conversation_priority: enum(earliest_created, longest_waiting)
  ├── fair_distribution_limit, fair_distribution_window
  ├── equal_distribution_window_hours (padrão 24)
  ├── equal_distribution_balance_threshold (padrão 20)
  └── has_many :inbox_assignment_policies → :inboxes

AgentCapacityPolicy
  ├── name, description, enabled
  ├── exclusion_rules: jsonb
  │     ├── excluded_labels: []
  │     └── exclude_older_than_hours: integer
  └── has_many :inbox_capacity_limits

InboxCapacityLimit
  ├── belongs_to :agent_capacity_policy
  ├── belongs_to :inbox
  └── conversation_limit: integer
```

### Arquivos principais

| Arquivo | Responsabilidade |
|---|---|
| `starchat/app/services/starchat/auto_assignment/assignment_service.rb` | Resolve o seletor com base na política |
| `starchat/app/services/starchat/auto_assignment/equal_distribution_selector.rb` | Algoritmo de distribuição igualitária |
| `starchat/app/services/starchat/auto_assignment/balanced_selector.rb` | Algoritmo de carga mínima |
| `app/models/assignment_policy.rb` | Modelo e enum assignment_order |
| `starchat/app/models/starchat/concerns/assignment_policy.rb` | Adiciona balanced + equal_distribution ao enum (premium) |
| `app/javascript/.../assignmentPolicy/pages/components/AgentAssignmentPolicyForm.vue` | Formulário com seleção de modo |
| `app/javascript/.../assignmentPolicy/constants.js` | Constantes de modos e defaults |
