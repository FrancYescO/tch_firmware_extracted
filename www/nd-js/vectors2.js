/*
 * 2018 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

var duma = duma || {};

duma.vectors2 = {
  create: function (x, y) {
    return {
      x: x,
      y: y
    };
  },

  add: function (u, v) {
    return duma.vectors2.create(u.x + v.x, u.y + v.y);
  },

  subtract: function (u, v) {
    return duma.vectors2.add(u, duma.vectors2.scalarMultiply(v, -1));
  },

  dotProduct: function (u, v) {
    return (u.x * v.x) + (u.y * v.y);
  },

  perpendicular: function (u) {
    return duma.vectors2.create(u.x, -u.y);
  },

  crossProduct: function (u, v) {
    return (u.x * v.y) - (u.y * v.x);
  },

  scalarMultiply: function (u, scalar) {
    return duma.vectors2.create(u.x * scalar, u.y * scalar);
  },

  absolute: function (u) {
    return Math.sqrt((u.x * u.x) + (u.y * u.y));
  }
};
