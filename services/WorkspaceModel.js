// Keep global plans and monitor-local blocks distinct; never wrap global IDs.
function workspaceIds(block, slots, values, monitorName, globalPlan) {
  var base=globalPlan?0:block*slots, ids=[],guests=[]
  for(var slot=1;slot<=slots;slot++)ids.push(base+slot)
  for(var i=0;i<values.length;i++) {
    var id=values[i].id
    if(!Number.isSafeInteger(id) || id<=0)continue
    if(globalPlan) {if(ids.indexOf(id)<0)ids.push(id)}
    else if(Math.floor((id-1)/slots)===block) {if(ids.indexOf(id)<0)ids.push(id)}
    else if(values[i].monitor && values[i].monitor.name===monitorName && guests.indexOf(id)<0)guests.push(id)
  }
  ids.sort(function(a,b){return a-b});guests.sort(function(a,b){return a-b})
  return ids.concat(guests)
}
function label(id,slots,globalPlan) {
  if(globalPlan && id>slots)return String(id)
  var slot=(id-1)%slots+1
  return slot===slots?"0":String(slot)
}
function hasGlobalPlan(raw) {
  return /^\s*o\.workspaces\.enabled\s*=\s*false\b/m.test(String(raw).slice(0,65536))
}
if(typeof module!=="undefined")module.exports={workspaceIds:workspaceIds,label:label,hasGlobalPlan:hasGlobalPlan}
