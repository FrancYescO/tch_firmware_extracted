
var duma = duma || {};
duma.type = top.duma.type || {
  wordLog: "",
  onWords: [],
  wordInterval: null,
  extension_time: 1000,
  keyDownElems: [],

  clearListeners: function(){
    for(var i = 0; i < duma.type.keyDownElems.length; i++){
      var elem = duma.type.keyDownElems[i];
      if(elem){
        elem.removeEventListener("keydown",duma.type.onKey);
      }
    }
  },
  doListeners: function(extra){
    var elems = [
      document,
      $("iframe").contents()[0]
    ].concat(extra || []);
    for(var i = 0; i < elems.length; i++){
      var elem = elems[i];
      if(elem){
        var exists = duma.type.keyDownElems.includes(elem);
        if(!exists){
          elem.addEventListener("keydown",duma.type.onKey);
          duma.type.keyDownElems.push(elem);
        }
      }
    }
  },

  init: function(){
    duma.type.doListeners();
    return duma.type;
  },

  OnWord: function(word,callback){
    duma.type.onWords.push({
      w: word.toLowerCase(),
      call: callback
    });
    return duma.type.onWords.length - 1;
  },
  OffWord: function(index){
    duma.type.onWords.splice(index,1);
  },

  onKey: function(event) {
    var x = event.which || event.keyCode;
    duma.type.wordLog += String.fromCharCode(x).toLowerCase();
    var doClear = false;
    for(var i = 0; i < duma.type.onWords.length; i ++){
      if(duma.type.wordLog.includes(duma.type.onWords[i].w)){
        duma.type.onWords[i].call();
        doClear = true;
      }
    }
    if(doClear)
      duma.type.ClearWordLog();
    else
      duma.type.extend();
  },

  extend: function(){
    if(duma.type.wordInterval !== null){
      clearTimeout(duma.type.wordInterval);
    }
    duma.type.wordInterval = setTimeout(duma.type.ClearWordLog,duma.type.extension_time);
  },

  ClearWordLog: function(){
    duma.type.wordLog = "";
    clearTimeout(duma.type.wordInterval);
  }
}
duma.type.init();
