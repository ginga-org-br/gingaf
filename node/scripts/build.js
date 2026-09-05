const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');

const playgroundDir = path.resolve(__dirname, '..', 'playground');
const srcDir = path.resolve(__dirname, '..', 'src');

if (!fs.existsSync(playgroundDir)) {
  fs.mkdirSync(playgroundDir, { recursive: true });
}

(async () => {
  try {
    await esbuild.build({
      entryPoints: [path.join(srcDir, 'main.ts')],
      outfile: path.join(playgroundDir, 'bundle.js'),
      bundle: true,
      sourcemap: true,
      minify: true,
      format: 'esm',
      loader: {
        '.ttf': 'file',
        '.woff': 'file',
        '.woff2': 'file',
        '.eot': 'file',
        '.svg': 'file'
      }
    });

    await esbuild.build({
      entryPoints: [path.resolve(__dirname, '..', 'node_modules/monaco-editor/esm/vs/editor/editor.worker.js')],
      outfile: path.join(playgroundDir, 'editor.worker.js'),
      bundle: true,
      minify: true,
      format: 'iife'
    });

    const stylePath = path.resolve(__dirname, '..', 'style.css');
    let combinedCss = '';
    if (fs.existsSync(stylePath)) {
      combinedCss += fs.readFileSync(stylePath, 'utf8') + '\n';
    }
    const extractedBundleCss = path.join(playgroundDir, 'bundle.css');
    if (fs.existsSync(extractedBundleCss)) {
      combinedCss += fs.readFileSync(extractedBundleCss, 'utf8') + '\n';
      fs.rmSync(extractedBundleCss, { force: true });
    }
    fs.writeFileSync(path.join(playgroundDir, 'style.css'), combinedCss, 'utf8');

    const indexSrc = path.resolve(__dirname, '..', 'index.html');
    if (fs.existsSync(indexSrc)) {
      let content = fs.readFileSync(indexSrc, 'utf8');
      content = content.replace(/href="\/style\.css"/g, 'href="./style.css"');
      content = content.replace(/src="\/src\/main\.ts(\?mode=[^"]*)?"/g, 'src="./bundle.js"');
      content = content.replace(/src="\.\/main\.js"/g, 'src="./bundle.js"');
      fs.writeFileSync(path.join(playgroundDir, 'index.html'), content, 'utf8');
    }

    const examplesSrcDir = path.resolve(__dirname, '..', 'examples');
    const playgroundExamplesDir = path.join(playgroundDir, 'examples');
    if (!fs.existsSync(playgroundExamplesDir)) {
      fs.mkdirSync(playgroundExamplesDir, { recursive: true });
    }

    const exampleFiles = [
      'playground-app-example.html',
      'player-app-example.html'
    ];

    for (const file of exampleFiles) {
      const srcFile = path.join(examplesSrcDir, file);
      if (fs.existsSync(srcFile)) {
        let content = fs.readFileSync(srcFile, 'utf8');

        let examplesContent = content;
        examplesContent = examplesContent.replace(/href="\/style\.css"/g, 'href="../style.css"');
        examplesContent = examplesContent.replace(/src="\/src\/main\.ts(\?[^"]*)?"/g, (match, query) => `src="../bundle.js${query || ''}"`);
        examplesContent = examplesContent.replace(/src="\.\/main\.js(\?[^"]*)?"/g, (match, query) => `src="../bundle.js${query || ''}"`);
        fs.writeFileSync(path.join(playgroundExamplesDir, file), examplesContent, 'utf8');

        let rootContent = content;
        rootContent = rootContent.replace(/href="\/style\.css"/g, 'href="./style.css"');
        rootContent = rootContent.replace(/src="\/src\/main\.ts(\?[^"]*)?"/g, (match, query) => `src="./bundle.js${query || ''}"`);
        rootContent = rootContent.replace(/src="\.\/main\.js(\?[^"]*)?"/g, (match, query) => `src="./bundle.js${query || ''}"`);
        fs.writeFileSync(path.join(playgroundDir, file), rootContent, 'utf8');
      }
    }

    const examplesSrc = path.join(srcDir, 'examples.json');
    if (fs.existsSync(examplesSrc)) {
      fs.copyFileSync(examplesSrc, path.join(playgroundDir, 'examples.json'));
    }

    const publicGingafWeb = path.resolve(__dirname, '..', 'public', 'gingaf-web');
    const destGingafWeb = path.join(playgroundDir, 'gingaf-web');
    if (fs.existsSync(publicGingafWeb)) {
      if (fs.existsSync(destGingafWeb)) {
        fs.rmSync(destGingafWeb, { recursive: true, force: true });
      }
      fs.cpSync(publicGingafWeb, destGingafWeb, { recursive: true });
    }

  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
