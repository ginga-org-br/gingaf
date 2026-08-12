const fs = require('fs');
const path = require('path');

const examplesDir = path.resolve(__dirname, '..', '..', 'examples');
const RAW_GITHUB_BASE = 'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/';

function getReferencedFiles(relDirPath, fileName, visited = new Set()) {
  if (visited.has(fileName)) return [];
  visited.add(fileName);

  const fullPath = path.join(examplesDir, relDirPath, fileName);
  if (!fs.existsSync(fullPath) || fs.statSync(fullPath).isDirectory()) {
    return [];
  }

  const result = [fileName];
  const content = fs.readFileSync(fullPath, 'utf8');

  const regex = /(?:src|documentURI)=["']([^"']+)["']/g;
  let match;
  while ((match = regex.exec(content)) !== null) {
    const ref = match[1].trim();
    if (!ref.startsWith('http://') && !ref.startsWith('https://')) {
      result.push(ref);
      if (ref.endsWith('.ncl') || ref.endsWith('.xml') || ref.endsWith('.html') || ref.endsWith('.htm')) {
        const subRefs = getReferencedFiles(relDirPath, ref, visited);
        result.push(...subRefs);
      }
    }
  }

  return [...new Set(result)];
}

const examples = {
  video: {
    mainFile: 'video.ncl',
    category: 'media',
    description: 'Video media presentation example',
    relDir: '',
    files: {},
    fileUrls: {}
  },
  lua_canvas: {
    mainFile: 'lua_canvas.ncl',
    category: 'lua',
    description: 'Lua canvas graphics example',
    relDir: '',
    files: {},
    fileUrls: {}
  },
  image: {
    mainFile: 'image.ncl',
    category: 'media',
    description: 'Image presentation example',
    relDir: '',
    files: {},
    fileUrls: {}
  },
  image_html: {
    mainFile: 'image.html',
    category: 'html',
    description: 'HTML layout image example',
    relDir: '',
    files: {},
    fileUrls: {}
  },
  current_service: {
    mainFile: 'current_service.html',
    category: 'html',
    description: 'Current service HTML integration example',
    relDir: '',
    files: {},
    fileUrls: {}
  },
  pj_00syncProp: { mainFile: '00syncProp.ncl', category: 'primeiro-joao', description: 'Primeiro João: Property sync example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_01sync: { mainFile: '01sync.ncl', category: 'primeiro-joao', description: 'Primeiro João: Sync example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_02syncInt: { mainFile: '02syncInt.ncl', category: 'primeiro-joao', description: 'Primeiro João: Interactive sync example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_03context: { mainFile: '03context.ncl', category: 'primeiro-joao', description: 'Primeiro João: Context mapping example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_04reuse: { mainFile: '04reuse.ncl', category: 'primeiro-joao', description: 'Primeiro João: Media reuse example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_05return: { mainFile: '05return.ncl', category: 'primeiro-joao', description: 'Primeiro João: Form return example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_06switch: { mainFile: '06switch.ncl', category: 'primeiro-joao', description: 'Primeiro João: Rule switch example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_07transition: { mainFile: '07transition.ncl', category: 'primeiro-joao', description: 'Primeiro João: Transition example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_08animation: { mainFile: '08animation.ncl', category: 'primeiro-joao', description: 'Primeiro João: Animation example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_09settings: { mainFile: '09settings.ncl', category: 'primeiro-joao', description: 'Primeiro João: Settings example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_10menu: { mainFile: '10menu.ncl', category: 'primeiro-joao', description: 'Primeiro João: Menu example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_11nclua: { mainFile: '11nclua.ncl', category: 'primeiro-joao', description: 'Primeiro João: NCLua example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
  pj_12embNCL: { mainFile: '12embNCL.ncl', category: 'primeiro-joao', description: 'Primeiro João: Embedded NCL example', relDir: 'primeiro-joao', files: {}, fileUrls: {} },
};

for (const key of Object.keys(examples)) {
  const item = examples[key];
  const relDir = item.relDir;
  const mainFile = item.mainFile;
  const basePath = relDir ? `${relDir}/${mainFile}` : mainFile;
  const baseRawUrl = `${RAW_GITHUB_BASE}${basePath}`;

  item.rawMainUrl = baseRawUrl;

  const referencedFiles = getReferencedFiles(relDir, mainFile);
  for (const refFile of referencedFiles) {
    const rawRefUrl = relDir ? `${RAW_GITHUB_BASE}${relDir}/${refFile}` : `${RAW_GITHUB_BASE}${refFile}`;
    item.fileUrls[refFile] = rawRefUrl;
  }

  delete item.relDir;
}

const outPath = path.resolve(__dirname, '..', 'src', 'examples.json');
fs.writeFileSync(outPath, JSON.stringify(examples, null, 2), 'utf8');
