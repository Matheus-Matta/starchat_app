## 4. Construir "Sistemas de Protocolos do SAC" amarrados no Inbox

### 4.1 Diagnóstico (contexto real de SAC moderno)

Em operações de SAC/Helpdesk, **um protocolo legível** é indispensável porque ele vira a “chave humana” do atendimento:

- Cliente consegue **citar no WhatsApp/telefone** sem precisar de link.
- Equipe localiza rápido no Chatwoot e no ERP (pedido, nota, entrega).
- Gestão audita SLA, reaberturas e volume por canal/loja.
- Permite padronizar integrações (Logística, Assistência Técnica, Financeiro, Montagem).

O ID interno do Chatwoot é técnico demais e não atende a esse papel (principalmente quando existem múltiplas inboxes/canais e múltiplas lojas).

Além disso, hoje o Chatwoot já trabalha muito bem com **Custom Attributes** (atributos customizados) para padronizar dados operacionais do atendimento (pedido, categoria, SLA, prioridade etc.). Vamos aplicar **a mesma lógica**: criar **Protocolos/Políticas** como entidades configuráveis, vinculadas a uma Inbox.

---

### 4.2 Forma de funcionamento (modelo “Custom” aplicado a Protocolos)

Vamos criar um **módulo de Protocolos** com **políticas configuráveis** e **vinculáveis a uma Inbox**, permitindo:

- Ter **diferentes políticas e formatos** por inbox (SAC, VIP, POS, Assistência, Lojas…).
- **Gerar o protocolo automaticamente** ao abrir conversa.
- **Analisar e reportar separadamente** por inbox/política (SAC vs VIP vs Assistência).
- Exibir o protocolo como **campo próprio** (UI) e também como **custom attribute**, para filtros e automações.

**Conceito central**

- `ProtocolPolicy` (Política de Protocolo) = “como gerar + como exibir + como analisar”
- `Inbox` aponta para **uma** `ProtocolPolicy` (ou permitir múltiplas e escolher por regra).
- `Conversation` recebe `protocol_code` + metadados (política usada, seq, data).

---

### 4.3 Objetivo do protocolo

Criar um **código único, curto, rastreável, pesquisável** e com significado operacional:

- **Amarrado ao Inbox** via política (SAC, VIP, POS, ASSIST, LOJA-X)
- Identifica **data** do atendimento
- Possui **sequência incremental** (evita colisão, facilita auditoria)
- Exibido na UI e retornado na API
- Entra automaticamente em mensagens/macros: “Seu protocolo é: …”
- Permite **relatórios por Inbox/Política**

---

### 4.4 Padrão recomendado (formato) + políticas por Inbox

**Formato padrão (curto e auditável):**
`{PREFIX}-{YYMMDD}-{SEQ4}`
Ex.: `SAC-260307-0042`

**Variações por política (se precisar por loja/filial):**

- `SAC-NIT-260307-0042` (cidade/loja)
- `ASSIST-260307-0123` (assistência técnica)
- `VIP-260307-0007` (VIP/WhatsApp marketing)

**Regras (configuráveis na ProtocolPolicy):**

- `prefix`: ex.: `SAC`, `VIP`, `POS`, `ASSIST`
- `scope`: `daily` (sequência reinicia por dia) | `global` (sequência contínua)
- `include_store_code`: boolean
- `include_city_code`: boolean
- `seq_padding`: default 4 (`0001`)
- `timezone`: herda da conta, mas pode ser sobrescrito

**Vinculação**

- A Inbox passa a ter `protocol_policy_id` (ou um `protocol_policy_code`)
- Assim, cada Inbox tem sua **política própria** e relatórios ficam naturalmente segmentados.

---

### 4.5 Implementação (Backend + DB) — robustez e governança

#### 4.5.1 Banco de Dados

**Tabela nova: `protocol_policies`**

