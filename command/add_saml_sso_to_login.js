// scripts/add_saml_sso_to_login.js
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(
  process.cwd(),
  'app',
  'javascript',
  'dashboard',
  'i18n',
  'locale'
);

// Tradução base em inglês (fallback)
const samlEn = {
  LABEL: 'Login via SSO',
  TITLE: 'Start Single Sign-on (SSO)',
  SUBTITLE: 'Enter your work email to access your organization',
  BACK_TO_LOGIN: 'Login with password',
  WORK_EMAIL: {
    LABEL: 'Work email',
    PLACEHOLDER: 'Enter your work email',
  },
  SUBMIT: 'Continue with SSO',
  API: {
    ERROR_MESSAGE:
      'SSO authentication failed. Please check your credentials and try again.',
  },
};

// Tradução em pt_BR (usando o texto que você passou + ajuste do erro)
const samlPtBr = {
  LABEL: 'Login via SSO',
  TITLE: 'Iniciar Single Sign-on (SSO)',
  SUBTITLE: 'Digite seu e-mail de trabalho para acessar sua organização',
  BACK_TO_LOGIN: 'Login com senha',
  WORK_EMAIL: {
    LABEL: 'E-mail de trabalho',
    PLACEHOLDER: 'Digite seu e-mail de trabalho',
  },
  SUBMIT: 'Continuar com SSO',
  API: {
    ERROR_MESSAGE:
      'Falha na autenticação SSO. Verifique suas credenciais e tente novamente.',
  },
};

// Aqui você pode adicionar outras traduções se quiser
const samlByLocale = {
  en: samlEn,
  en_US: samlEn,
  pt_BR: samlPtBr,
  // es: { ... },
  // fr: { ... },
};

function getSamlBlockForLocale(locale) {
  // Se tiver tradução específica, usa
  if (samlByLocale[locale]) {
    return samlByLocale[locale];
  }

  // Fallback: inglês
  return samlEn;
}

function addSamlToLoginForLocale(locale) {
  const loginPath = path.join(LOCALES_DIR, locale, 'login.json');

  if (!fs.existsSync(loginPath)) {
    console.warn(`[SKIP] Não existe login.json para locale: ${locale}`);
    return;
  }

  let content;
  try {
    content = fs.readFileSync(loginPath, 'utf8');
  } catch (err) {
    console.error(`[ERRO] Falha ao ler ${loginPath}:`, err.message);
    return;
  }

  let json;
  try {
    json = JSON.parse(content);
  } catch (err) {
    console.error(`[ERRO] JSON inválido em ${loginPath}:`, err.message);
    return;
  }

  if (!json.LOGIN) {
    json.LOGIN = {};
  }

  if (json.LOGIN.SAML) {
    console.log(`[OK] LOGIN.SAML já existe em ${loginPath}, pulando...`);
    return;
  }

  const samlBlock = getSamlBlockForLocale(locale);
  json.LOGIN.SAML = samlBlock;

  try {
    const formatted = JSON.stringify(json, null, 2) + '\n';
    fs.writeFileSync(loginPath, formatted, 'utf8');
    console.log(`[ADD] LOGIN.SAML adicionado em ${loginPath}`);
  } catch (err) {
    console.error(`[ERRO] Falha ao escrever em ${loginPath}:`, err.message);
  }
}

function main() {
  if (!fs.existsSync(LOCALES_DIR)) {
    console.error('Diretório de locales não encontrado:', LOCALES_DIR);
    process.exit(1);
  }

  const entries = fs.readdirSync(LOCALES_DIR, { withFileTypes: true });
  const localeDirs = entries.filter(e => e.isDirectory()).map(e => e.name);

  console.log('Locales encontrados:', localeDirs.join(', '));

  localeDirs.forEach(locale => {
    addSamlToLoginForLocale(locale);
  });

  console.log('Finalizado.');
}

main();
