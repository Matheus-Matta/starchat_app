// scripts/clean_locale_conflicts.js
// Limpa conflitos de merge em JSON de locale e mantém APENAS a segunda versão (theirs)

const fs = require('fs');
const path = require('path');

const baseDir = path.join(process.cwd(), 'app/javascript/dashboard/i18n/locale');
const backupDir = path.join(
  process.cwd(),
  'app/javascript/dashboard/i18n_backup_conflicts_' + Date.now()
);

// Busca todos os .json recursivamente
function collectJsonFiles(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectJsonFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.json')) {
      files.push(fullPath);
    }
  }

  return files;
}

// Remove conflitos mantendo apenas a segunda parte (entre ======= e >>>>>>>)
function keepSecondVersion(content) {
  const lines = content.split(/\r?\n/);
  const result = [];
  let state = 'normal'; // 'normal' | 'in_head' | 'in_second'

  for (const line of lines) {
    if (line.startsWith('<<<<<<< HEAD')) {
      state = 'in_head';
      continue;
    }
    if (line.startsWith('=======')) {
      if (state === 'in_head') {
        state = 'in_second';
        continue;
      }
    }
    if (line.startsWith('>>>>>>>')) {
      if (state === 'in_second' || state === 'in_head') {
        state = 'normal';
        continue;
      }
    }

    if (state === 'normal' || state === 'in_second') {
      result.push(line);
    }
    // se estiver em 'in_head', simplesmente ignora as linhas
  }

  return result.join('\n');
}

function main() {
  if (!fs.existsSync(baseDir)) {
    console.error('Diretório de locale não encontrado:', baseDir);
    process.exit(1);
  }

  // backup do diretório inteiro de i18n
  console.log('📦 Criando backup dos locales em:', backupDir);
  fs.cpSync(
    path.join(process.cwd(), 'app/javascript/dashboard/i18n'),
    backupDir,
    { recursive: true }
  );

  const files = collectJsonFiles(baseDir);
  console.log('📁 Encontrados', files.length, 'arquivos .json em locale.\n');

  let changedCount = 0;

  for (const fullPath of files) {
    const rel = path.relative(baseDir, fullPath);
    let raw = fs.readFileSync(fullPath, 'utf8');

    if (!raw.includes('<<<<<<< HEAD')) {
      console.log('✅ OK     ', rel);
      continue;
    }

    console.log('🔍 CONFL ', rel, '→ limpando HEAD e mantendo segunda versão');
    const cleaned = keepSecondVersion(raw);

    // Tenta validar como JSON, só pra garantir que não quebrou geral
    try {
      JSON.parse(cleaned);
      fs.writeFileSync(fullPath, cleaned, 'utf8');
      console.log('🔧 FIXED  ', rel);
      changedCount += 1;
    } catch (e) {
      console.error('❌ ERRO   ', rel, '→ JSON inválido após limpeza:', e.message);
      // Se quiser, pode escrever mesmo assim para inspeção manual:
      // fs.writeFileSync(fullPath + '.broken', cleaned, 'utf8');
    }
  }

  console.log('\n✅ Finalizado. Arquivos alterados:', changedCount);
  console.log('🛟 Backup em:', backupDir);
}

main();
