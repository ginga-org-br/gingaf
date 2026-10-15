const fs = require('fs');
const path = require('path');
const esbuild = require('esbuild');

const playgroundDir = path.resolve(__dirname, '..', 'playground');
const srcDir = path.resolve(__dirname, '..', 'src');
const flutterWebSrc = path.resolve(__dirname, '..', '..', 'build', 'web');
const flutterWebDest = path.join(playgroundDir, 'gingaf-web');

if (!fs.existsSync(playgroundDir)) {
  fs.mkdirSync(playgroundDir, { recursive: true });
}

(async () => {
  try {
    if (!fs.existsSync(flutterWebSrc)) {
      if (!fs.existsSync(flutterWebDest)) {
        console.error(`Error: Flutter web build not found at ${flutterWebSrc}. Run "flutter build web --release" or "make release-web" first.`);
        process.exit(1);
      }
    } else {
      if (fs.existsSync(flutterWebDest)) {
        fs.rmSync(flutterWebDest, { recursive: true, force: true });
      }
      fs.mkdirSync(flutterWebDest, { recursive: true });
      fs.cpSync(flutterWebSrc, flutterWebDest, { recursive: true });

      const idx = path.join(flutterWebDest, 'index.html');
      if (fs.existsSync(idx)) {
        let content = fs.readFileSync(idx, 'utf8');
        const dynamicBaseScript = `<script>let p=window.location.pathname;if(!p.endsWith('/')){p=(p.endsWith('.html')||p.endsWith('.htm'))?p.substring(0,p.lastIndexOf('/')+1):p+'/';}const b=document.createElement('base');b.href=p;document.head.prepend(b);</script>`;
        content = content.replace(/<base href="[^"]*">/, dynamicBaseScript);
        fs.writeFileSync(idx, content, 'utf8');
      }
    }

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

  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
