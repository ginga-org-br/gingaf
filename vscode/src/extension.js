const path = require('path');
let vscode;
try {
  vscode = require('vscode');
} catch (e) {
  vscode = {
    ViewColumn: { Two: 2 },
    Range: class Range { constructor() {} },
    CodeLens: class CodeLens { constructor() {} },
    window: {
      activeTextEditor: {
        document: {
          fileName: 'test.ncl',
          getText: () => '<ncl><head></head><body><port id="p1" component="media1"/><media id="media1" src="media1.mp4"/></body ></ncl>'
        }
      },
      onDidChangeActiveTextEditor: () => ({ dispose: () => {} }),
      createWebviewPanel: () => ({
        webview: { html: '', postMessage: () => {}, onDidReceiveMessage: () => {} },
        reveal: () => {},
        onDidDispose: () => {}
      }),
      showInformationMessage: () => {},
      showWarningMessage: () => {}
    },
    languages: {
      registerCodeLensProvider: () => ({ dispose: () => {} })
    },
    commands: {
      registerCommand: (name, cb) => ({ name, cb })
    },
    workspace: {
      textDocuments: [],
      onDidOpenTextDocument: () => ({ dispose: () => {} }),
      onDidChangeTextDocument: () => ({ dispose: () => {} }),
      onDidCloseTextDocument: () => ({ dispose: () => {} })
    },
    tests: {
      createTestController: () => ({
        createRunProfile: () => ({ dispose: () => {} }),
        items: {
          add: () => {},
          delete: () => {},
          get: () => undefined,
          forEach: () => {}
        },
        createTestItem: (id, label, uri) => ({ id, label, uri }),
        dispose: () => {}
      })
    },
    TestRunProfileKind: {
      Run: 1,
      Debug: 2,
      Coverage: 3
    }
  };
}


let currentPanel = undefined;
let isExecuting = false;
let virtualClockMs = 0;
let breakpoints = new Set();
let activeEvents = new Map();
let variables = new Map();
let lastActiveEditor = undefined;
let targetDocumentUri = undefined;
let extensionContext = undefined;



function updateWebviewState() {
  if (currentPanel) {
    currentPanel.webview.postMessage({
      command: 'updateState',
      running: isExecuting,
      clockMs: virtualClockMs
    });
  }
}

function isExecutableAvailable(executable) {
  const fs = require('fs');
  if (path.isAbsolute(executable)) {
    return fs.existsSync(executable);
  }
  const pathDirs = (process.env.PATH || '').split(process.platform === 'win32' ? ';' : ':');
  const extensions = process.platform === 'win32' ? ['.exe', '.cmd', '.bat', ''] : [''];
  for (const dir of pathDirs) {
    for (const ext of extensions) {
      const fullPath = path.join(dir, executable + ext);
      if (fs.existsSync(fullPath)) {
        return true;
      }
    }
  }
  return false;
}

