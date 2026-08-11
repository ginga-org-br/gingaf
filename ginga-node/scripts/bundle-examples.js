const fs = require('fs');
const path = require('path');

const examplesDir = path.resolve(__dirname, '..', '..', 'ginga', 'examples');

const examples = {
  video: {
    mainFile: 'video.ncl',
    category: 'media',
    description: 'Video media presentation example',
    files: {}
  },
  lua_canvas: {
    mainFile: 'lua_canvas.ncl',
    category: 'lua',
    description: 'Lua canvas graphics example',
    files: {}
  },
  image: {
    mainFile: 'image.ncl',
    category: 'media',
    description: 'Image presentation example',
    files: {}
  },
  image_html: {
    mainFile: 'image.html',
    category: 'html',
    description: 'HTML layout image example',
    files: {}
  },
  current_service: {
    mainFile: 'current_service.html',
    category: 'html',
    description: 'Current service HTML integration example',
    files: {}
  },
  pj_00syncProp: { mainFile: '00syncProp.ncl', category: 'primeiro-joao', description: 'Primeiro João: Property sync example', files: {} },
  pj_01sync: { mainFile: '01sync.ncl', category: 'primeiro-joao', description: 'Primeiro João: Sync example', files: {} },
  pj_02syncInt: { mainFile: '02syncInt.ncl', category: 'primeiro-joao', description: 'Primeiro João: Interactive sync example', files: {} },
  pj_03context: { mainFile: '03context.ncl', category: 'primeiro-joao', description: 'Primeiro João: Context mapping example', files: {} },
  pj_04reuse: { mainFile: '04reuse.ncl', category: 'primeiro-joao', description: 'Primeiro João: Media reuse example', files: {} },
  pj_05return: { mainFile: '05return.ncl', category: 'primeiro-joao', description: 'Primeiro João: Form return example', files: {} },
  pj_06switch: { mainFile: '06switch.ncl', category: 'primeiro-joao', description: 'Primeiro João: Rule switch example', files: {} },
  pj_07transition: { mainFile: '07transition.ncl', category: 'primeiro-joao', description: 'Primeiro João: Transition example', files: {} },
  pj_08animation: { mainFile: '08animation.ncl', category: 'primeiro-joao', description: 'Primeiro João: Animation example', files: {} },
  pj_09settings: { mainFile: '09settings.ncl', category: 'primeiro-joao', description: 'Primeiro João: Settings example', files: {} },
  pj_10menu: { mainFile: '10menu.ncl', category: 'primeiro-joao', description: 'Primeiro João: Menu example', files: {} },
  pj_11nclua: { mainFile: '11nclua.ncl', category: 'primeiro-joao', description: 'Primeiro João: NCLua example', files: {} },
  pj_12embNCL: { mainFile: '12embNCL.ncl', category: 'primeiro-joao', description: 'Primeiro João: Embedded NCL example', files: {} },
};

function readFileIfExist(relPath) {
  const fullPath = path.join(examplesDir, relPath);
  if (fs.existsSync(fullPath)) {
    return fs.readFileSync(fullPath, 'utf8');
  }
  return '';
}

examples.video.files['video.ncl'] = readFileIfExist('video.ncl');
examples.lua_canvas.files['lua_canvas.ncl'] = readFileIfExist('lua_canvas.ncl');
examples.lua_canvas.files['lua_canvas.lua'] = readFileIfExist('lua_canvas.lua');
examples.image.files['image.ncl'] = readFileIfExist('image.ncl');
examples.image_html.files['image.html'] = readFileIfExist('image.html');
examples.current_service.files['current_service.html'] = readFileIfExist('current_service.html');

const casualConnContent = readFileIfExist('primeiro-joao/causalConnBase.ncl');
const counterLuaContent = readFileIfExist('primeiro-joao/script/counter.lua');
const advertNclContent = readFileIfExist('primeiro-joao/advert.ncl');

for (const key of Object.keys(examples)) {
  if (key.startsWith('pj_')) {
    const mainFile = examples[key].mainFile;
    examples[key].files[mainFile] = readFileIfExist(path.join('primeiro-joao', mainFile));
    if (casualConnContent && key !== 'pj_00syncProp') {
      examples[key].files['causalConnBase.ncl'] = casualConnContent;
    }
    if (key === 'pj_11nclua' && counterLuaContent) {
      examples[key].files['script/counter.lua'] = counterLuaContent;
    }
    if (key === 'pj_12embNCL' && advertNclContent) {
      examples[key].files['advert.ncl'] = advertNclContent;
    }
  }
}

const outPath = path.resolve(__dirname, '..', 'src', 'examples.json');
fs.writeFileSync(outPath, JSON.stringify(examples, null, 2), 'utf8');
console.log('Bundled examples to src/examples.json cleanly!');
