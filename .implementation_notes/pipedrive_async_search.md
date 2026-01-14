# Implementação: Busca Assíncrona Dinâmica no Filtro Pipedrive

## Data: 2026-01-13

## Objetivo

Melhorar a performance e UX dos filtros do Pipedrive implementando busca assíncrona com debounce para usuários, pessoas e organizações.

## Mudanças Implementadas

### Backend

#### 1. Controller (`pipedrive_controller.rb`)

Adicionados 3 novos endpoints:

- `GET /users` - Lista 5 usuários
- `GET /persons?term=...` - Busca pessoas (5 resultados)
- `GET /organizations?term=...` - Busca organizações (5 resultados)

#### 2. Service (`browse_resources_service.rb`)

Adicionados 3 novos métodos:

```ruby
def users
  # Retorna lista de usuários com id, name, email
end

def persons
  # Busca por termo ou retorna os primeiros 5
  # Retorna id, name, email
end

def organizations
  # Busca por termo ou retorna os primeiros 5
  # Retorna id, name
end
```

#### 3. Routes (`routes.rb`)

Adicionadas rotas no namespace integrations/pipedrive:

```ruby
get :users
get :persons
get :organizations
```

#### 4. API Client Ruby (`pipedrive_client.rb`)

Mantém lógica de resolução de nomes para IDs:

- `find_user_id_by_name(name)`
- `find_person_id_by_name(name)`
- `find_org_id_by_name(name)`

Agora são usados pelos novos endpoints, mas não mais diretamente pelos filtros do frontend.

### Frontend

#### 1. API Client JS (`pipedrive.js`)

Adicionados métodos:

```javascript
getUsers((term = ''));
getPersons((term = ''));
getOrganizations((term = ''));
```

#### 2. Filtro (`PipedriveFilter.vue`)

**Imports adicionados:**

```javascript
import { useDebounceFn } from '@vueuse/core';
import PipedriveAPI from 'dashboard/api/pipedrive';
```

**Funções de busca assíncrona com debounce (500ms):**

- `fetch Users(query, setOptions, setLoading)`
- `fetchPersons(query, setOptions, setLoading)`
- `fetchOrganizations(query, setOptions, setLoading)`

**Mudança nos FilterTypes:**
Antes:

```javascript
{
  attributeKey: 'user_name',
  inputType: 'text',
  // ...
}
```

Depois:

```javascript
{
  attributeKey: 'owner_id',
  inputType: 'asyncSearchSelect',
  fetchOptions: fetchUsers,
  // ...
}
```

**Lógica no applyFilter:**
Agora extrai IDs de objetos selecionados:

```javascript
if (
  attribute === 'org_id' ||
  attribute === 'person_id' ||
  attribute === 'owner_id'
) {
  if (typeof rawValue === 'object' && rawValue !== null && rawValue.id) {
    payload[attribute] = rawValue.id;
  }
}
```

## Benefícios

1. **Performance**:

   - Busca assíncrona com debounce de 500ms
   - Apenas 5 resultados iniciais
   - Reduz chamadas à API

2. **UX**:

   - Usuário vê opções reais do Pipedrive
   - Sem erros de digitação
   - Seleção visual mais clara

3. **Código mais limpo**:
   - IDs são enviados diretamente ao backend
   - Não precisa resolver nomes para IDs no backend durante filtragem
   - Menos chance de erros

## Compatibilidade

- Mantém compatibilidade com filtros salvos antigos
- Backend ainda suporta filtros por nome (user_name, person_name, org_name)
- Novos filtros usam IDs diretamente (owner_id, person_id, org_id)

## TODO

1. Verificar se o `ConditionRow` suporta `inputType: 'asyncSearchSelect'`
   - Se não, criar componente customizado ou adaptar
2. Adicionar loading states nos selects
3. Adicionar tratamento de erro nas buscas
4. Considerar cache local para reduzir chamadas repetidas