- `id`
- `name` (ex.: “SAC Padrão”, “Assistência Técnica”)
- `prefix`
- `scope` (`daily|global`)
- `seq_padding` (default 4)
- flags opcionais: `include_store_code`, `include_city_code`
- `active` (boolean)
- timestamps

**Alterações em `inboxes`**

- `protocol_policy_id` (FK)

**Alterações em `conversations`**

- `protocol_code` (string, **unique**, **indexed**)
- `protocol_seq` (int, opcional)
- `protocol_date` (date, opcional)
- `protocol_policy_id` (FK para auditoria e relatório)

**(Opcional) Tabela de contador**

- `protocol_counters(inbox_id, date, last_seq)` para `daily`
- ou `protocol_counters(inbox_id, last_seq)` para `global`

#### 4.5.2 Gerador transacional

Criar `Conversations::ProtocolGenerator` chamado em `after_create` (ou no service que cria a conversa).
**Ponto crítico:** garantir sequência **sem colisão** em concorrência.

Estratégias:

1. **Sequence nativa do DB** (ideal)
2. **Tabela de contador com lock transacional**
   - `SELECT ... FOR UPDATE`, incrementa e salva
3. Fallback: retry com unique constraint (último caso)

---

### 4.6 UI / API / Busca + Sidebar “Protocolo”

#### 4.6.1 API

- Expor `protocol_code`, `protocol_policy_id` no JSON da conversa (`_conversation.json.jbuilder`)
- Permitir filtrar listagem por `protocol_code` (ex.: `?q=SAC-260307-0042`)
- Permitir filtrar por `inbox_id` / `protocol_policy_id` para análises segmentadas
- Index em `protocol_code` para busca instantânea

#### 4.6.2 UI (Dashboard Chatwoot)

**Campo dedicado**

- Exibir `protocol_code` como **campo próprio** na conversa (header) e com botão “copiar”.

**Sidebar**

- Criar uma seção fixa no sidebar: **“Protocolo”**
  - Mostra: `protocol_code`, `policy`, `data`, `sequência`
  - Botão “Copiar”
  - Link rápido: “Ver relatório desta política”

> Importante: apesar de termos campo dedicado, também gravar como custom attribute facilita filtros/automations sem depender 100% de custom UI.

#### 4.6.3 Mensagens e macros (padrão helpdesk)

- Inserir automaticamente em mensagem inicial (configurável por política):
  - “Atendimento iniciado ✅ Protocolo: **SAC-260307-0042**”
- Variável para templates:
  - `{{conversation.protocol_code}}`

---

### 4.7 Relatório de Protocolos (novo)

Criar um relatório dedicado (aba “Reports” ou nova tela) com:

- Total de protocolos por período
- Volume por **Inbox**
- Volume por **ProtocolPolicy**
- Ranking de motivos/tags por política (opcional)
- Tempo médio 1ª resposta / resolução por política (integração com o item de SLA/inatividade)

**Export**

- CSV/Excel com colunas: `protocol_code`, `inbox`, `policy`, `status`, `created_at`, `first_response_at`, `resolved_at`, `assignee`, `tags`, `custom_attributes` principais

---

### 4.8 Permissões (Custom Roles) — gerenciamento de protocolos

Adicionar permissões específicas para governança:

- `protocols.view` (ver protocolo e relatórios)
- `protocols.manage` (criar/editar políticas, vincular políticas a inbox)

**Regras sugeridas**

- Agentes: `protocols.view` or `protocols.manage`
- Supervisores/Coordenadores: `protocols.view` or `protocols.manage`
- Admin/Owner: todas, incluindo `protocols.manage`

---

### 4.9 Critérios de aceite (Definition of Done)

