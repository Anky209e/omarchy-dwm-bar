'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
function body(file, name) {
  const qml = fs.readFileSync(path.join(root, file), 'utf8');
  const match = qml.match(new RegExp('function ' + name + '\\(raw\\) \\{([\\s\\S]*?)\\n  \\}'));
  assert(match, `Missing function ${name}`);
  return match[1];
}
function execute(file, name) {
  return new Function('raw', `with(this){${body(file, name)}}`);
}
const gpu = execute('widgets/status/Status.qml', 'updateGpu');
const reading = {gpu: 0, gpuAvailable: false};
gpu.call(reading, '28\n');
assert.equal(reading.gpu, 28);
assert.equal(reading.gpuAvailable, true);
for (const raw of ['101', '-1', 'N/A', '', '<img src="https://example.invalid">']) {
  gpu.call(reading, raw);
  assert.equal(reading.gpuAvailable, false);
}
const temperature = execute('widgets/temperature/Temperature.qml', 'update');
const sensor = {temperature: -1};
temperature.call({root: sensor}, '48\n');
assert.equal(sensor.temperature, 48);
for (const raw of ['151', '-1', 'N/A', '', '<img src="https://example.invalid">']) {
  temperature.call({root: sensor}, raw);
  assert.equal(sensor.temperature, -1);
}
const update = execute('widgets/status/Status.qml', 'update');
const cpu = {previousTotal: 0, previousIdle: 0, cpu: -1, ram: -1};
update.call(cpu, '100 0 100 800 0 0 0 0\n1000 400');
update.call(cpu, '150 0 150 900 0 0 0 0\n1000 250');
assert.equal(cpu.cpu, 50);
assert.equal(cpu.ram, 75);
update.call(cpu, '<img src=x>');
assert.equal(cpu.cpu, 50);
assert.equal(cpu.ram, 75);
const parse = execute('widgets/status/ThemePalette.qml', 'parse');
const palette = {values: {}};
parse.call(palette, 'green = "#9ece6a"\ncyan = "#449dab"\nblue = "<img src=x>"');
assert.equal(palette.values.green, '#9ece6a');
assert.equal(palette.values.cyan, '#449dab');
assert.equal(palette.values.blue, undefined);
parse.call(palette, 'x'.repeat(65536) + '\nred = "#ff0000"');
assert.equal(palette.values.red, undefined);
for (const plugin of ['music', 'indicators', 'temperature']) {
  assert.equal(fs.readFileSync(path.join(root, 'widgets', plugin, 'ThemePalette.qml'), 'utf8'), fs.readFileSync(path.join(root, 'widgets/status/ThemePalette.qml'), 'utf8'));
}
const music = fs.readFileSync(path.join(root, 'widgets/music/Music.qml'), 'utf8');
assert(music.includes('textFormat: Text.PlainText'));
assert(!music.match(/tooltipText:\s*root\.player/));
console.log('Parser checks passed: CPU deltas, available RAM, GPU, temperature, bounded theme palette and markup-shaped input.');
