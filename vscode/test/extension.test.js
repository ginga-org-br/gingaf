const test = require('node:test');
const assert = require('node:assert');
const extension = require('../src/extension.js');

test('Extension exports functions', () => {
  assert.strictEqual(typeof extension.activate, 'function');
  assert.strictEqual(typeof extension.deactivate, 'function');
  assert.strictEqual(typeof extension.startExecution, 'function');
  assert.strictEqual(typeof extension.stopExecution, 'function');
  assert.strictEqual(typeof extension.tickClock, 'function');
  assert.strictEqual(typeof extension.getWebviewContent, 'function');
  assert.strictEqual(typeof extension.handleBridgeMessage, 'function');
});

test('Webview Content Generation', () => {
  const html = extension.getWebviewContent('Test Panel', 'vscode-resource:/player/index.html');
  assert.ok(html.includes('<title>Test Panel</title>'));
  assert.ok(html.includes('id="btn-stop"'));
  assert.ok(html.includes('id="btn-tick-100"'));
  assert.ok(html.includes('id="btn-tick-1s"'));
  assert.ok(html.includes('src="vscode-resource:/player/index.html"'));
});

test('Bridge Message Handling - State & Breakpoints', () => {
  const inspectRes = extension.handleBridgeMessage({ type: 'inspectState' });
  assert.strictEqual(inspectRes.status, 'ok');
  assert.strictEqual(inspectRes.type, 'stateResponse');

  const evtRes = extension.handleBridgeMessage({ type: 'triggerEvent', eventId: 'evt1' });
  assert.strictEqual(evtRes.status, 'ok');
  assert.strictEqual(evtRes.eventId, 'evt1');

  const linkRes = extension.handleBridgeMessage({ type: 'linkEvaluated', linkId: 'l1' });
  assert.strictEqual(linkRes.status, 'ok');
  assert.strictEqual(linkRes.linkId, 'l1');

  const setBpRes = extension.handleBridgeMessage({ type: 'setBreakpoint', nodeId: 'media_video1' });
  assert.strictEqual(setBpRes.status, 'ok');
  assert.strictEqual(setBpRes.type, 'breakpointSet');
  assert.ok(setBpRes.breakpoints.includes('media_video1'));

  const getBpRes = extension.handleBridgeMessage({ type: 'getBreakpoints' });
  assert.strictEqual(getBpRes.status, 'ok');
  assert.ok(getBpRes.breakpoints.includes('media_video1'));

  const clearBpRes = extension.handleBridgeMessage({ type: 'clearBreakpoint', nodeId: 'media_video1' });
  assert.strictEqual(clearBpRes.status, 'ok');
  assert.strictEqual(clearBpRes.type, 'breakpointCleared');
  assert.strictEqual(clearBpRes.breakpoints.length, 0);
});

test('Bridge Message Handling - Events & Variables', () => {
  extension.handleBridgeMessage({ type: 'triggerEvent', eventId: 'evt_start', state: 'OCCURRING' });
  const activeEvtRes = extension.handleBridgeMessage({ type: 'inspectActiveEvents' });
  assert.strictEqual(activeEvtRes.status, 'ok');
  assert.strictEqual(activeEvtRes.type, 'activeEventsResponse');
  assert.strictEqual(activeEvtRes.events.length, 1);
  assert.strictEqual(activeEvtRes.events[0].id, 'evt_start');
  assert.strictEqual(activeEvtRes.events[0].state, 'OCCURRING');

  const setVarRes = extension.handleBridgeMessage({ type: 'setVariable', name: 'system.language', value: 'pt-BR' });
  assert.strictEqual(setVarRes.status, 'ok');
  assert.strictEqual(setVarRes.type, 'variableSet');
  assert.strictEqual(setVarRes.name, 'system.language');
  assert.strictEqual(setVarRes.value, 'pt-BR');

  const getVarRes = extension.handleBridgeMessage({ type: 'inspectVariable', name: 'system.language' });
  assert.strictEqual(getVarRes.status, 'ok');
  assert.strictEqual(getVarRes.type, 'variableInspected');
  assert.strictEqual(getVarRes.value, 'pt-BR');

  const listVarRes = extension.handleBridgeMessage({ type: 'listVariables' });
  assert.strictEqual(listVarRes.status, 'ok');
  assert.strictEqual(listVarRes.type, 'variablesListResponse');
  assert.strictEqual(listVarRes.variables.length, 1);
  assert.strictEqual(listVarRes.variables[0].name, 'system.language');
  assert.strictEqual(listVarRes.variables[0].val, 'pt-BR');

  const errRes = extension.handleBridgeMessage({ type: 'invalidType' });
  assert.strictEqual(errRes.status, 'error');
});

test('NCL Execution State Machine', () => {
  extension.startExecution();
  const startState = extension.handleBridgeMessage({ type: 'inspectState' });
  assert.strictEqual(startState.running, true);
  assert.strictEqual(startState.clockMs, 0);

  const stepRes = extension.handleBridgeMessage({ type: 'step', deltaMs: 200 });
  assert.strictEqual(stepRes.running, true);
  assert.strictEqual(stepRes.clockMs, 200);

  extension.stopExecution();
  const stopState = extension.handleBridgeMessage({ type: 'inspectState' });
  assert.strictEqual(stopState.running, false);
});

