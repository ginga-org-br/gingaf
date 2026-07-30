import assert from 'assert';

function parseQueryConfig(searchString) {
  const params = new URLSearchParams(searchString);
  const rateStr = params.get('rate') || params.get('playbackRate');
  const parsedRate = rateStr ? parseFloat(rateStr) : 1.0;
  return {
    requestedExample: params.get('example') || params.get('app'),
    isEmbed: params.get('embed') === 'true',
    category: params.get('category'),
    theme: params.get('theme'),
    playbackRate: isNaN(parsedRate) || parsedRate <= 0 ? 1.0 : parsedRate
  };
}

function resolveExampleKey(requested, available) {
  if (!requested) return 'video';
  const key = Object.keys(available).find(k =>
    k === requested ||
    available[k].mainFile === requested ||
    available[k].mainFile === requested + '.ncl'
  );
  return key || 'video';
}

function runTests() {
  const mockExamples = {
    video: { mainFile: 'video.ncl', category: 'media' },
    lua_canvas: { mainFile: 'lua_canvas.ncl', category: 'lua' },
    image_html: { mainFile: 'image.html', category: 'html' },
    pj_00syncProp: { mainFile: '00syncProp.ncl', category: 'primeiro-joao' },
    pj_01sync: { mainFile: '01sync.ncl', category: 'primeiro-joao' },
    pj_02syncInt: { mainFile: '02syncInt.ncl', category: 'primeiro-joao' },
    pj_03context: { mainFile: '03context.ncl', category: 'primeiro-joao' },
    pj_04reuse: { mainFile: '04reuse.ncl', category: 'primeiro-joao' },
    pj_05return: { mainFile: '05return.ncl', category: 'primeiro-joao' },
    pj_06switch: { mainFile: '06switch.ncl', category: 'primeiro-joao' },
    pj_07transition: { mainFile: '07transition.ncl', category: 'primeiro-joao' },
    pj_08animation: { mainFile: '08animation.ncl', category: 'primeiro-joao' },
    pj_09settings: { mainFile: '09settings.ncl', category: 'primeiro-joao' },
    pj_10menu: { mainFile: '10menu.ncl', category: 'primeiro-joao' },
    pj_11nclua: { mainFile: '11nclua.ncl', category: 'primeiro-joao' },
    pj_12embNCL: { mainFile: '12embNCL.ncl', category: 'primeiro-joao' }
  };

  const config1 = parseQueryConfig('?example=lua_canvas&embed=true&category=lua&theme=dark&rate=2.0');
  assert.strictEqual(config1.requestedExample, 'lua_canvas');
  assert.strictEqual(config1.isEmbed, true);
  assert.strictEqual(config1.category, 'lua');
  assert.strictEqual(config1.theme, 'dark');
  assert.strictEqual(config1.playbackRate, 2.0);

  const config2 = parseQueryConfig('?app=image.html');
  assert.strictEqual(config2.requestedExample, 'image.html');
  assert.strictEqual(config2.isEmbed, false);
  assert.strictEqual(config2.theme, null);
  assert.strictEqual(config2.playbackRate, 1.0);

  assert.strictEqual(resolveExampleKey('lua_canvas', mockExamples), 'lua_canvas');
  assert.strictEqual(resolveExampleKey('image.html', mockExamples), 'image_html');

  const pjExamples = [
    { key: 'pj_00syncProp', file: '00syncProp.ncl', stem: '00syncProp' },
    { key: 'pj_01sync', file: '01sync.ncl', stem: '01sync' },
    { key: 'pj_02syncInt', file: '02syncInt.ncl', stem: '02syncInt' },
    { key: 'pj_03context', file: '03context.ncl', stem: '03context' },
    { key: 'pj_04reuse', file: '04reuse.ncl', stem: '04reuse' },
    { key: 'pj_05return', file: '05return.ncl', stem: '05return' },
    { key: 'pj_06switch', file: '06switch.ncl', stem: '06switch' },
    { key: 'pj_07transition', file: '07transition.ncl', stem: '07transition' },
    { key: 'pj_08animation', file: '08animation.ncl', stem: '08animation' },
    { key: 'pj_09settings', file: '09settings.ncl', stem: '09settings' },
    { key: 'pj_10menu', file: '10menu.ncl', stem: '10menu' },
    { key: 'pj_11nclua', file: '11nclua.ncl', stem: '11nclua' },
    { key: 'pj_12embNCL', file: '12embNCL.ncl', stem: '12embNCL' }
  ];

  for (const item of pjExamples) {
    assert.strictEqual(resolveExampleKey(item.stem, mockExamples), item.key);
    assert.strictEqual(resolveExampleKey(item.file, mockExamples), item.key);
    assert.strictEqual(resolveExampleKey(item.key, mockExamples), item.key);
  }

  assert.strictEqual(resolveExampleKey('nonexistent', mockExamples), 'video');
  assert.strictEqual(resolveExampleKey(null, mockExamples), 'video');

  console.log('All playground main logic tests passed successfully.');
}

runTests();
