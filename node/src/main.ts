import * as monaco from 'monaco-editor';
import bundledExamples from './examples.json';

export interface Example {
  mainFile: string;
  rawMainUrl?: string;
  category?: string;
  description?: string;
  files: Record<string, string>;
  fileUrls?: Record<string, string>;
}

const RAW_GITHUB_BASE = 'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/';
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

const examples: Record<string, Example> = bundledExamples as Record<string, Example>;

(self as any).MonacoEnvironment = {
  getWorkerUrl(_workerId: string, _label: string) {
    const prefix = typeof window !== 'undefined' && window.location.pathname.includes('/examples/') ? '../' : './';
    return prefix + 'editor.worker.js';
  }
};

export function isEditableFile(fileName: string): boolean {
  return fileName.endsWith('.ncl') ||
    fileName.endsWith('.xml') ||
    fileName.endsWith('.lua') ||
    fileName.endsWith('.html') ||
    fileName.endsWith('.htm') ||
    fileName.endsWith('.js') ||
    fileName.endsWith('.css') ||
    fileName.endsWith('.txt');
}

export async function loadExampleFiles(example: Example): Promise<void> {
  if (example.fileUrls) {
    for (const [fileName, url] of Object.entries(example.fileUrls)) {
      if (isEditableFile(fileName) && (!example.files[fileName] || example.files[fileName] === '')) {
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

export function getAllFiles(example: Example): Record<string, string> {
  return example.category === 'primeiro-joao'
    ? { ...pjMediaFiles, ...example.files }
    : { ...example.files };
}

export function getEffectiveSearch(): string {
  if (typeof window === 'undefined') return '';
  if (window.location.search) return window.location.search;
  try {
    const scriptEl = (document.currentScript || document.querySelector('script[src*="bundle.js"], script[src*="main.ts"]')) as HTMLScriptElement;
    if (scriptEl && scriptEl.src && scriptEl.src.includes('?')) {
      return scriptEl.src.slice(scriptEl.src.indexOf('?'));
    }
  } catch (_) {}
  return '';
}

export function resolvePlayerBaseUrl(playerParam: string | null): string {
  const isInExamples = typeof window !== 'undefined' && window.location.pathname.includes('/examples/');
  let playerBaseUrl = isInExamples ? '../gingaf-web/index.html' : 'gingaf-web/index.html';
  const isHostedEnv = typeof process !== 'undefined' && (process as any).env ? (process as any).env.VITE_USE_HOSTED_PLAYER === 'true' : false;
  const useHosted = playerParam === 'hosted' || (playerParam !== 'local' && isHostedEnv);
  if (useHosted) {
    playerBaseUrl = 'https://ginga-org-br.github.io/gingaf/playground/gingaf-web/index.html';
  }
  return playerBaseUrl;
}

export async function resolveTargetExample(appParam: string | null): Promise<Example> {
  if (!appParam) {
    return examples['video'] || Object.values(examples)[0];
  }

  const cleanParam = appParam.split('?')[0];
  const extractedFileName = cleanParam.split('/').pop() || cleanParam;
  const extractedKey = extractedFileName.replace(/\.[^/.]+$/, '');

  if (examples[appParam]) return examples[appParam];
  if (examples[extractedFileName]) return examples[extractedFileName];
  if (examples[extractedKey]) return examples[extractedKey];

  for (const key of Object.keys(examples)) {
    if (examples[key].mainFile === extractedFileName || examples[key].mainFile === appParam) {
      return examples[key];
    }
  }

  if (appParam.startsWith('http://') || appParam.startsWith('https://')) {
    try {
      const res = await fetch(appParam);
      if (res.ok) {
        const text = await res.text();
        const fileName = extractedFileName || 'app.ncl';
        const remoteExample: Example = {
          mainFile: fileName,
          rawMainUrl: appParam,
          category: 'remote',
          description: 'Remote App',
          files: { [fileName]: text }
        };
        examples[appParam] = remoteExample;
        return remoteExample;
      }
    } catch (e) {
      console.warn('[ginga-node] Could not fetch remote app URL:', e);
    }
  }

  return examples['video'] || Object.values(examples)[0];
}

function syncIframeStorage(win: any, example: Example, allFiles: Record<string, string>) {
  try {
    if (win && win.sessionStorage) {
      win.sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
      win.sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', example.mainFile);
      win.GingaApp = {
        appPath: example.mainFile,
        files: allFiles
      };
    }
  } catch (_) {}
}

export function getEffectiveMode(): 'player' | 'playground' | 'playgroundSingle' | 'single' {
  const search = getEffectiveSearch();
  const urlParams = new URLSearchParams(search);
  const urlMode = urlParams.get('mode');
  if (urlMode === 'player' || urlMode === 'playground' || urlMode === 'playgroundSingle' || urlMode === 'single') {
    return urlMode as any;
  }

  const bodyMode = document.body?.getAttribute('data-mode');
  if (bodyMode === 'player' || bodyMode === 'playground' || bodyMode === 'playgroundSingle' || bodyMode === 'single') {
    return bodyMode as any;
  }

  const pathname = (typeof window !== 'undefined' ? window.location.pathname : '').toLowerCase();
  if (pathname.includes('player.html') || pathname.endsWith('/player') || pathname.endsWith('/player/')) {
    return 'player';
  }

  return 'playground';
}

export async function initPlayer(): Promise<void> {
  console.log('[ginga-node] INFO: initPlayer() starting...');
  document.body.classList.add('mode-player');
  const appEl = document.getElementById('app');
  if (!appEl) {
    console.error('[ginga-node] #app element not found');
    return;
  }

  const search = getEffectiveSearch();
  const urlParams = new URLSearchParams(search);
  const appParam = urlParams.get('app');
  const playerParam = urlParams.get('player');

  const playerBaseUrl = resolvePlayerBaseUrl(playerParam);
  const targetExample = await resolveTargetExample(appParam);
  await loadExampleFiles(targetExample);

  const allFiles = getAllFiles(targetExample);

  try {
    window.sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
    window.sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', targetExample.mainFile);
    (window as any).GingaApp = {
      appPath: targetExample.mainFile,
      files: allFiles
    };
  } catch (e) {
    console.warn('[ginga-node] Could not set window.sessionStorage:', e);
  }

  const iframe = document.createElement('iframe');
  iframe.id = 'preview-frame';
  iframe.style.cssText = 'width:100%; height:100%; border:none; margin:0; padding:0; display:block;';

  iframe.onload = () => {
    syncIframeStorage(iframe.contentWindow, targetExample, allFiles);
  };

  const srcUrl = `${playerBaseUrl}?app=${encodeURIComponent(targetExample.mainFile)}`;
  console.log('[ginga-node] INFO: Mounting inner player iframe src:', srcUrl);

  iframe.src = srcUrl;
  appEl.replaceChildren(iframe);
}

export async function initPlayground(mode: string): Promise<void> {
  console.log('[ginga-node] INFO: initPlayground() starting in mode:', mode);

  let appEl = document.getElementById('app');
  if (!appEl) {
    appEl = document.createElement('div');
    appEl.id = 'app';
    document.body.appendChild(appEl);
  }

  if (!document.getElementById('editor-container')) {
    appEl.innerHTML = `
    <header class="playground-header">
      <div class="header-left" style="display: flex; align-items: center; gap: 20px;">
        <div class="logo">Ginga Playground</div>
        <div class="controls">
          <label for="example-select" style="font-size: 0.9rem; color: #ccc;">Select example:</label>
          <select id="example-select">
            <optgroup label="General Examples">
              <option value="video">video.ncl</option>
              <option value="lua_canvas">lua_canvas.ncl</option>
              <option value="image">image.ncl</option>
              <option value="image_html">image.html</option>
              <option value="current_service">current_service.html</option>
            </optgroup>
            <optgroup label="Primeiro João">
              <option value="pj_00syncProp">00syncProp.ncl</option>
              <option value="pj_01sync">01sync.ncl</option>
              <option value="pj_02syncInt">02syncInt.ncl</option>
              <option value="pj_03context">03context.ncl</option>
              <option value="pj_04reuse">04reuse.ncl</option>
              <option value="pj_05return">05return.ncl</option>
              <option value="pj_06switch">06switch.ncl</option>
              <option value="pj_07transition">07transition.ncl</option>
              <option value="pj_08animation">08animation.ncl</option>
              <option value="pj_09settings">09settings.ncl</option>
              <option value="pj_10menu">10menu.ncl</option>
              <option value="pj_11nclua">11nclua.ncl</option>
              <option value="pj_12embNCL">12embNCL.ncl</option>
            </optgroup>
          </select>
          <button id="run-btn">Run</button>
          <button id="upload-btn">Upload Files</button>
          <input type="file" id="file-input" multiple style="display: none;"
            accept=".ncl,.xml,.lua,.html,.js,.css,.txt,.png,.jpg,.jpeg,.mp4,.mp3,.gif,.webp" />
        </div>
      </div>
      <div class="header-right" style="font-size: 0.8rem; color: #aaa; display: flex; align-items: center; gap: 5px;">
        Powered by <a href="https://github.com/ginga-org-br/gingaf" target="_blank" rel="noopener noreferrer"
          style="color: #58a6ff; text-decoration: none; display: flex; align-items: center; gap: 5px;">
          gingaf
          <svg height="16" aria-hidden="true" viewBox="0 0 16 16" version="1.1" width="16" data-view-component="true"
            fill="currentColor">
            <path
              d="M8 0c4.42 0 8 3.58 8 8a8.013 8.013 0 0 1-5.45 7.59c-.4.08-.55-.17-.55-.38 0-.27.01-1.13.01-2.2 0-.75-.25-1.23-.54-1.48 1.78-.2 3.65-.88 3.65-3.95 0-.88-.31-1.59-.82-2.15.08-.2.36-1.02-.08-2.12 0 0-.67-.22-2.2.82-.64-.18-1.32-.27-2-.27-.68 0-1.36.09-2 .27-1.53-1.03-2.2-.82-2.2-.82-.44 1.1-.16 1.92-.08 2.12-.51.56-.82 1.28-.82 2.15 0 3.06 1.86 3.75 3.64 3.95-.23.2-.44.55-.51 1.07-.46.21-1.61.55-2.33-.66-.15-.24-.6-.83-1.23-.82-.67.01-.27.38.01.53.34.19.73.9.82 1.13.16.45.68 1.31 2.69.94 0 .67.01 1.3.01 1.49 0 .21-.15.45-.55.38A7.995 7.995 0 0 1 0 8c0-4.42 3.58-8 8-8Z">
            </path>
          </svg>
        </a>
      </div>
    </header>
    <main class="split-pane">
      <div id="editor-wrapper">
        <div id="editor-tabs"></div>
        <div id="editor-container"></div>
        <div id="editor-overlay" class="hidden">
          <span>Editing blocked while running. Click Stop to edit.</span>
        </div>
      </div>
      <div id="preview-container">
        <iframe id="preview-frame" src="about:blank" frameborder="0"></iframe>
      </div>
    </main>`;
  }

  const editorContainer = document.getElementById('editor-container');
  const editorTabs = document.getElementById('editor-tabs');
  const runBtn = document.getElementById('run-btn');
  const uploadBtn = document.getElementById('upload-btn');
  const fileInput = document.getElementById('file-input') as HTMLInputElement;
  const selectEl = document.getElementById('example-select') as HTMLSelectElement;
  const iframe = document.getElementById('preview-frame') as HTMLIFrameElement;

  if (!editorContainer || !editorTabs || !runBtn || !selectEl || !iframe) {
    console.error('[ginga-node] Required Playground DOM elements not found');
    return;
  }

  const search = getEffectiveSearch();
  const urlParams = new URLSearchParams(search);
  const appParam = urlParams.get('app') || urlParams.get('example');
  const playerParam = urlParams.get('player');
  const isEmbed = urlParams.get('embed') === 'true' || mode === 'single' || mode === 'playgroundSingle';

  const playerBaseUrl = resolvePlayerBaseUrl(playerParam);

  if (isEmbed) {
    document.body.classList.add('mode-single');
    document.body.classList.add('embed-mode');
    const exampleSelect = document.getElementById('example-select');
    if (exampleSelect) exampleSelect.style.display = 'none';
    const selectLabel = document.querySelector('label[for="example-select"]') as HTMLElement;
    if (selectLabel) selectLabel.style.display = 'none';
    if (uploadBtn) uploadBtn.style.display = 'none';
  }

  let currentExample = await resolveTargetExample(appParam);
  let currentFileName = currentExample.mainFile;
  let isRunning = false;

  const foundKey = Object.keys(examples).find(k => examples[k] === currentExample);
  if (foundKey && selectEl) {
    selectEl.value = foundKey;
  }

  await loadExampleFiles(currentExample);

  const editor = monaco.editor.create(editorContainer, {
    value: currentExample.files[currentFileName] || '',
    language: currentFileName.endsWith('.lua') ? 'lua' : (currentFileName.endsWith('.html') ? 'html' : 'xml'),
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
      const allFiles = getAllFiles(currentExample);

      sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(allFiles));
      sessionStorage.setItem('GINGA_PLAYGROUND_MAIN', currentExample.mainFile);

      editor.updateOptions({ readOnly: true });
      document.getElementById('editor-overlay')?.classList.remove('hidden');
      runBtn.textContent = 'Stop';

      iframe.src = playerBaseUrl;
      iframe.onload = () => {
        syncIframeStorage(iframe.contentWindow, currentExample, allFiles);
      };
      isRunning = true;
    }
  });
}

const mode = getEffectiveMode();
console.log('[ginga-node] INFO: main.ts router dispatched mode:', mode);

if (mode === 'player') {
  initPlayer();
} else {
  initPlayground(mode);
}
