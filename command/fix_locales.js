// scripts/fix_locales.js
// Script para corrigir arquivos de locale quebrados (Git conflicts + JSON duplicado)

const fs = require('fs');
const path = require('path');

const baseDir = path.join(
  process.cwd(),
  'app/javascript/dashboard/i18n/locale'
);
const backupDir = path.join(
  process.cwd(),
  'app/javascript/dashboard/i18n_backup_' + Date.now()
);

// Merge profundo de objetos
function deepMerge(target, source) {
  if (typeof target !== 'object' || target === null) {
    return source;
  }
  if (typeof source !== 'object' || source === null) {
    return source;
  }
  const result = { ...target };
  for (const [key, value] of Object.entries(source)) {
    if (Object.prototype.hasOwnProperty.call(result, key)) {
      result[key] = deepMerge(result[key], value);
    } else {
      result[key] = value;
    }
  }
  return result;
}

// Remove marcadores de conflito do Git
function stripGitConflictMarkers(content) {
  const lines = content.split(/\r?\n/);
  const cleaned = [];
  let inConflict = false;

  for (const line of lines) {
    if (line.startsWith('<<<<<<<')) {
      inConflict = true;
      continue;
    }
    if (line.startsWith('=======')) {
      continue;
    }
    if (line.startsWith('>>>>>>>')) {
      inConflict = false;
      continue;
    }
    cleaned.push(line);
  }

  return cleaned.join('\n');
}

// Tenta corrigir um JSON possivelmente com múltiplos objetos concatenados
function fixJson(content, filename) {
  let text = content.trim();

  // 1) tira marcadores de conflito
  if (text.includes('<<<<<<<') || text.includes('=======')) {
    text = stripGitConflictMarkers(text);
  }

  // 2) tenta parse direto
  try {
    const parsed = JSON.parse(text);
    return {
      fixed: JSON.stringify(parsed, null, 2) + '\n',
      changed: text !== content,
      reason: 'normalize/strip-conflict',
    };
  } catch {
    // tenta múltiplos objetos
  }

  // 3) múltiplos objetos colados
  const normalized = text.replace(/}\s*{/g, '}\n{');

  const parts = normalized
    .split(/\n(?=\s*{)/)
    .map(p => p.trim())
    .filter(p => p.length > 0);

  const objects = [];
  for (const [idx, part] of parts.entries()) {
    try {
      const obj = JSON.parse(part);
      objects.push(obj);
    } catch (e) {
      console.error(`  [${filename}] Chunk inválido (#${idx + 1}), ignorando.`);
    }
  }

  if (!objects.length) {
    return null;
  }

  const merged = objects.reduce((acc, obj) => deepMerge(acc, obj), {});
  return {
    fixed: JSON.stringify(merged, null, 2) + '\n',
    changed: true,
    reason: 'multi-root-merge',
  };
}

// lista todos os .json recursivamente a partir de baseDir
function collectJsonFiles(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectJsonFiles(fullPath)); // 👈 entra na subpasta
    } else if (entry.isFile() && entry.name.endsWith('.json')) {
      files.push(fullPath); // 👈 pega o .json
    }
  }

  return files;
}

// Execução principal
(function main() {
  if (!fs.existsSync(baseDir)) {
    console.error('Diretório de locale não encontrado:', baseDir);
    process.exit(1);
  }

  // backup
  console.log('📦 Criando backup dos locales em:', backupDir);
  fs.cpSync(
    path.join(process.cwd(), 'app/javascript/dashboard/i18n'),
    backupDir,
    { recursive: true }
  );

  const files = collectJsonFiles(baseDir);

  console.log('📁 Encontrados', files.length, 'arquivos de locale (.json).\n');

  for (const fullPath of files) {
    const file = path.relative(baseDir, fullPath);
    let raw = fs.readFileSync(fullPath, 'utf8');

    // já é JSON válido?
    try {
      JSON.parse(raw);
      console.log('✅ OK     ', file);
      continue;
    } catch {
      // tenta corrigir
    }

    const result = fixJson(raw, file);

    if (!result) {
      console.error(
        '❌ FALHA  ',
        file,
        '→ não foi possível corrigir automaticamente'
      );
      continue;
    }

    fs.writeFileSync(fullPath, result.fixed, 'utf8');

    if (result.reason === 'multi-root-merge') {
      console.log('🔧 FIX MR ', file, '→ múltiplos JSON mesclados');
    } else {
      console.log('🔧 FIX CF ', file, '→ conflitos removidos/normalizados');
    }
  }

  console.log('\n✅ Finalizado. Backup em:', backupDir);
})();
