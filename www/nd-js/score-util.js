/**
 * (C) Luke Meppem - NetDuma
 * Utility for ping and data
 */

<% local json = require "json" %>

function lerpColour(a,b,amount){
    var ar = a >> 16,
      ag = a >> 8 & 0xff,
      ab = a & 0xff,

      br = b >> 16,
      bg = b >> 8 & 0xff,
      bb = b & 0xff,

      rr = ar + amount * (br - ar),
      rg = ag + amount * (bg - ag),
      rb = ab + amount * (bb - ab);

    //var decColour = (rr << 16) + (rg << 8) + (rb | 0);
    return `rgb(${rr},${rg},${rb})`;
}

var scoreUtil = scoreUtil || {};
(function(){
  var colours = [
    "<%= theme.RATING_APLUS %>",
    "<%= theme.RATING_A %>",
    "<%= theme.RATING_B %>",
    "<%= theme.RATING_C %>",
    "<%= theme.RATING_D %>"
  ];
  if(!colours || colours.length !== 5){
    console.error("SCORE_COLOURS is incorrect length, using default colours")
    colours = [0x00ff00,0x99ff00,0xffff00,0xff7700,0xff0000];
  }
  for(var i = 0; i < colours.length; i++){
    colours[i] = new Color(colours[i]);
  }
  var scores = [
    ['A+',colours[0],15],
    ['A',colours[1],25],
    ['B',colours[2],40],
    ['C',colours[3],70],
    ['D',colours[4],200]
  ];
  this.getPingColour = function(ping){
    var lerpColours = new Array(2).fill(colours[colours.length-1])
    var max = scores[scores.length-1][2];
    var min = max;
    if(ping <= max){
      for(var i = 0; i < scores.length; i++){
        var p = scores[i];
        if(ping > p[2]) { continue; }
        var a = b = i;
        if(i !== 0) a--;
        lerpColours = [scores[a][1],scores[b][1]];
        min = i === 0 ? 0 : scores[a][2];
        max = scores[b][2];
        break;
      }
    }
    var amount = (ping - min) / Math.max(max - min,1);
    return lerpColour(lerpColours[0].dec(false), lerpColours[1].dec(false), amount);
  }
  this.getPingScore = function(ping){
    for(var i = 0; i < scores.length; i++){
      if(ping > scores[i][2]) continue;
      return scores[i][0];
    }
    return scores[scores.length - 1][0];
  },
  this.getPingData = function(ping){
    return {
      ping: ping,
      score: this.getPingScore(ping),
      colour: this.getPingColour(ping)
    }
  }
  this.generateLegend = function(element){
    var ul = $("<ul></ul>");
    var li_s = "<li><span></span></li>";

    for(var k in scores){
      var s = scores[k];
      var li = $(li_s);
      var span = li.find("span");
      var col = this.getPingColour(s[2]);
      span.css("background-color", col);
      li.append(s[0]);
      ul.append(li);
    }
    $(element).append(ul);
    return ul;
  }
  this.getScoreData = function(score,origMin,origMax){
    var min = origMin;
    var max = origMax;
    var lerpColours = new Array(2).fill(colours[colours.length-1]);
    var diff = max - min;
    var steps = diff / scores.length;
    var letter = scores[scores.length-1][0];
    if(score < max){
      for(var i = 0; i < scores.length; i ++){
        var a,b = i;
        if(i !== 0) a--;
        var bounds = [Math.floor(a * steps),Math.round(b * steps)];
        if(bounds[0] <= score && score <= bounds[1]){
          min = bounds[0];
          max = bounds[1];
          lerpColours[0] = colours[a];
          lerpColours[1] = colours[b];
          letter = scores[b][0];
          break;
        }
      }
    }
    var amount = (score - min) / Math.max(max - min, 1);
    return {
      score: score,
      min: origMin,
      max: origMax,
      colour: lerpColour(lerpColours[0].dec(false),lerpColours[1].dec(false),amount),
      score: letter
    }
  }
}).call(scoreUtil);
