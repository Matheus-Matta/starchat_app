#!/usr/bin/env node

const fs = require('fs').promises;
const path = require('path');

// Diretório base: passado como argumento ou o diretório atual
const ROOT_DIR = process.argv[2] || process.cwd();

// Se quiser realmente tentar em TODOS os arquivos, mude para true
const PROCESS_ALL_FILES = false;

// Extensões de texto mais comuns (quando PROCESS_ALL_FILES = false)
const TEXT_EXTS = new Set([
  '.js',
  '.ts',
  '.jsx',
  '.tsx',
  '.rb',
  '.jbuilder',
  '.json',
  '.html',
  '.htm',
  '.css',
  '.scss',
  '.sass',
  '.less',
  '.md',
  '.txt',
  '.yml',
  '.yaml',
  '.php',
  '.liquid',
  '.vue',
]);

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    // pula algumas pastas chatas
    if (entry.isDirectory()) {
      if (['node_modules', '.git', '.idea', '.vscode'].includes(entry.name))
        continue;
      await walk(fullPath);
    } else if (shouldProcess(fullPath)) {
      await replaceInFile(fullPath);
    }
  }
}

function shouldProcess(filePath) {
  if (PROCESS_ALL_FILES) return true;
  const ext = path.extname(filePath).toLowerCase();
  return TEXT_EXTS.has(ext);
}

async function replaceInFile(filePath) {
  let content;
  try {
    content = await fs.readFile(filePath, 'utf8');
  } catch (err) {
    console.warn('Não consegui ler (pulei):', filePath);
    return;
  }

  const replaced = content
    .replace(/COSMOS/g, 'COSMOS')
    .replace(/Cosmos/g, 'Cosmos')
    .replace(/cosmos/g, 'cosmos');

  if (replaced !== content) {
    await fs.writeFile(filePath, replaced, 'utf8');
    console.log('Atualizado:', filePath);
  }
}

walk(ROOT_DIR)
  .then(() => console.log('Concluído.'))
  .catch(err => console.error('Erro geral:', err));
