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
  if (!sample || sample.available !== true || !validPercent(sample.gpu)
      || typeof sample.temperature !== "number" || !isFinite(sample.temperature) || sample.temperature < 0 || sample.temperature > 150)
    return {available: false, gpu: -1, temperature: -1}
  return {available: true, gpu: Math.round(sample.gpu), temperature: Math.round(sample.temperature)}
}
if (typeof module !== "undefined") module.exports = {hardware: hardware, resetBaseline: resetBaseline, gpu: gpu}
