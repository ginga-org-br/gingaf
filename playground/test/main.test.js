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
    image_html: { mainFile: 'image.html', category: 'html' }
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
  assert.strictEqual(resolveExampleKey('nonexistent', mockExamples), 'video');
  assert.strictEqual(resolveExampleKey(null, mockExamples), 'video');

  console.log('All playground main logic tests passed successfully.');
}

runTests();
