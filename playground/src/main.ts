import * as monaco from 'monaco-editor';
import EditorWorker from 'monaco-editor/esm/vs/editor/editor.worker?worker';

const RAW_GITHUB_BASE = 'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/ginga/examples/';
const RAW_PJ_BASE = `${RAW_GITHUB_BASE}primeiro-joao/`;

const pjMediaFiles: Record<string, string> = {
  'media/animGar.mp4': `${RAW_PJ_BASE}media/animGar.mp4`,
  'media/background.png': `${RAW_PJ_BASE}media/background.png`,
  'media/backgroundPassive.png': `${RAW_PJ_BASE}media/backgroundPassive.png`,
  'media/cartoes.png': `${RAW_PJ_BASE}media/cartoes.png`,
  'media/cartoon.mp4': `${RAW_PJ_BASE}media/cartoon.mp4`,
  'media/cartoon.png': `${RAW_PJ_BASE}media/cartoon.png`,
  'media/chorinho.png': `${RAW_PJ_BASE}media/chorinho.png`,
  'media/choro.mp4': `${RAW_PJ_BASE}media/choro.mp4`,
  'media/chut.png': `${RAW_PJ_BASE}media/chut.png`,
  'media/chuteira_mod.png': `${RAW_PJ_BASE}media/chuteira_mod.png`,
  'media/drible.mp4': `${RAW_PJ_BASE}media/drible.mp4`,
  'media/enComprou.htm': `${RAW_PJ_BASE}media/enComprou.htm`,
  'media/enForm.htm': `${RAW_PJ_BASE}media/enForm.htm`,
  'media/icon.png': `${RAW_PJ_BASE}media/icon.png`,
  'media/iconPassive.png': `${RAW_PJ_BASE}media/iconPassive.png`,
  'media/intOff.png': `${RAW_PJ_BASE}media/intOff.png`,
  'media/intOn.png': `${RAW_PJ_BASE}media/intOn.png`,
  'media/photo.png': `${RAW_PJ_BASE}media/photo.png`,
  'media/ptComprou.htm': `${RAW_PJ_BASE}media/ptComprou.htm`,
  'media/ptForm.htm': `${RAW_PJ_BASE}media/ptForm.htm`,
  'media/rock.mp4': `${RAW_PJ_BASE}media/rock.mp4`,
  'media/rock.png': `${RAW_PJ_BASE}media/rock.png`,
  'media/shoes.mp4': `${RAW_PJ_BASE}media/shoes.mp4`,
  'media/techno.mp4': `${RAW_PJ_BASE}media/techno.mp4`,
  'media/techno.png': `${RAW_PJ_BASE}media/techno.png`,
};

(self as any).MonacoEnvironment = {
  getWorker(_workerId: string, _label: string) {
    return new EditorWorker();
  }
};

export interface Example {
  mainFile: string;
  rawMainUrl?: string;
  category?: string;
  description?: string;
  files: Record<string, string>;
  fileUrls?: Record<string, string>;
}

