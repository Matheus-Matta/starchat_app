# Funcionalidade Anti Spam para Inboxes

Esta funcionalidade foi desenvolvida para prevenir que agentes (ou automações agindo como agentes) enviem mensagens repetitivas excessivas em um curto período de tempo dentro de uma mesma inbox.

## Como funciona

O sistema monitora as mensagens enviadas (**outgoing**) por users (agentes) em cada inbox. Antes de salvar uma nova mensagem, ele verifica:

1. Se a funcionalidade Anti Spam está ativa na Inbox atual.
2. Se o conteúdo da nova mensagem é **similar** a mensagens enviadas recentemente pelo mesmo agente na mesma inbox.
3. Se a quantidade de mensagens similares, dentro de uma **janela de tempo** configurada, excede o **limite máximo** permitido.

Se o limite for excedido, o sistema **bloqueia** o envio da nova mensagem e retorna um erro visual "clean" (âmbar) no frontend, impedindo o spam e protegendo a integração (especialmente WhatsApp) de bloqueios por automação repetitiva.

### Detalhes da Similaridade (Smart Detection)

Diferente de sistemas que apenas bloqueiam mensagens idênticas, este algoritmo foi aprimorado para detectar variações comuns utilizadas para burlar filtros de spam.

**1. Normalização Agressiva:**
Antes de comparar, o texto é tratado para ignorar "disfarces":

- **Acentos:** `Olá` = `Ola`
- **Pontuação e Emojis:** `Oi!!!` = `Oi`
- **Espaços:** `promoção  hoje` = `promocaohoje`
- **Case:** `PROMOÇÃO` = `promocao`

**2. Similaridade Semântica (Tokens):**
O sistema quebra a mensagem em palavras-chave (tokens) e compara com o histórico recente do usuário.

- Se uma mensagem compartilha **mais de 70%** dos seus tokens (palavras > 2 letras) com uma mensagem anterior, ela é considerada uma **repetição**.

**Exemplos Identificados como Spam:**

- `"Promoção imperdível! Corra"` vs `"Venha, Promoção imperdível..."` (Núcleo "Promoção", "imperdível" se repete).
- `"Bom dia"` vs `"Bom dia!!!"` (Normalização torna iguais).

## Configuração

A configuração é feita individualmente por inbox (Caixa de Entrada) na aba "Configurações".

Os parâmetros configuráveis são:

- **Ativar Anti Spam**: Habilita ou desabilita a verificação para a inbox.
- **Máximo de mensagens idênticas/similares**: Número máximo de vezes que mensagens com conteúdo similar podem ser enviadas dentro da janela de tempo. (Ex: 5)
- **Janela de tempo (minutos)**: O período de tempo em que as mensagens são memorizadas para comparação. (Ex: 1 minuto)

### Exemplo Prático

Se configurado para **3 mensagens** em **5 minutos**:

1. Agente envia: `"Promoção de Natal!"` (OK, contagem: 1)
2. Agente envia: `"Promoção de Natal! Aproveite"` (Similaridade alta detected. Contagem: 2)
3. Agente envia: `"PROMOÇÃO DE NATAL"` (Similaridade alta detected. Contagem: 3)
4. Agente tenta enviar: `"Corre pra Promoção de Natal"` (Similaridade alta detected. **BLOQUEADO**)

## Implementação Técnica

- **Backend**:

  - `Inbox` model possui uma coluna `anti_spam_config` (JSONB).
  - `Messages::MessageBuilder` realiza a verificação (`check_anti_spam`).
  - **Redis Lists**: Em vez de contadores simples, mantemos uma lista (`anti_spam_history:inbox:ID:user:ID`) com os tokens das últimas 100 mensagens enviadas pelo usuário.
  - O cálculo de similaridade é feito em Ruby comparando a interseção de tokens da nova mensagem com o histórico armazenado no Redis.

- **Frontend**:
  - `Settings.vue`: Interface de configuração.
  - `MessageError.vue`: Exibe erro de spam com destaque visual diferenciado (texto âmbar sem borda) para feedback imediato ao agente.
