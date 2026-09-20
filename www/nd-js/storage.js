/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
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
