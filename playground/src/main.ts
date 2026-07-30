import * as monaco from 'monaco-editor';
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';

// @ts-ignore
import videoNcl from '../../ginga/examples/video.ncl?raw';
// @ts-ignore
import luaCanvasNcl from '../../ginga/examples/lua_canvas.ncl?raw';
// @ts-ignore
import luaCanvasLua from '../../ginga/examples/lua_canvas.lua?raw';
// @ts-ignore
import imageNcl from '../../ginga/examples/image.ncl?raw';
// @ts-ignore
import imageHtml from '../../ginga/examples/image.html?raw';
// @ts-ignore
import currentServiceHtml from '../../ginga/examples/current_service.html?raw';

// @ts-ignore
import pjCausalConnBase from '../../ginga/examples/primeiro-joao/causalConnBase.ncl?raw';
// @ts-ignore
import pjAdvert from '../../ginga/examples/primeiro-joao/advert.ncl?raw';
// @ts-ignore
import pjCounterLua from '../../ginga/examples/primeiro-joao/script/counter.lua?raw';

// @ts-ignore
import pj00syncProp from '../../ginga/examples/primeiro-joao/00syncProp.ncl?raw';
// @ts-ignore
import pj01sync from '../../ginga/examples/primeiro-joao/01sync.ncl?raw';
// @ts-ignore
import pj02syncInt from '../../ginga/examples/primeiro-joao/02syncInt.ncl?raw';
// @ts-ignore
import pj03context from '../../ginga/examples/primeiro-joao/03context.ncl?raw';
// @ts-ignore
import pj04reuse from '../../ginga/examples/primeiro-joao/04reuse.ncl?raw';
// @ts-ignore
import pj05return from '../../ginga/examples/primeiro-joao/05return.ncl?raw';
// @ts-ignore
import pj06switch from '../../ginga/examples/primeiro-joao/06switch.ncl?raw';
// @ts-ignore
import pj07transition from '../../ginga/examples/primeiro-joao/07transition.ncl?raw';
// @ts-ignore
import pj08animation from '../../ginga/examples/primeiro-joao/08animation.ncl?raw';
// @ts-ignore
import pj09settings from '../../ginga/examples/primeiro-joao/09settings.ncl?raw';
// @ts-ignore
import pj10menu from '../../ginga/examples/primeiro-joao/10menu.ncl?raw';
// @ts-ignore
import pj11nclua from '../../ginga/examples/primeiro-joao/11nclua.ncl?raw';
// @ts-ignore
import pj12embNCL from '../../ginga/examples/primeiro-joao/12embNCL.ncl?raw';

// @ts-ignore
import pjMediaAnimGar from '../../ginga/examples/primeiro-joao/media/animGar.mp4';
// @ts-ignore
import pjMediaBackground from '../../ginga/examples/primeiro-joao/media/background.png';
// @ts-ignore
import pjMediaBackgroundPassive from '../../ginga/examples/primeiro-joao/media/backgroundPassive.png';
// @ts-ignore
import pjMediaCartoes from '../../ginga/examples/primeiro-joao/media/cartoes.png';
// @ts-ignore
import pjMediaCartoonMp4 from '../../ginga/examples/primeiro-joao/media/cartoon.mp4';
// @ts-ignore
import pjMediaCartoonPng from '../../ginga/examples/primeiro-joao/media/cartoon.png';
// @ts-ignore
import pjMediaChorinhoPng from '../../ginga/examples/primeiro-joao/media/chorinho.png';
// @ts-ignore
import pjMediaChoroMp4 from '../../ginga/examples/primeiro-joao/media/choro.mp4';
// @ts-ignore
import pjMediaChutPng from '../../ginga/examples/primeiro-joao/media/chut.png';
// @ts-ignore
import pjMediaChuteiraModPng from '../../ginga/examples/primeiro-joao/media/chuteira_mod.png';
// @ts-ignore
import pjMediaDribleMp4 from '../../ginga/examples/primeiro-joao/media/drible.mp4';
// @ts-ignore
import pjMediaEnComprouHtm from '../../ginga/examples/primeiro-joao/media/enComprou.htm?raw';
// @ts-ignore
import pjMediaEnFormHtm from '../../ginga/examples/primeiro-joao/media/enForm.htm?raw';
// @ts-ignore
import pjMediaIconPng from '../../ginga/examples/primeiro-joao/media/icon.png';
// @ts-ignore
import pjMediaIconPassivePng from '../../ginga/examples/primeiro-joao/media/iconPassive.png';
// @ts-ignore
import pjMediaIntOffPng from '../../ginga/examples/primeiro-joao/media/intOff.png';
// @ts-ignore
import pjMediaIntOnPng from '../../ginga/examples/primeiro-joao/media/intOn.png';
// @ts-ignore
import pjMediaPhotoPng from '../../ginga/examples/primeiro-joao/media/photo.png';
// @ts-ignore
import pjMediaPtComprouHtm from '../../ginga/examples/primeiro-joao/media/ptComprou.htm?raw';
// @ts-ignore
import pjMediaPtFormHtm from '../../ginga/examples/primeiro-joao/media/ptForm.htm?raw';
// @ts-ignore
import pjMediaRockMp4 from '../../ginga/examples/primeiro-joao/media/rock.mp4';
// @ts-ignore
import pjMediaRockPng from '../../ginga/examples/primeiro-joao/media/rock.png';
// @ts-ignore
import pjMediaShoesMp4 from '../../ginga/examples/primeiro-joao/media/shoes.mp4';
// @ts-ignore
import pjMediaTechnoMp4 from '../../ginga/examples/primeiro-joao/media/techno.mp4';
// @ts-ignore
import pjMediaTechnoPng from '../../ginga/examples/primeiro-joao/media/techno.png';

