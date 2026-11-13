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
const model = require('../services/TelemetryModel.js');
let sample = model.hardware({total: 0, idle: 0, cpu: -1, ram: -1}, {total: 1000, idle: 800, ram: 60});
sample = model.hardware(sample, {total: 1200, idle: 900, ram: 75});
assert.equal(sample.cpu, 50); assert.equal(sample.ram, 75);
const reset = model.resetBaseline(sample);
const resumed = model.hardware(reset, {total: 999999, idle: 999900, ram: 40});
assert.equal(resumed.cpu, 50, 'Resume must discard the game interval from the CPU average');
assert.equal(model.hardware(sample, {total: '<img src=x>', idle: 0, ram: 50}), sample);
assert.equal(model.hardware(sample, {total: 1200, idle: 900, ram: 101}), sample);
assert.equal(model.hardware(reset, {total: 1300, idle: 950, ram: 35, cpu: 73}).cpu, 73, 'Manual snapshot supplies a short CPU sample');
assert.deepEqual(model.gpu({available: true, gpu: 28, temperature: 48}), {available: true, gpu: 28, temperature: 48});
for (const bad of [null, {available:true,gpu:101,temperature:48}, {available:true,gpu:28,temperature:151}, {available:true,gpu:'<img src=x>',temperature:48}])
  assert.equal(model.gpu(bad).available, false);
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
console.log('Parser checks passed: shared CPU deltas, resume baseline, manual samples, combined GPU/temperature, bounded palette and markup-shaped input.');
