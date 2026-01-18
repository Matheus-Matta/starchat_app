# 📚 Documentação da API Starchats

## Acessando a Documentação

A documentação interativa da API está disponível em:

```
https://app.starchats.com.br/doc
```

## 🔐 Autenticação

Para usar a API, você precisa de um **Access Token**. Siga os passos:

1. Faça login na sua conta Starchats
2. Vá em **Configurações → Perfil**
3. Na seção **Access Token**, clique em "Regenerate Access Token"
4. Copie o token gerado

## 🚀 Usando a API

### Testando Direto na Documentação

1. Acesse https://app.starchats.com.br/doc
2. Clique no botão **"Authorize"** (cadeado no topo)
3. Cole seu Access Token
4. Clique em **"Authorize"**
5. Agora você pode clicar em **"Try it out"** em qualquer endpoint!

### Usando em Código

Exemplo com cURL:

```bash
curl -X GET "https://app.starchats.com.br/api/v1/accounts/1/contacts" \
  -H "api_access_token: SEU_TOKEN_AQUI"
```

Exemplo com JavaScript:

```javascript
fetch('https://app.starchats.com.br/api/v1/accounts/1/contacts', {
  headers: {
    api_access_token: 'SEU_TOKEN_AQUI',
  },
})
  .then(res => res.json())
  .then(data => console.log(data));
```

Exemplo com Python:

```python
import requests

headers = {
    'api_access_token': 'SEU_TOKEN_AQUI'
}

response = requests.get(
    'https://app.starchats.com.br/api/v1/accounts/1/contacts',
    headers=headers
)

print(response.json())
```

## 📊 Endpoints Principais

- **Contacts**: Gerenciar contatos
- **Conversations**: Gerenciar conversas
- **Messages**: Enviar e receber mensagens
- **Inboxes**: Gerenciar caixas de entrada
- **Webhooks**: Configurar notificações em tempo real

## ⚡ Rate Limiting

- **Limite**: 60 requisições por minuto por IP
- Se exceder, receberá um erro `429 Too Many Requests`

## 🔒 Segurança

- Sempre use HTTPS
- Nunca compartilhe seu Access Token
- Você pode regenerar seu token a qualquer momento
- Cada token só acessa dados da sua conta

## 💡 Suporte

Para dúvidas:

- Email: hello@starchats.com.br
- Site: https://www.starchats.com.br