export const examples: Record<string, Example> = {
  video: { mainFile: 'video.ncl', rawMainUrl: `${RAW_GITHUB_BASE}video.ncl`, category: 'media', description: 'Video media presentation example', files: {}, fileUrls: { 'video.ncl': `${RAW_GITHUB_BASE}video.ncl` } },
  lua_canvas: { mainFile: 'lua_canvas.ncl', rawMainUrl: `${RAW_GITHUB_BASE}lua_canvas.ncl`, category: 'lua', description: 'Lua canvas graphics example', files: {}, fileUrls: { 'lua_canvas.ncl': `${RAW_GITHUB_BASE}lua_canvas.ncl`, 'lua_canvas.lua': `${RAW_GITHUB_BASE}lua_canvas.lua` } },
  image: { mainFile: 'image.ncl', rawMainUrl: `${RAW_GITHUB_BASE}image.ncl`, category: 'media', description: 'Image presentation example', files: {}, fileUrls: { 'image.ncl': `${RAW_GITHUB_BASE}image.ncl` } },
  image_html: { mainFile: 'image.html', rawMainUrl: `${RAW_GITHUB_BASE}image.html`, category: 'html', description: 'HTML layout image example', files: {}, fileUrls: { 'image.html': `${RAW_GITHUB_BASE}image.html` } },
  current_service: { mainFile: 'current_service.html', rawMainUrl: `${RAW_GITHUB_BASE}current_service.html`, category: 'html', description: 'Current service HTML integration example', files: {}, fileUrls: { 'current_service.html': `${RAW_GITHUB_BASE}current_service.html` } },

  pj_00syncProp: { mainFile: '00syncProp.ncl', rawMainUrl: `${RAW_PJ_BASE}00syncProp.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Property sync example', files: {}, fileUrls: { '00syncProp.ncl': `${RAW_PJ_BASE}00syncProp.ncl` } },
  pj_01sync: { mainFile: '01sync.ncl', rawMainUrl: `${RAW_PJ_BASE}01sync.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Sync example', files: {}, fileUrls: { '01sync.ncl': `${RAW_PJ_BASE}01sync.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_02syncInt: { mainFile: '02syncInt.ncl', rawMainUrl: `${RAW_PJ_BASE}02syncInt.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Interactive sync example', files: {}, fileUrls: { '02syncInt.ncl': `${RAW_PJ_BASE}02syncInt.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_03context: { mainFile: '03context.ncl', rawMainUrl: `${RAW_PJ_BASE}03context.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Context mapping example', files: {}, fileUrls: { '03context.ncl': `${RAW_PJ_BASE}03context.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_04reuse: { mainFile: '04reuse.ncl', rawMainUrl: `${RAW_PJ_BASE}04reuse.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Media reuse example', files: {}, fileUrls: { '04reuse.ncl': `${RAW_PJ_BASE}04reuse.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_05return: { mainFile: '05return.ncl', rawMainUrl: `${RAW_PJ_BASE}05return.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Form return example', files: {}, fileUrls: { '05return.ncl': `${RAW_PJ_BASE}05return.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_06switch: { mainFile: '06switch.ncl', rawMainUrl: `${RAW_PJ_BASE}06switch.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Rule switch example', files: {}, fileUrls: { '06switch.ncl': `${RAW_PJ_BASE}06switch.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_07transition: { mainFile: '07transition.ncl', rawMainUrl: `${RAW_PJ_BASE}07transition.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Transition example', files: {}, fileUrls: { '07transition.ncl': `${RAW_PJ_BASE}07transition.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_08animation: { mainFile: '08animation.ncl', rawMainUrl: `${RAW_PJ_BASE}08animation.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Animation example', files: {}, fileUrls: { '08animation.ncl': `${RAW_PJ_BASE}08animation.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_09settings: { mainFile: '09settings.ncl', rawMainUrl: `${RAW_PJ_BASE}09settings.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Settings example', files: {}, fileUrls: { '09settings.ncl': `${RAW_PJ_BASE}09settings.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_10menu: { mainFile: '10menu.ncl', rawMainUrl: `${RAW_PJ_BASE}10menu.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Menu example', files: {}, fileUrls: { '10menu.ncl': `${RAW_PJ_BASE}10menu.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
  pj_11nclua: { mainFile: '11nclua.ncl', rawMainUrl: `${RAW_PJ_BASE}11nclua.ncl`, category: 'primeiro-joao', description: 'Primeiro João: NCLua example', files: {}, fileUrls: { '11nclua.ncl': `${RAW_PJ_BASE}11nclua.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl`, 'script/counter.lua': `${RAW_PJ_BASE}script/counter.lua` } },
  pj_12embNCL: { mainFile: '12embNCL.ncl', rawMainUrl: `${RAW_PJ_BASE}12embNCL.ncl`, category: 'primeiro-joao', description: 'Primeiro João: Embedded NCL example', files: {}, fileUrls: { '12embNCL.ncl': `${RAW_PJ_BASE}12embNCL.ncl`, 'advert.ncl': `${RAW_PJ_BASE}advert.ncl`, 'causalConnBase.ncl': `${RAW_PJ_BASE}causalConnBase.ncl` } },
};

async function loadExampleFiles(example: Example): Promise<void> {
  if (example.fileUrls) {
    for (const [fileName, url] of Object.entries(example.fileUrls)) {
      if (!(fileName in example.files)) {
        try {
          const res = await fetch(url);
          if (res.ok) {
            example.files[fileName] = await res.text();
          }
        } catch (_) {}
      }
    }
  }
}

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

async function initPlayground() {
  if (!editorContainer || !editorTabs || !runBtn || !selectEl || !iframe) return;

  const queryConfig = parseQueryConfig(window.location.search);
  const requested = queryConfig.requestedExample;

  if (queryConfig.isEmbed) {
    document.body.classList.add('embed-mode');
  }

  let defaultKey = resolveExampleKey(requested, examples);

  if (requested && !examples[defaultKey]) {
    const isUrl = requested.startsWith('http://') || requested.startsWith('https://');
    const fileName = requested.split('/').pop()?.split('?')[0] || 'app.ncl';
    defaultKey = 'requested_app';
    examples[defaultKey] = {
      mainFile: fileName,
      rawMainUrl: isUrl ? requested : undefined,
      files: {},
      fileUrls: isUrl ? { [fileName]: requested } : undefined
    };
  }

  let currentExample = examples[defaultKey];
  let currentFileName = currentExample.mainFile;
  let isRunning = false;

  if (requested) {
    const selectLabel = document.querySelector('label[for="example-select"]') as HTMLElement;
    if (selectLabel) selectLabel.style.display = 'none';
    if (selectEl) selectEl.style.display = 'none';
    if (uploadBtn) uploadBtn.style.display = 'none';
    selectEl.innerHTML = '';
    const opt = document.createElement('option');
    opt.value = defaultKey;
    opt.textContent = currentExample.mainFile;
    selectEl.appendChild(opt);
  }

  selectEl.value = defaultKey;

  await loadExampleFiles(currentExample);

  const editor = monaco.editor.create(editorContainer, {
    value: currentExample.files[currentFileName] || '',
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
          editor.setValue(currentExample.files[currentFileName] || '');
          monaco.editor.setModelLanguage(editor.getModel()!, fileName.endsWith('.lua') ? 'lua' : (fileName.endsWith('.html') ? 'html' : 'xml'));
          renderTabs();
        }
      });
      editorTabs.appendChild(tab);
    }
  };

  renderTabs();

  selectEl.addEventListener('change', async () => {
    const selected = selectEl.value;
    if (examples[selected]) {
      if (isRunning) {
        runBtn.click();
      }
      currentExample = examples[selected];
      await loadExampleFiles(currentExample);
      currentFileName = currentExample.mainFile;
      editor.setValue(currentExample.files[currentFileName] || '');
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
      iframe.src = 'gingaf-web/index.html';
      isRunning = true;
    }
  });

  window.addEventListener('message', (event) => {
    if (event.data === 'ginga_app_exited' && isRunning) {
      runBtn.click();
    }
  });
}

initPlayground();