- [ ] Existe `ProtocolPolicy` com CRUD (mínimo: criar/editar/ativar)
- [ ] Inbox pode ser vinculada a uma `ProtocolPolicy`
- [ ] Toda conversa nova gera `protocol_code` automaticamente e único
- [ ] Não há duplicidade sob concorrência (teste com 100 criações simultâneas)
- [ ] UI mostra protocolo no header + seção no sidebar + botão copiar
- [ ] Busca por protocolo encontra a conversa
- [ ] Relatório de Protocolos por Inbox/Política disponível + export
- [ ] Permissões em Custom Roles controlam acesso (view/manage/reports)
- [ ] Logs de integração (ERP/Logística) armazenam o protocolo como chave

---

### 4.10 Protocolo como Recurso SAC — Anotações, Comentários e Arquivos

#### 4.10.1 Contexto e motivação

No padrão SAC de atendimento, o protocolo não é apenas um código de rastreio — ele é o **dossiê do atendimento**. Os agentes precisam:

- Registrar o **motivo real** da abertura (ex.: "Produto com defeito – NF 54321")
- Adicionar **anotações internas** ao longo do fluxo
- Anexar **evidências**: fotos, NF, XML, laudos, comprovantes de entrega
- Deixar comentários públicos (para o cliente rastrear) ou privados (para a equipe)

Isso segue o padrão de **protocolamento formal** usado em SAC regulado (Procon, ANATEL, ANVISA, etc).

#### 4.10.2 Modelo `Protocol` (recurso completo)

```
Protocol
  ├── code            string  UNIQUE NOT NULL   — código legível (SAC-260307-0042)
  ├── seq             integer NOT NULL
  ├── date            date    NOT NULL
  ├── status          enum    open | closed | archived
  ├── reason          string(500)  — motivo resumido da abertura (editável pelo agente)
  ├── description     text         — descrição detalhada / histórico SAC
  ├── problem         string       — tipo/classe do problema (categoria operacional)
  ├── closed_at       datetime
  ├── account_id      FK
  ├── contact_id      FK → contato vinculado
  ├── conversation_id FK → conversa de origem (nullable)
  └── protocol_policy_id FK
```

**Relacionamentos**

| Relação | Cardinalidade | Propósito |
|---|---|---|
| `Protocol → Conversations` | has_many | um protocolo abrange N conversas (reutilização) |
| `Protocol → ProtocolComments` | has_many | anotações/comentários do agente |
| `Protocol → files` (ActiveStorage) | has_many_attached | arquivos diretos no protocolo |
| `Contact → Protocols` | has_many | todos os protocolos de um cliente |

#### 4.10.3 Modelo `ProtocolComment` (anotações SAC)

```
ProtocolComment
  ├── content      text NOT NULL    — texto do comentário/anotação
  ├── is_private   boolean          — interno (equipe) ou visível
  ├── protocol_id  FK
  ├── account_id   FK
  ├── user_id      FK → agente
  └── files        ActiveStorage    — arquivos anexados ao comentário
```

**Casos de uso:**
- Agente registra que "trocou por telefone com o cliente em 09/03"
- Supervisor adiciona nota interna "escalar para logística"
- Anexar foto do produto com defeito diretamente na anotação
- Histórico auditável de todas as interações sobre o protocolo

#### 4.10.4 API Endpoints

```
# Protocolos
GET    /api/v1/accounts/:id/protocols             — lista (filtros: contact_id, status, q)
POST   /api/v1/accounts/:id/protocols             — criar manualmente
GET    /api/v1/accounts/:id/protocols/:pid        — detalhes
PATCH  /api/v1/accounts/:id/protocols/:pid        — editar reason/description/problem
DELETE /api/v1/accounts/:id/protocols/:pid        — arquivar
POST   /api/v1/accounts/:id/protocols/:pid/close  — encerrar protocolo
POST   /api/v1/accounts/:id/protocols/:pid/reopen — reabrir protocolo

# Comentários / Anotações
GET    /api/v1/accounts/:id/protocols/:pid/protocol_comments        — listar
POST   /api/v1/accounts/:id/protocols/:pid/protocol_comments        — criar (+ files[])
DELETE /api/v1/accounts/:id/protocols/:pid/protocol_comments/:cid   — excluir
```

