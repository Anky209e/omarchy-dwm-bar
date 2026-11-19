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
assert.deepEqual(model.gpu({available:true,gpu:42,temperature:-1}),{available:true,gpu:42,temperature:-1});
assert.deepEqual(model.gpu({available:true,gpu:-1,temperature:54}),{available:true,gpu:-1,temperature:54});
const parse = execute('services/ThemePalette.qml', 'parse');
const palette = {values: {}};
parse.call(palette, 'green = "#9ece6a"\ncyan = "#449dab"\nblue = "<img src=x>"');
assert.equal(palette.values.green, '#9ece6a');
assert.equal(palette.values.cyan, '#449dab');
assert.equal(palette.values.blue, undefined);
parse.call(palette, 'x'.repeat(65536) + '\nred = "#ff0000"');
assert.equal(palette.values.red, undefined);

const music = fs.readFileSync(path.join(root, 'widgets/music/Music.qml'), 'utf8');
assert(/textFormat:\s*Text\.PlainText/.test(music));
assert(!music.match(/tooltipText:\s*root\.player/));
console.log('Parser checks passed: shared CPU deltas, resume baseline, manual samples, combined GPU/temperature, bounded palette and markup-shaped input.');

const trayPolicy=require('../services/TrayIconPolicy.js');
assert.deepEqual(trayPolicy.classify('image://icon/steam?path=/tmp/icons'),{source:'image://icon/steam',local:true});
assert.deepEqual(trayPolicy.classify('network-wireless-symbolic'),{source:'image://icon/network-wireless-symbolic',local:false});
assert.deepEqual(trayPolicy.classify('image://icon/steam?fallback=/tmp/pipe'),{source:'image://icon/steam',local:false});
for(const raw of ['image://icon//tmp/pipe','image://icon/%2ftmp%2fpipe','/tmp/pipe','file:///tmp/pipe']) {
 const policy=trayPolicy.classify(raw);assert.equal(policy.source,'');assert(policy.local);
}
for(const raw of ['image://qspixmap/1/2','image://qsimage/42','https://example.invalid/a.png','image://icon/%ZZ','image://icon/%252ftmp%252fpipe','image://unknown/file','x'.repeat(4097),'image://icon/a\u0000'])assert.equal(trayPolicy.classify(raw).source,'');
const trayQml=fs.readFileSync(path.join(root,'widgets/tray/Tray.qml'),'utf8');
assert(!trayQml.includes('source: menuRow.modelData.icon'));
assert(trayQml.includes('source: root.trayIconSource(menuRow.modelData.icon)'));
assert(trayQml.includes('source: root.trayIconSource(trayIconRoot.icon, trayIconRoot.applicationIcon)'));
console.log('Tray icon policy passed: no client path or unchecked provider reaches an Image source.');

const trayModel=require('../widgets/tray/TrayModel.js');
assert.equal(trayModel.applicationIcon({id:'discord_status_icon_1',title:''}),'discord');
assert.equal(trayModel.applicationIcon({id:'com.discordapp.Discord'}),'discord');
assert.equal(trayModel.applicationIcon({id:'/tmp/discord.png',title:'other'}),'');
assert.equal(trayModel.applicationIcon({id:'image://icon//tmp/fifo'}),'');
console.log('Discord fallback uses only the fixed installed discord theme icon.');
