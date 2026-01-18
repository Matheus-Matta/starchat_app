# Plano de Customização: Notificações e Emails Starchats

## 1. Traduções PT-BR Faltantes

### 1.1 Notificações (`config/locales/pt_BR.yml`)

- [x] Line 151: `conversation_creation` está vazio
  - Adicionar: "Uma conversa (#%{display_id}) foi criada na caixa de entrada %{inbox_name}"

### 1.2 Templates de Email (hardcoded)

Localização: `app/mailers/agent_notifications/conversation_notifications_mailer.rb`

Subjects que precisam de i18n:

- Line 8: "A new conversation [ID - #{@conversation.display_id}] has been created in #{inbox_name}"
- Line 18: "A new conversation [ID - #{@conversation.display_id}] has been assigned to you"
- Line 29: "You have been mentioned in conversation [ID - #{@conversation.display_id}]"
- Line 41: "New message in your assigned conversation [ID - #{@conversation.display_id}]"
- Line 53: "New message in your participating conversation [ID - #{@conversation.display_id}]"

## 2. Logos e Branding

### 2.1 Arquivos de Logo

Localização: `/public/brand-assets/`

- logo.svg
- logo_thumbnail.svg (ou .png)

### 2.2 Variáveis de Ambiente

```env
LOGO=<URL_DO_LOGO_STARCHATS>
LOGO_THUMBNAIL=<URL_DO_LOGO_THUMBNAIL>
BRAND_NAME=Starchats
INSTALLATION_NAME=Starchats
```

### 2.3 Configurações no Código

- `config/app.yml` - variáveis de branding
- Templates de email usam variáveis Liquid: `{{ brand_name }}`

## 3. Tema de Cores

### 3.1 CSS/SCSS Files

- `app/javascript/dashboard/assets/scss/` - variáveis de cores

### 3.2 Configurações de Widget

- Cor padrão do widget pode ser configurada por inbox
- Configuração global em `installation_configs`

## 4. Templates de Email

### Estrutura dos Templates

- `app/views/mailers/agent_notifications/conversation_notifications_mailer/`
  - conversation_creation.html.erb
  - conversation_assignment.html.erb
  - conversation_mention.html.erb
  - assigned_conversation_new_message.html.erb
  - participating_conversation_new_message.html.erb

### Layout Base

- `app/views/layouts/mailer.html.erb` ou similar

## 5. Próximos Passos

1. ✅ Adicionar tradução faltante de `conversation_creation`
2. ⏳ Internacionalizar subjects dos emails
3. ⏳ Verificar/criar templates HTML personalizados
4. ⏳ Configurar logos Starchats
5. ⏳ Ajustar tema de cores