const pjMediaFiles: Record<string, string> = {
  'media/animGar.mp4': pjMediaAnimGar,
  'media/background.png': pjMediaBackground,
  'media/backgroundPassive.png': pjMediaBackgroundPassive,
  'media/cartoes.png': pjMediaCartoes,
  'media/cartoon.mp4': pjMediaCartoonMp4,
  'media/cartoon.png': pjMediaCartoonPng,
  'media/chorinho.png': pjMediaChorinhoPng,
  'media/choro.mp4': pjMediaChoroMp4,
  'media/chut.png': pjMediaChutPng,
  'media/chuteira_mod.png': pjMediaChuteiraModPng,
  'media/drible.mp4': pjMediaDribleMp4,
  'media/enComprou.htm': pjMediaEnComprouHtm,
  'media/enForm.htm': pjMediaEnFormHtm,
  'media/icon.png': pjMediaIconPng,
  'media/iconPassive.png': pjMediaIconPassivePng,
  'media/intOff.png': pjMediaIntOffPng,
  'media/intOn.png': pjMediaIntOnPng,
  'media/photo.png': pjMediaPhotoPng,
  'media/ptComprou.htm': pjMediaPtComprouHtm,
  'media/ptForm.htm': pjMediaPtFormHtm,
  'media/rock.mp4': pjMediaRockMp4,
  'media/rock.png': pjMediaRockPng,
  'media/shoes.mp4': pjMediaShoesMp4,
  'media/techno.mp4': pjMediaTechnoMp4,
  'media/techno.png': pjMediaTechnoPng,
};

self.MonacoEnvironment = {
  getWorker(_workerId: string, _label: string) {
    return new EditorWorker();
  }
};

export interface Example {
  mainFile: string;
  category?: string;
  description?: string;
  files: Record<string, string>;
}

