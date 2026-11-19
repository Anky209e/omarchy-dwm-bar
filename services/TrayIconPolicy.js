// Only a path-free theme lookup may reach Quickshell synchronously.
function themeName(value) {return /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,255}$/.test(value) && value!=="." && value!==".."}
function classify(value) {
  var raw=String(value || "")
  if(!raw || raw.length>4096 || /[\x00-\x1f\x7f]/.test(raw))return {source:"",local:false}
  if(raw.indexOf("image://icon/")===0) {
    var id=raw.slice(13), parts=id.split("?"),name
    try{name=decodeURIComponent(parts[0])}catch(e){return {source:"",local:false}}
    var source=themeName(name)?"image://icon/"+name:""
    // Strip all client search paths/fallbacks; local paths go through the worker.
    return {source:source,local:name.charAt(0)==="/" || (source!=="" && parts.length===2 && parts[1].indexOf("path=")===0)}
  }
  if(themeName(raw))return {source:"image://icon/"+raw,local:false}
  return {source:"",local:raw.charAt(0)==="/" || raw.indexOf("file://")===0}
}
if(typeof module!=="undefined")module.exports={classify:classify,themeName:themeName}
