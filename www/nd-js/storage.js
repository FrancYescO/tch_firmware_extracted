/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

var duma = duma || {};

duma.storage = function (packageId, name, value) {
  function getKey(packageId, name) {
    return packageId + "._" + name;
  }

  if (typeof (localStorage) === "undefined") {
    throw Error("Local storage not implemented in browser");
  }

  if (typeof (value) === "undefined") {
    return localStorage.getItem(getKey(packageId, name));
  } else if (value === null) {
    return localStorage.removeItem(getKey(packageId, name));
  } else {
    return localStorage.setItem(getKey(packageId, name), value);
  }
}

duma.storageReset = function(packageId) {
  if (typeof (localStorage) === "undefined") {
    throw Error("Local storage not implemented in browser");
  }
  var count = 0;
  for(var key in localStorage) {
    if(key.startsWith(packageId)){
      localStorage.removeItem(key);
      count += 1;
    }
  }
  return count;
}