export const examples: Record<string, Example> = {
  video: { mainFile: 'video.ncl', category: 'media', description: 'Video media presentation example', files: { 'video.ncl': videoNcl } },
  lua_canvas: { mainFile: 'lua_canvas.ncl', category: 'lua', description: 'Lua canvas graphics example', files: { 'lua_canvas.ncl': luaCanvasNcl, 'lua_canvas.lua': luaCanvasLua } },
  image: { mainFile: 'image.ncl', category: 'media', description: 'Image presentation example', files: { 'image.ncl': imageNcl } },
  image_html: { mainFile: 'image.html', category: 'html', description: 'HTML layout image example', files: { 'image.html': imageHtml } },
  current_service: { mainFile: 'current_service.html', category: 'html', description: 'Current service HTML integration example', files: { 'current_service.html': currentServiceHtml } },

  pj_00syncProp: { mainFile: '00syncProp.ncl', category: 'primeiro-joao', description: 'Primeiro João: Property sync example', files: { '00syncProp.ncl': pj00syncProp } },
  pj_01sync: { mainFile: '01sync.ncl', category: 'primeiro-joao', description: 'Primeiro João: Sync example', files: { '01sync.ncl': pj01sync, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_02syncInt: { mainFile: '02syncInt.ncl', category: 'primeiro-joao', description: 'Primeiro João: Interactive sync example', files: { '02syncInt.ncl': pj02syncInt, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_03context: { mainFile: '03context.ncl', category: 'primeiro-joao', description: 'Primeiro João: Context mapping example', files: { '03context.ncl': pj03context, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_04reuse: { mainFile: '04reuse.ncl', category: 'primeiro-joao', description: 'Primeiro João: Media reuse example', files: { '04reuse.ncl': pj04reuse, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_05return: { mainFile: '05return.ncl', category: 'primeiro-joao', description: 'Primeiro João: Form return example', files: { '05return.ncl': pj05return, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_06switch: { mainFile: '06switch.ncl', category: 'primeiro-joao', description: 'Primeiro João: Rule switch example', files: { '06switch.ncl': pj06switch, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_07transition: { mainFile: '07transition.ncl', category: 'primeiro-joao', description: 'Primeiro João: Transition example', files: { '07transition.ncl': pj07transition, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_08animation: { mainFile: '08animation.ncl', category: 'primeiro-joao', description: 'Primeiro João: Animation example', files: { '08animation.ncl': pj08animation, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_09settings: { mainFile: '09settings.ncl', category: 'primeiro-joao', description: 'Primeiro João: Settings example', files: { '09settings.ncl': pj09settings, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_10menu: { mainFile: '10menu.ncl', category: 'primeiro-joao', description: 'Primeiro João: Menu example', files: { '10menu.ncl': pj10menu, 'causalConnBase.ncl': pjCausalConnBase } },
  pj_11nclua: { mainFile: '11nclua.ncl', category: 'primeiro-joao', description: 'Primeiro João: NCLua example', files: { '11nclua.ncl': pj11nclua, 'causalConnBase.ncl': pjCausalConnBase, 'script/counter.lua': pjCounterLua } },
  pj_12embNCL: { mainFile: '12embNCL.ncl', category: 'primeiro-joao', description: 'Primeiro João: Embedded NCL example', files: { '12embNCL.ncl': pj12embNCL, 'advert.ncl': pjAdvert, 'causalConnBase.ncl': pjCausalConnBase } },
};

export function resolveExampleKey(requested: string | null, available: Record<string, Example> = examples): string {
  if (!requested) return 'video';
  const key = Object.keys(available).find(k =>
    k === requested ||
    available[k].mainFile === requested ||
    available[k].mainFile === requested + '.ncl'
  );
  return key || 'video';
}

export function parseQueryConfig(searchString: string): {
  requestedExample: string | null;
  isEmbed: boolean;
  category: string | null;
  theme: string | null;
  playbackRate: number;
} {
  const params = new URLSearchParams(searchString);
  const rateStr = params.get('rate') || params.get('playbackRate');
  const parsedRate = rateStr ? parseFloat(rateStr) : 1.0;
  return {
    requestedExample: params.get('example') || params.get('app'),
    isEmbed: params.get('embed') === 'true',
    category: params.get('category'),
    theme: params.get('theme'),
    playbackRate: isNaN(parsedRate) || parsedRate <= 0 ? 1.0 : parsedRate,
  };
}

const editorContainer = document.getElementById('editor-container');
const editorTabs = document.getElementById('editor-tabs');
const runBtn = document.getElementById('run-btn');
const uploadBtn = document.getElementById('upload-btn');
const fileInput = document.getElementById('file-input') as HTMLInputElement;
const selectEl = document.getElementById('example-select') as HTMLSelectElement;
const iframe = document.getElementById('preview-frame') as HTMLIFrameElement;

const isEditableFile = (fileName: string) => {
  return fileName.endsWith('.ncl') ||
    fileName.endsWith('.xml') ||
    fileName.endsWith('.lua') ||
    fileName.endsWith('.html') ||
    fileName.endsWith('.htm') ||
    fileName.endsWith('.js') ||
    fileName.endsWith('.css') ||
    fileName.endsWith('.txt');
};

if (editorContainer && editorTabs && runBtn && selectEl && iframe) {
  const queryConfig = parseQueryConfig(window.location.search);

  if (queryConfig.isEmbed) {
    document.body.classList.add('embed-mode');
  }

  const defaultKey = resolveExampleKey(queryConfig.requestedExample, examples);

  let currentExample = examples[defaultKey];
  let currentFileName = currentExample.mainFile;
  let isRunning = false;
  selectEl.value = defaultKey;

  const editor = monaco.editor.create(editorContainer, {
    value: currentExample.files[currentFileName],
    language: 'xml',
    theme: 'vs-dark',
    minimap: { enabled: false },
    automaticLayout: true,
    wordWrap: 'on',
  });

  const renderTabs = () => {
    editorTabs.innerHTML = '';
    for (const fileName of Object.keys(currentExample.files)) {
      if (!isEditableFile(fileName)) continue;
      const tab = document.createElement('div');
      tab.className = 'tab' + (fileName === currentFileName ? ' active' : '');
      tab.textContent = fileName;
      tab.addEventListener('click', () => {
        if (!isRunning) {
          currentExample.files[currentFileName] = editor.getValue();
          currentFileName = fileName;
          editor.setValue(currentExample.files[currentFileName]);
          monaco.editor.setModelLanguage(editor.getModel()!, fileName.endsWith('.lua') ? 'lua' : (fileName.endsWith('.html') ? 'html' : 'xml'));
          renderTabs();
        }
      });
      editorTabs.appendChild(tab);
    }
  };

  renderTabs();

  selectEl.addEventListener('change', () => {
    const selected = selectEl.value;
    if (examples[selected]) {
      if (isRunning) {
        runBtn.click();
      }
      currentExample = examples[selected];
      currentFileName = currentExample.mainFile;
      editor.setValue(currentExample.files[currentFileName]);
      monaco.editor.setModelLanguage(editor.getModel()!, currentFileName.endsWith('.lua') ? 'lua' : (currentFileName.endsWith('.html') ? 'html' : 'xml'));
      renderTabs();
    }
  });

  if (uploadBtn && fileInput) {
    uploadBtn.addEventListener('click', () => {
      if (!isRunning) {
        fileInput.click();
      }
    });

    fileInput.addEventListener('change', async () => {
      const files = fileInput.files;
      if (!files || files.length === 0) return;

      if (!examples['uploaded']) {
        examples['uploaded'] = {
          mainFile: '',
          files: {}
        };
      }

      let mainFileCandidate = '';
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        if (isEditableFile(file.name)) {
          const text = await file.text();
          examples['uploaded'].files[file.name] = text;
        } else {
          const url = URL.createObjectURL(file);
          examples['uploaded'].files[file.name] = url;
        }

        if (file.name.endsWith('.ncl')) {
          mainFileCandidate = file.name;
        } else if (file.name.endsWith('.html') && !mainFileCandidate.endsWith('.ncl')) {
          mainFileCandidate = file.name;
        } else if (!mainFileCandidate && isEditableFile(file.name)) {
          mainFileCandidate = file.name;
        }
      }

      if (mainFileCandidate) {
        examples['uploaded'].mainFile = mainFileCandidate;
      }

      let uploadedOption = Array.from(selectEl.options).find(opt => opt.value === 'uploaded');
      if (!uploadedOption) {
        uploadedOption = document.createElement('option');
        uploadedOption.value = 'uploaded';
        uploadedOption.textContent = 'Uploaded Files';
        selectEl.appendChild(uploadedOption);
      }

      selectEl.value = 'uploaded';
      selectEl.dispatchEvent(new Event('change'));
      fileInput.value = '';
    });
  }

  iframe.src = 'about:blank';

  runBtn.addEventListener('click', async () => {
    if (isRunning) {
      editor.updateOptions({ readOnly: false });
      document.getElementById('editor-overlay')?.classList.add('hidden');
      runBtn.textContent = 'Run';
      iframe.src = 'about:blank';
      isRunning = false;
    } else {
      currentExample.files[currentFileName] = editor.getValue();

      const allFiles = currentExample.category === 'primeiro-joao'
        ? { ...pjMediaFiles, ...currentExample.files }
        : currentExample.files;

      sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
      sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', currentExample.mainFile);

      editor.updateOptions({ readOnly: true });
      document.getElementById('editor-overlay')?.classList.remove('hidden');
      runBtn.textContent = 'Stop';
      iframe.src = 'player/index.html';
      isRunning = true;
    }
  });

  window.addEventListener('message', (event) => {
    if (event.data === 'ginga_app_exited' && isRunning) {
      runBtn.click();
    }
  });
}
