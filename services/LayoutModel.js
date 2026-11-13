// Keep the DWM core fixed while retaining registered add-ons from shell.json.
function configuredExtras(layout, registry) {
  var core = ["omarchy.menu", "omarchy.workspaces", "omarchy.active-window", "omarchy.media",
              "omarchy.indicators", "omarchy.tray", "omarchy.clock", "omarchy.audio",
              "omarchy.network", "omarchy.bluetooth", "omarchy.power", "omarchy.keyboard-layout",
              "omarchy.spacer"]
  var sections = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
  var seen = Object.create(null)
  var result = []
  for (var i = 0; i < sections.length; i++) {
    var entries = layout && Array.isArray(layout[sections[i]]) ? layout[sections[i]].slice(0,64) : []
    for (var j = 0; j < entries.length; j++) {
      var entry = typeof entries[j] === "string" ? {id: entries[j]} : entries[j]
      if (!entry || typeof entry.id !== "string") continue
      var id = entry.id
      if (core.indexOf(id) >= 0 || id.indexOf("dwm.") === 0 || seen[id]) continue
      if (!registry || !registry[id] || !registry[id].component) continue
      seen[id] = true
      result.push(JSON.parse(JSON.stringify(entry)))
    }
  }
  return result
}
if (typeof module !== "undefined") module.exports = {configuredExtras: configuredExtras}
