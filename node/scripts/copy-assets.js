const fs = require('fs');
const path = require('path');

const src = path.resolve(__dirname, '..', '..', 'build', 'web');
const dest = path.resolve(__dirname, '..', 'public', 'gingaf-web');

if (fs.existsSync(dest)) {
  fs.rmSync(dest, { recursive: true, force: true });
}
fs.mkdirSync(dest, { recursive: true });
fs.cpSync(src, dest, { recursive: true });

const idx = path.join(dest, 'index.html');
if (fs.existsSync(idx)) {
  let content = fs.readFileSync(idx, 'utf8');
  const dynamicBaseScript = `<script>let p=window.location.pathname;if(!p.endsWith('/')){p=(p.endsWith('.html')||p.endsWith('.htm'))?p.substring(0,p.lastIndexOf('/')+1):p+'/';}const b=document.createElement('base');b.href=p;document.head.prepend(b);</script>`;
  content = content.replace(/<base href="[^"]*">/, dynamicBaseScript);
  fs.writeFileSync(idx, content, 'utf8');
}

const playgroundDest = path.resolve(__dirname, '..', 'playground', 'gingaf-web');
if (fs.existsSync(path.dirname(playgroundDest))) {
  if (fs.existsSync(playgroundDest)) {
    fs.rmSync(playgroundDest, { recursive: true, force: true });
  }
  fs.mkdirSync(playgroundDest, { recursive: true });
  fs.cpSync(dest, playgroundDest, { recursive: true });
}
