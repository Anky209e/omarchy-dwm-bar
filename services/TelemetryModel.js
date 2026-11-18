function validPercent(value) {
  return typeof value === "number" && isFinite(value) && value >= 0 && value <= 100
}
function hardware(previous, sample) {
  if (!sample || !Number.isSafeInteger(sample.total) || !Number.isSafeInteger(sample.idle)
      || sample.total <= 0 || sample.idle < 0 || sample.idle > sample.total || !validPercent(sample.ram)) return previous
  var cpu = previous.cpu
  if (validPercent(sample.cpu)) cpu = Math.round(sample.cpu)
  else if (previous.total > 0 && sample.total > previous.total && sample.idle >= previous.idle) {
    var delta = sample.total - previous.total
    cpu = Math.max(0, Math.min(100, Math.round(100 * (1 - (sample.idle - previous.idle) / delta))))
  }
  return {total: sample.total, idle: sample.idle, cpu: cpu, ram: Math.round(sample.ram)}
}
function resetBaseline(previous) {
  return {total: 0, idle: 0, cpu: previous.cpu, ram: previous.ram}
}
function gpu(sample) {
  if (!sample || sample.available !== true) return {available:false,gpu:-1,temperature:-1}
  var load=validPercent(sample.gpu)?Math.round(sample.gpu):-1
  var temp=typeof sample.temperature==="number" && isFinite(sample.temperature) && sample.temperature>=0 && sample.temperature<=150?Math.round(sample.temperature):-1
  if ((sample.gpu!==-1 && load<0) || (sample.temperature!==-1 && temp<0)) return {available:false,gpu:-1,temperature:-1}
  return {available:load>=0 || temp>=0,gpu:load,temperature:temp}
}
if (typeof module !== "undefined") module.exports = {hardware: hardware, resetBaseline: resetBaseline, gpu: gpu}
