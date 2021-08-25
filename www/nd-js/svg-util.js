var duma = duma || {};
duma.svg = duma.svg || {};

duma.svg._DEFAULT_ICONSET = "icons";
duma.svg._meta = duma.svg._meta || Polymer.Base.create('iron-meta', {type: 'iconset'});

window.addEventListener('iron-iconset-added',function(e){
  //Can attach stuff to do here
});

duma.svg.getIconset = function(iconsetName){
  return /** @type {?Polymer.Iconset} */ (duma.svg._meta.byKey(iconsetName));
}

duma.svg.splitIconName = function(icon){
  var parts = (icon || '').split(':');
  var iconName = parts.pop();
  var iconsetName = parts.pop() || duma.svg._DEFAULT_ICONSET;
  return [iconsetName, iconName];
}

duma.svg.iconExists = function(icon){
  var parts = duma.svg.splitIconName(icon);
  var iconset = duma.svg.getIconset(parts[0]);
  var names = iconset.getIconNames();
  for(var i = 0; i < names.length; i ++){
    if(names[i] === icon){
      return true;
    }
  }
  return false;
}

duma.svg.fromIconset = function(icon){
  var parts = duma.svg.splitIconName(icon);
  var iconset = duma.svg.getIconset(parts[0]);
  duma.svg.iconExists(icon);
  if(iconset){
    var icon = iconset._cloneIcon(parts[1],false);
    return icon || null;
  }else{
    console.error("Cannot find an iconset with name:", parts[0]);
    return null;
  }
}

duma.svg.fromIconsetPromise = function(icon){
  return new Promise(function(resolve,reject){
    if(duma.svg.iconExists(icon)){
      resolve(duma.svg.fromIconset(icon));
    }else{
      reject("Icon not found: " + icon)
    }
  })
}

duma.svg.urlcached = duma.svg.urlcached || []
duma.svg.fromURLPromise = function(url){
  return new Promise(function(resolve,reject){
    if(duma.svg.urlcached[url]){
      resolve(duma.svg.urlcached[url]);
    }else{
      $.ajax({
        url: url,
        success: function(result){
          duma.svg.urlcached[url] = result.documentElement ? result.documentElement : false;
          resolve(duma.svg.urlcached[url]);
        },
        error: function(e){
          reject(e);
        }
      })
    }
  })
}

duma.svg.getPromise = function(img){
  if(typeof(img) === "string"){
    if(img.endsWith(".svg")){
      return duma.svg.fromURLPromise(img);
    }else if(duma.svg.iconExists(img)){
      return duma.svg.fromIconsetPromise(img);
    }
  }
  return null;
}