function openPlayer(context, targetUri) {
  console.log('[Extension] openPlayer called for URI:', targetUri ? targetUri.toString() : 'null');
  if (targetUri) {
    targetDocumentUri = targetUri;
  }
  extensionContext = context;

  let documentPath = undefined;
  if (targetUri && typeof targetUri === 'string') {
    documentPath = targetUri;
  } else if (targetUri && targetUri.fsPath) {
    documentPath = targetUri.fsPath;
  } else {
    const activeEditor = vscode.window.activeTextEditor || lastActiveEditor;
    if (activeEditor && activeEditor.document) {
      documentPath = activeEditor.document.fileName;
    }
  }

  if (!documentPath) {
    vscode.window.showWarningMessage('No active editor open or document path found.');
    return;
  }

  const cp = require('child_process');
  const fs = require('fs');

  let executable = 'gingaf';

  const userConfig = vscode.workspace.getConfiguration('vscode');
  const configuredPath = userConfig ? userConfig.get('gingafExePath') : undefined;
  if (configuredPath && configuredPath.trim() !== '' && fs.existsSync(configuredPath.trim())) {
    executable = configuredPath.trim();
  } else {
    let candidateSearchRoots = [];
    if (documentPath) {
      let curr = path.dirname(documentPath);
      for (let i = 0; i < 5; i++) {
        candidateSearchRoots.push(curr);
        const parent = path.dirname(curr);
        if (parent === curr) break;
        curr = parent;
      }
    }
    if (vscode.workspace && vscode.workspace.workspaceFolders) {
      for (const folder of vscode.workspace.workspaceFolders) {
        let curr = folder.uri.fsPath;
        for (let i = 0; i < 3; i++) {
          if (!candidateSearchRoots.includes(curr)) {
            candidateSearchRoots.push(curr);
          }
          const parent = path.dirname(curr);
          if (parent === curr) break;
          curr = parent;
        }
      }
    }

    for (const rootPath of candidateSearchRoots) {
      let possiblePaths = [];
      if (process.platform === 'win32') {
        possiblePaths = [
          path.join(rootPath, 'ginga', 'build', 'windows', 'x64', 'runner', 'Debug', 'gingaf.exe'),
          path.join(rootPath, 'ginga', 'build', 'windows', 'x64', 'runner', 'Release', 'gingaf.exe'),
          path.join(rootPath, 'build', 'windows', 'x64', 'runner', 'Debug', 'gingaf.exe'),
          path.join(rootPath, 'build', 'windows', 'x64', 'runner', 'Release', 'gingaf.exe'),
        ];
      } else if (process.platform === 'darwin') {
        possiblePaths = [
          path.join(rootPath, 'ginga', 'build', 'macos', 'Build', 'Products', 'Debug', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
          path.join(rootPath, 'ginga', 'build', 'macos', 'Build', 'Products', 'Release', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
          path.join(rootPath, 'build', 'macos', 'Build', 'Products', 'Debug', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
          path.join(rootPath, 'build', 'macos', 'Build', 'Products', 'Release', 'gingaf.app', 'Contents', 'MacOS', 'gingaf'),
        ];
      } else {
        possiblePaths = [
          path.join(rootPath, 'ginga', 'build', 'linux', 'x64', 'debug', 'bundle', 'gingaf'),
          path.join(rootPath, 'ginga', 'build', 'linux', 'x64', 'release', 'bundle', 'gingaf'),
          path.join(rootPath, 'build', 'linux', 'x64', 'debug', 'bundle', 'gingaf'),
          path.join(rootPath, 'build', 'linux', 'x64', 'release', 'bundle', 'gingaf'),
        ];
      }

      for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
          executable = p;
          break;
        }
      }
      if (executable !== 'gingaf') {
        break;
      }
    }
  }

  if (!isExecutableAvailable(executable)) {
    if (configuredPath) {
      vscode.window.showErrorMessage(`Ginga player executable was not found at configured path '${configuredPath}'. Please correct the 'vscode.gingafExePath' setting.`);
    } else {
      vscode.window.showErrorMessage(`Ginga player executable '${executable}' was not found in the workspace or system PATH. Please configure the setting 'vscode.gingafExePath' in VS Code.`);
    }
    return;
  }

  try {
    console.log('[Extension] Spawning Ginga player executable:', executable, 'with documentPath:', documentPath);
    const spawnEnv = Object.assign({}, process.env, { APP: documentPath });
    const child = cp.spawn(executable, [documentPath], {
      detached: true,
      stdio: 'ignore',
      cwd: path.dirname(executable),
      env: spawnEnv
    });
    child.on('error', (err) => {
      console.error('[Extension] Failed child process spawn error:', err);
    });
    child.unref();
    vscode.window.showInformationMessage(`Started Ginga player for: ${path.basename(documentPath)}`);
  } catch (err) {
    console.error('[Extension] Exception during cp.spawn:', err);
    vscode.window.showErrorMessage(`Failed to start Ginga player: ${err.message}`);
  }
}

function startExecution() {
  console.log('[Extension] startExecution called.');
  let document = undefined;

  if (targetDocumentUri) {
    const openDoc = vscode.workspace.textDocuments.find(
      d => d.uri.toString() === targetDocumentUri.toString()
    );
    if (openDoc) {
      document = openDoc;
    }
  }

  if (!document) {
    const activeEditor = vscode.window.activeTextEditor || lastActiveEditor;
    if (activeEditor) {
      document = activeEditor.document;
    }
  }

  if (!document) {
    console.log('[Extension] startExecution failed: no active document found.');
    vscode.window.showWarningMessage('No active editor open to execute.');
    return;
  }

  const fileName = path.basename(document.fileName);
  const fileText = document.getText();
  console.log('[Extension] Loading NCL document:', fileName);

  isExecuting = true;
  virtualClockMs = 0;
  updateWebviewState();

  if (currentPanel && extensionContext) {
    currentPanel.title = `Ginga Player: ${fileName}`;
    const fileUri = currentPanel.webview.asWebviewUri(document.uri).toString();
    const playerUriBase = currentPanel.webview.asWebviewUri(
      vscode.Uri.file(path.join(extensionContext.extensionPath, 'player', 'index.html'))
    ).toString();
    const targetPlayerUri = `${playerUriBase}?APP=${encodeURIComponent(fileUri)}`;
    currentPanel.webview.postMessage({
      command: 'loadUri',
      uri: targetPlayerUri,
      fileContent: fileText,
      fileName: fileName
    });
  }
  vscode.window.showInformationMessage('Ginga NCL document execution started.');
}

function stopExecution() {
  isExecuting = false;
  updateWebviewState();
  if (currentPanel) {
    currentPanel.title = 'Ginga Visual Player & Debugger';
  }
  vscode.window.showInformationMessage('Ginga NCL document execution stopped.');
}

function tickClock(deltaMs = 100) {
  if (!isExecuting) {
    vscode.window.showWarningMessage('Cannot tick Virtual Clock when execution is stopped.');
    return;
  }
  virtualClockMs += deltaMs;
  updateWebviewState();
}

function handleBridgeMessage(message) {
  if (!message || typeof message !== 'object') {
    return { status: 'error', error: 'Invalid message payload' };
  }

  switch (message.type) {
    case 'step':
      tickClock(message.deltaMs || 100);
      return { status: 'ok', type: 'stepResponse', clockMs: virtualClockMs, running: isExecuting };
    case 'inspectState':
      return { status: 'ok', type: 'stateResponse', clockMs: virtualClockMs, running: isExecuting };
    case 'triggerEvent':
      if (message.eventId && message.state) {
        activeEvents.set(message.eventId, message.state);
      }
      return { status: 'ok', type: 'eventTriggered', eventId: message.eventId, active: true };
    case 'linkEvaluated':
      return { status: 'ok', type: 'linkStatus', linkId: message.linkId, evaluated: true };
    case 'setBreakpoint':
      if (message.nodeId) breakpoints.add(message.nodeId);
      return { status: 'ok', type: 'breakpointSet', nodeId: message.nodeId, breakpoints: Array.from(breakpoints) };
    case 'clearBreakpoint':
      if (message.nodeId) breakpoints.delete(message.nodeId);
      return { status: 'ok', type: 'breakpointCleared', nodeId: message.nodeId, breakpoints: Array.from(breakpoints) };
    case 'getBreakpoints':
      return { status: 'ok', type: 'breakpointsList', breakpoints: Array.from(breakpoints) };
    case 'inspectActiveEvents':
      return { status: 'ok', type: 'activeEventsResponse', events: Array.from(activeEvents.entries()).map(([id, state]) => ({ id, state })) };
    case 'setVariable':
      if (message.name !== undefined && message.value !== undefined) {
        variables.set(message.name, message.value);
      }
      return { status: 'ok', type: 'variableSet', name: message.name, value: message.value };
    case 'inspectVariable':
      const value = message.name ? variables.get(message.name) : undefined;
      return { status: 'ok', type: 'variableInspected', name: message.name, value: value };
    case 'listVariables':
      return { status: 'ok', type: 'variablesListResponse', variables: Array.from(variables.entries()).map(([name, val]) => ({ name, val })) };
    default:
      return { status: 'error', error: 'Unknown message type: ' + message.type };
  }
}

function activate(context) {
  extensionContext = context;
  const initialEditor = vscode.window.activeTextEditor;
  if (initialEditor && (initialEditor.document.languageId === 'xml' || initialEditor.document.fileName.endsWith('.ncl') || initialEditor.document.fileName.endsWith('.html'))) {
    lastActiveEditor = initialEditor;
  }

  const changeEditorSub = vscode.window.onDidChangeActiveTextEditor(editor => {
    if (editor && (editor.document.languageId === 'xml' || editor.document.fileName.endsWith('.ncl') || editor.document.fileName.endsWith('.html'))) {
      lastActiveEditor = editor;
    }
  });

  const openPlayerCmd = vscode.commands.registerCommand('ginga.openPlayer', (uri) => openPlayer(context, uri));

  context.subscriptions.push(changeEditorSub, openPlayerCmd);
}

function deactivate() {
  currentPanel = undefined;
  isExecuting = false;
  virtualClockMs = 0;
  breakpoints.clear();
  activeEvents.clear();
  variables.clear();
}

module.exports = {
  activate,
  deactivate,
  startExecution,
  stopExecution,
  tickClock,
  openPlayer,
  handleBridgeMessage
};

