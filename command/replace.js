#!/usr/bin/env node

const fs = require('fs').promises;
const path = require('path');

const ROOT_DIR = process.argv[2] || process.cwd();
const PROCESS_ALL_FILES = false;

const TEXT_EXTS = new Set([
  '.js',
  '.ts',
  '.jsx',
  '.tsx',
  '.rb',
  '.json',
  '.html',
  '.eml',
  '.htm',
  '.css',
  '.scss',
  '.sass',
  '.less',
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

    if (entry.isDirectory()) {
      if (['node_modules', '.git', '.idea', '.vscode'].includes(entry.name))
        continue;
      await walk(fullPath);
    } else if (entry.isFile() && shouldProcess(fullPath)) {
      console.log('Verificando:', fullPath);
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
    console.warn(
      'Não consegui ler (pulei):',
      filePath,
      '-',
      err.code || err.message
    );
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
