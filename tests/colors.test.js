'use strict';
const fs=require('node:fs'), assert=require('node:assert/strict');
const source=fs.readFileSync('services/ThemePalette.qml','utf8');
function method(name,args) {
 const start=source.indexOf('  function '+name+'('), begin=source.indexOf('{',start);
 let level=1,end=begin+1;
 for(;level;end++){if(source[end]==='{')level++;if(source[end]==='}')level--;}
 return new Function(...args,source.slice(begin+1,end-1));
}
const rgb=hex=>({r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255});
global.Qt={tint:c=>typeof c==='string'?rgb(c):c,rgba:(r,g,b,a)=>({r,g,b,a})};
global.Commons={Color:{background:rgb('#000000')}};
global.luminance=method('luminance',['c']);
const readable=method('readable',['value']);
for(const background of ['#000000','#ffffff','#1d2021','#eeeeee','#777777']) {
 Commons.Color.background=rgb(background);
 for(const foreground of ['#000000','#ffffff','#555555','#777777','#ff0000','#00ff00','#0000ff','#c2a57d']) {
  const c=readable(foreground), a=luminance(c),b=luminance(Commons.Color.background);
  assert((Math.max(a,b)+0.05)/(Math.min(a,b)+0.05)>=4.5,`${foreground} on ${background}`);
 }
}
console.log('Theme contrast checks passed on dark, light and mid-tone backgrounds.');
