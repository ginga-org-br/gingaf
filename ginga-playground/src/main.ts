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
      
      sessionStorage.setItem('GINGA_PLAYGROUND_FILES', JSON.stringify(currentExample.files));
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
