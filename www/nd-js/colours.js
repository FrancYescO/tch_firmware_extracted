/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
 * Luke Meppem
*/

<%
local json = require "json"

--[[
  Way to get the shades, mainly for use in CSS.
  Example usage: "< % = get_shade(0) % >"
  You will need to copy to the specific file for haserl use
]]
function get_shade(index)
  local shades = theme.COLOR_SHADES
  local total,x = 0,1
  for _,line in pairs(shades) do
    total = total + #line
  end
  index = (index % total) + 1
  while index > #shades do
    index = index - #shades 
    x = x + 1
  end
  return shades[index][x]
end
%>
/**
 * Returns list of shade arrays
 * use [x][y] to get values
 * lengths will change depending on theme
 */
function getAllColours(){
  return JSON.parse('<%= json.encode(theme.COLOR_SHADES) %>');
}

/**
 * Returns a one-dimensional list of colours, by colour, then by shade
 * So [0][0], [1][0], [2][0], [3][0], [0][1], [1][1], [2][1] etc...
 * Does not loop
 */
function getAllShades(){
  var colours = getAllColours();

  var colour = 0;
  var shade = 0;
  var ret = [];
  
  while(true){
    if (colour > colours.length - 1) {
      colour = 0;
      shade++;
    }
    var selectedColour = colours[colour];
    if (shade > selectedColour.length - 1) {
      break;
    }
    var selectedShade = selectedColour[shade];
    colour++;
    ret.push(selectedShade);
  };
  return ret;
}

/**
 * Returns a function, which when called, will return the next shade
 * Cycles through colours, and then to next "column" of shades
 * After all shades, will loop back to start
 */
function getColourGenerator () {
  var shades = getAllShades();
  var shade = 0;
  return function () {
    if(shade > shades.length - 1){
      shade = 0;
    }
    var selectedShade = shades[shade];
    shade ++;
    return selectedShade;
  };
}

class Color {
  constructor(colString=null) {
    this.r = 0;
    this.g = 0;
    this.b = 0;
    this.a = 0;
    if(colString) this.parse(colString);
  }
  
  setVal(val, i){
  	val = Math.max(0,Math.min(255,parseInt(val)));
    switch(i){
      case 0:
        this.r = val;
        break;
      case 1:
        this.g = val;
        break;
      case 2:
        this.b = val;
        break;
      case 3:
        this.a = val;
        break;
    }
    return this;
  }

  _parseHex(inp){
    var str = inp.replace('#','').replace('0x','');
    //if length 3 or 4, convert to double up.
    //i.e. #FFF becomes #FFFFFF
    if(str.length === 3 || str.length === 4){
      str = str.match(/.{1}/g).map(v => v+v).join("");
    }
    if(str.length === 6 || str.length === 8){
      var splits = str.match(/.{2}/g);
      for(var i = 0; i < splits.length; i ++){
        var conv = parseInt(splits[i],16);
        this.setVal(conv,i);
      }
      if(splits.length === 3){
      	this.setVal(255,3);
      }
      return this;
    }else{
      console.error("Input string is not valid for hex");
    }
  }
  _parseRGB(inp){
    var str = inp.match(/\((.*?)\)/);
    if(str.length > 1){
    	var splits = str[1].split(',');
      for(var i = 0; i < splits.length; i ++){
      	var split = splits[i];
        if(split.indexOf('.') > -1){
          var conv = parseFloat(split);
          if(conv < 1) conv = conv*255;
          this.setVal(Math.round(conv),i);
        }else{
        	this.setVal(split,i);
        }
      }
      if(splits.length === 3){
      	this.setVal(255,3)
      }
      return this;
    }else{
    	console.error("input RGB(a) string is not valid");
    }
  }
  _parseNumber(inp){
    return this._parseHex(inp.toString(16));
  }

  parse(inp){
    if(typeof(inp) === "string"){
      if(inp.charAt(0,1) === '#' || inp.startsWith("0x")){
        return this._parseHex(inp);
      }else if(inp.startsWith("rgb")){
        return this._parseRGB(inp);
      }
    }else if(typeof(inp) === "number"){
      return this._parseNumber(inp);
    }
  }
  
  hex(alpha=true){
    var r = this.r.toString(16);
    var g = this.g.toString(16);
    var b = this.b.toString(16);
    var a = this.a.toString(16);

    if (r.length == 1)
      r = "0" + r;
    if (g.length == 1)
      g = "0" + g;
    if (b.length == 1)
      b = "0" + b;
    if (a.length == 1)
    	a = "0" + a;
  	return '#' + r + g + b + (alpha ? a : '');
  }
  rgb(alpha=false,asFloat=false){
  	if(alpha){
    	return "rgba(" + [this.r,this.g,this.b, asFloat ? (this.a/255) : this.a].join(',') + ")";
    }else{
    	return "rgb(" + [this.r,this.g,this.b].join(",") + ")";
    }
  }
  rgba(asFloat){
  	return this.rgb(true,!!asFloat);
  }
  dec(alpha=true){
    var hex = this.hex(alpha).replace('#','');
    return parseInt(hex,16);
  }
  toArray(alpha=false){
    var out = [this.r,this.g,this.b];
    if(alpha) out.push(this.a);
    return out;
  }
  clone(){
    return new Color().setVal(this.r,0).setVal(this.g,1).setVal(this.b,2).setVal(this.a,3);
  }
}