#### 4.10.5 Campos editáveis pelo agente

| Campo | Quem edita | Observação |
|---|---|---|
| `reason` | Agente + Supervisor | Motivo resumido (obrigatório preenchimento quando fechar) |
| `description` | Agente + Supervisor | Campo livre/histórico |
| `problem` | Agente + Supervisor | Categoria operacional (defeito, entrega, financeiro…) |
| `status` | Supervisor + Admin | Transições: open → closed → archived |
| Comentários | Qualquer agente | Sempre rastreado com user_id |
| is_private | Agente | Campo `true` = visível só para equipe |

---

### 4.11 Reutilização de Protocolo por Contato (Encadeamento SAC)

#### 4.11.1 Motivação

No SAC real, o cliente pode:
- Mandar nova mensagem WhatsApp sobre o mesmo problema
- Ligar depois, abrindo uma nova conversa no mesmo canal
- Entrar por outro canal (email + WhatsApp) sobre o mesmo caso

Nesses cenários, **abrir um novo protocolo** seria errado — o atendimento deve continuar sob o mesmo registro SAC, possibilitando:
- Histórico unificado do caso
- Não "inflar" métricas de volume
- Garantir que o agente vê toda a linha do tempo do problema

#### 4.11.2 Regra de reutilização

```
Ao criar nova conversa com contato C na inbox I:
  → buscar Protocol.open_for_contact(contact_id: C, protocol_policy_id: I.protocol_policy_id)
  → se encontrar protocolo aberto:
       → vincular conversations.protocol_id = protocolo_existente.id
       → copiar protocol_code/date/seq para o registro legado da conversa
       → NÃO criar novo código/contador
  → se não encontrar:
       → gerar novo protocolo (código único, incrementar sequência)
       → vincular conversations.protocol_id = novo_protocolo.id
```

#### 4.11.3 Implicações no modelo de dados

```
# Protocol
has_many :conversations, foreign_key: :protocol_id   # N conversas mesmo protocolo

# Conversation
belongs_to :protocol, optional: true   # protocolo SAC (pode ser compartilhado)
protocol_code / protocol_seq / protocol_date  # campos legacy — mantidos para automações

# Contact
has_many :protocols     # todos os protocolos do cliente
```

#### 4.11.4 Quando encerrar automaticamente o encadeamento

O protocolo só é reutilizado enquanto está `status: open`. Ao fechar:
- Nova conversa do mesmo contato → **novo protocolo**
- Protocolo fechado fica como registro histórico imutável

Configuração opcional na `ProtocolPolicy`:
- `reuse_open_protocol` (boolean, default: true) — desabilitar por política se necessário

#### 4.11.5 Critérios de aceite adicionais (DoD — extensão issue 4)

- [ ] `Protocol` tem `status` (open/closed/archived) e transições `close!` / `reopen!`
- [ ] `Protocol` vinculado ao `Contact` via `contact_id`
- [ ] `Protocol` has_many `:conversations` (N conversas por protocolo)
- [ ] Ao nova conversa de contato com protocolo aberto → reutiliza sem gerar novo código
- [ ] Ao nova conversa de contato sem protocolo aberto → gera novo protocolo normalmente
- [ ] Agente pode editar `reason`, `description`, `problem` via UI e API
- [ ] Agente pode adicionar `ProtocolComment` (texto + arquivos) ao protocolo
- [ ] Comentários `is_private: true` visíveis apenas para equipe (não para cliente)
- [ ] Arquivos (fotos, NF, documentos) anexáveis tanto no protocolo quanto no comentário
- [ ] API retorna lista de protocolos filtrável por `contact_id`, `status`, `q` (código)
- [ ] Sidebar do contato exibe histórico de protocolos e status ( open / closed )

