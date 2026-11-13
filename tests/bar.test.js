'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const repo = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(repo, 'DwmBar.qml'), 'utf8');
assert(source.includes('import "file:/usr/share/omarchy/shell/plugins/bar" as OmarchyBar'));
for (const match of source.matchAll(/^import "(widgets\/[^\"]+)"/gm)) {
  assert(fs.statSync(path.join(repo, match[1])).isDirectory());
}
function method(name) {
  const match = source.match(new RegExp('function ' + name + '\\(\\) \\{([\\s\\S]*?)\\n  \\}'));
  assert(match, 'Missing ' + name);
  return new Function('with(this){' + match[1] + '}');
}
const apply = method('applyBarConfig');
for (const previous of [
  {position: 'bottom', background: 'opaque', layout: {left: [{id: 'unrelated.plugin'}]}},
  {background: 'glassy', layout: {}},
  {background: 'none'},
  {}
]) {
  const before = JSON.stringify(previous);
  const context = {
    position: 'bottom', barConfig: previous, glassy: false, glassSyncedLook: '',
    barConfigSerial: 0, layoutConfig: null,
    normalizeLayout: value => value,
    setRequestedTransparency(value) { this.requestedTransparent = value; },
    Util: {execDetached() {}}
  };
  apply.call(context);
  assert.equal(context.position, 'top');
  assert.deepEqual(context.layoutConfig.left.map(entry => entry.id), ['dwm.workspaces', 'dwm.music']);
  const ids = context.layoutConfig.right.map(entry => entry.id);
  for (const required of ['dwm.status', 'dwm.temperature', 'dwm.indicators', 'dwm.tray', 'omarchy.audio', 'omarchy.clock']) assert(ids.includes(required));
  assert(!JSON.stringify(context.layoutConfig).includes('anky.'));
  assert(!JSON.stringify(context.layoutConfig).includes('whitewebdev.'));
  assert.equal(context.requestedTransparent, previous.background === 'none');
  assert.equal(context.glassy, previous.background === 'glassy');
  assert.equal(JSON.stringify(previous), before, 'Enabling must not replace the previous layout');
}
const bind = method('bindRegistry');
const native = {widgets: {'omarchy.audio': {}}};
const bundled = {};
const context = {barWidgetRegistry: native, inheritedRegistry: null, bundledRegistry: bundled};
bind.call(context);
assert.equal(context.barWidgetRegistry, bundled);
assert.equal(context.inheritedRegistry, native);
bind.call(context);
assert.equal(context.inheritedRegistry, native, 'Repeated injection must not wrap the registry in itself');
const refreshed = {widgets: {'omarchy.clock': {}}};
context.barWidgetRegistry = refreshed;
bind.call(context);
assert.equal(context.inheritedRegistry, refreshed);
assert.equal(context.barWidgetRegistry, bundled);
console.log('Single-plugin checks passed: self-contained layout, preserved prior config, backgrounds, native imports and registry reinjection.');

// Only the root owns readers. Monitor widgets consume the same instance.
assert.equal((source.match(/Services\.Telemetry\s*\{/g) || []).length, 1);
assert.equal((source.match(/telemetry: sharedTelemetry/g) || []).length, 3);
for (const file of ['status/Status.qml','temperature/Temperature.qml','indicators/Indicators.qml']) {
  const widget = fs.readFileSync(path.join(repo, 'widgets', file), 'utf8');
  assert(!/\b(?:Process|Timer)\s*\{/.test(widget), file + ' must not own pollers');
}
const service = fs.readFileSync(path.join(repo,'services/Telemetry.qml'),'utf8');
function telemetryMethod(name) {
  const match=service.match(new RegExp('function '+name+'\\(manual\\) \\{([\\s\\S]*?)\\n  \\}'));
  assert(match, name); return new Function('manual','with(this){'+match[1]+'}');
}
const requestFast = telemetryMethod('refreshFast'), requestGpu = telemetryMethod('refreshGpu');
const shared = {hardwarePaused:true,fastRequests:0,gpuRequests:0,fast:{running:false},gpuRead:{running:false},helper:mode=>['python','telemetry.py',mode]};
shared.root=shared;
requestFast.call(shared,false); requestGpu.call(shared,false);
assert.equal(shared.fastRequests,0);assert.equal(shared.gpuRequests,0);
requestFast.call(shared,true);requestGpu.call(shared,true);
assert.equal(shared.fastRequests,1);assert.equal(shared.gpuRequests,1);
assert.equal(shared.fast.command[2],'snapshot');
requestFast.call(shared,true);assert.equal(shared.fastRequests,1,'Concurrent requests must coalesce');
shared.hardwarePaused=false;shared.fast.running=false;shared.gpuRead.running=false;
requestFast.call(shared,false);requestGpu.call(shared,false);
assert.equal(shared.fastRequests,2);assert.equal(shared.gpuRequests,2);
assert(service.includes('running: root.gameReady && !root.hardwarePaused'));
console.log('Efficiency checks passed: one service for all monitors; automatic reads pause, manual reads work, and polling resumes.');
