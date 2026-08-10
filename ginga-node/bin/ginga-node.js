#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { startServer } = require('../dist/index.js');

const args = process.argv.slice(2);
let port = 3000;
let targetDir = process.cwd();

for (let i = 0; i < args.length; i++) {
  if (args[i] === '-p' || args[i] === '--port') {
    port = parseInt(args[i + 1], 10) || 3000;
    i++;
  } else if (!args[i].startsWith('-')) {
    targetDir = path.resolve(args[i]);
  }
}

console.log(`Starting ginga-node server in ${targetDir} on port ${port}...`);

startServer(port).then(() => {
  console.log(`ginga-node running at http://localhost:${port}/`);
}).catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
