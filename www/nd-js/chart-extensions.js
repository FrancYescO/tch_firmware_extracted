/*
 * (C) 2017 NETDUMA Software
 * Luke Meppem
*/


var helpers = Chart.helpers;

var valueOrDefault = helpers.valueOrDefault;

var PI = Math.PI;
var DOUBLE_PI = PI * 2;
var HALF_PI = PI / 2;




//#region Doughnut Gaps

/// Gaps between doughnut datasets ///
/**
 * {
 *  type="doughnut",
 *  datasetRadiusBuffer: 10
 * }
 */

// this option will control the white space between embedded charts when there is more than 1 dataset
helpers.extend(Chart.defaults.doughnut, {
  datasetRadiusBuffer: 0
});

Chart.controllers.doughnut = Chart.controllers.doughnut.extend({
  update: function (reset) {
    var me = this;
		var chart = me.chart;
		var chartArea = chart.chartArea;
		var opts = chart.options;
		var ratioX = 1;
		var ratioY = 1;
		var offsetX = 0;
		var offsetY = 0;
		var meta = me.getMeta();
		var arcs = meta.data;
		var cutout = opts.cutoutPercentage / 100 || 0;
		var circumference = opts.circumference;
		var chartWeight = me._getRingWeight(me.index);
		var maxWidth, maxHeight, i, ilen;

		// If the chart's circumference isn't a full circle, calculate size as a ratio of the width/height of the arc
		if (circumference < DOUBLE_PI) {
			var startAngle = opts.rotation % DOUBLE_PI;
			startAngle += startAngle >= PI ? -DOUBLE_PI : startAngle < -PI ? DOUBLE_PI : 0;
			var endAngle = startAngle + circumference;
			var startX = Math.cos(startAngle);
			var startY = Math.sin(startAngle);
			var endX = Math.cos(endAngle);
			var endY = Math.sin(endAngle);
			var contains0 = (startAngle <= 0 && endAngle >= 0) || endAngle >= DOUBLE_PI;
			var contains90 = (startAngle <= HALF_PI && endAngle >= HALF_PI) || endAngle >= DOUBLE_PI + HALF_PI;
			var contains180 = startAngle === -PI || endAngle >= PI;
			var contains270 = (startAngle <= -HALF_PI && endAngle >= -HALF_PI) || endAngle >= PI + HALF_PI;
			var minX = contains180 ? -1 : Math.min(startX, startX * cutout, endX, endX * cutout);
			var minY = contains270 ? -1 : Math.min(startY, startY * cutout, endY, endY * cutout);
			var maxX = contains0 ? 1 : Math.max(startX, startX * cutout, endX, endX * cutout);
			var maxY = contains90 ? 1 : Math.max(startY, startY * cutout, endY, endY * cutout);
			ratioX = (maxX - minX) / 2;
			ratioY = (maxY - minY) / 2;
			offsetX = -(maxX + minX) / 2;
			offsetY = -(maxY + minY) / 2;
		}

		for (i = 0, ilen = arcs.length; i < ilen; ++i) {
			arcs[i]._options = me._resolveDataElementOptions(arcs[i], i);
		}

		chart.borderWidth = me.getMaxBorderWidth();
		maxWidth = (chartArea.right - chartArea.left - chart.borderWidth) / ratioX;
		maxHeight = (chartArea.bottom - chartArea.top - chart.borderWidth) / ratioY;
		chart.outerRadius = Math.max(Math.min(maxWidth, maxHeight) / 2, 0);
		chart.innerRadius = Math.max(chart.outerRadius * cutout, 0);
		chart.radiusLength = (chart.outerRadius - chart.innerRadius) / (me._getVisibleDatasetWeightTotal() || 1);
		chart.offsetX = offsetX * chart.outerRadius;
		chart.offsetY = offsetY * chart.outerRadius;

		meta.total = me.calculateTotal();

		me.outerRadius = chart.outerRadius - chart.radiusLength * me._getRingWeightOffset(me.index);
		me.innerRadius = Math.max(me.outerRadius - chart.radiusLength * chartWeight, 0);

    /// ADDED THIS SECTION
    if (me.index > 0) {
      me.outerRadius -= opts.datasetRadiusBuffer;
      me.innerRadius -= opts.datasetRadiusBuffer;
    }
    /// END SECTION

		for (i = 0, ilen = arcs.length; i < ilen; ++i) {
			me.updateElement(arcs[i], i, reset);
		}
  }
});

//#endregion




//#region Triangles

/// Triangular bar charts ///
/**
 * elements: {
 *  rectangle: {
 *    traingles: true
 *  }
 * }
 */
/*
helpers.extend(Chart.defaults.global.elements.rectangle, {
  triangles: false
})
Chart.elements.Rectangle.prototype.draw = function () {
  var ctx = this._chart.ctx;
  var vm = this._view;
  var left, right, top, bottom, signX, signY, borderSkipped;
  var borderWidth = vm.borderWidth;

  if (!vm.horizontal) {
    // bar
    left = vm.x - vm.width / 2;
    right = vm.x + vm.width / 2;
    top = vm.y;
    bottom = vm.base;
    signX = 1;
    signY = bottom > top ? 1 : -1;
    borderSkipped = vm.borderSkipped || 'bottom';
  } else {
    // horizontal bar
    left = vm.base;
    right = vm.x;
    top = vm.y - vm.height / 2;
    bottom = vm.y + vm.height / 2;
    signX = right > left ? 1 : -1;
    signY = 1;
    borderSkipped = vm.borderSkipped || 'left';
  }

  // Canvas doesn't allow us to stroke inside the width so we can
  // adjust the sizes to fit if we're setting a stroke on the line
  if (borderWidth) {
    // borderWidth shold be less than bar width and bar height.
    var barSize = Math.min(Math.abs(left - right), Math.abs(top - bottom));
    borderWidth = borderWidth > barSize ? barSize : borderWidth;
    var halfStroke = borderWidth / 2;
    // Adjust borderWidth when bar top position is near vm.base(zero).
    var borderLeft = left + (borderSkipped !== 'left' ? halfStroke * signX : 0);
    var borderRight = right + (borderSkipped !== 'right' ? -halfStroke * signX : 0);
    var borderTop = top + (borderSkipped !== 'top' ? halfStroke * signY : 0);
    var borderBottom = bottom + (borderSkipped !== 'bottom' ? -halfStroke * signY : 0);
    // not become a vertical line?
    if (borderLeft !== borderRight) {
      top = borderTop;
      bottom = borderBottom;
    }
    // not become a horizontal line?
    if (borderTop !== borderBottom) {
      left = borderLeft;
      right = borderRight;
    }
  }

  ctx.beginPath();
  ctx.fillStyle = vm.backgroundColor;
  ctx.strokeStyle = vm.borderColor;
  ctx.lineWidth = borderWidth;

  // Corner points, from bottom-left to bottom-right clockwise
  // | 1 2 |
  // | 0 3 |
  var corners = [
    [left, bottom],
    [left, top],
    [right, top],
    [right, bottom]
  ];

  /// ADDED THIS SECTION
  if (vm.triangles) {
    if (!vm.horizontal) {
      //Vertical
      var centerTop = (left + right) / 2;
      corners[1] = [centerTop, top];
      corners[2] = [centerTop, top];
    } else {
      //Horizontal
      var centerRight = (top + bottom) / 2;
      corners[2] = [right, centerRight];
      corners[3] = [right, centerRight];
    }
  }
  /// END ADDED

  // Find first (starting) corner with fallback to 'bottom'
  var borders = ['bottom', 'left', 'top', 'right'];
  var startCorner = borders.indexOf(borderSkipped, 0);
  if (startCorner === -1) {
    startCorner = 0;
  }

  function cornerAt(index) {
    return corners[(startCorner + index) % 4];
  }

  // Draw rectangle from 'startCorner'
  var corner = cornerAt(0);
  ctx.moveTo(corner[0], corner[1]);

  for (var i = 1; i < 4; i++) {
    corner = cornerAt(i);
    ctx.lineTo(corner[0], corner[1]);
  }

  ctx.fill();
  if (borderWidth) {
    ctx.stroke();
  }
}
Chart.controllers.bar = Chart.controllers.bar.extend({
  updateElement: function (rectangle, index, reset) {
    var me = this;
    var chart = me.chart;
    var meta = me.getMeta();
    var dataset = me.getDataset();
    var custom = rectangle.custom || {};
    var rectangleOptions = chart.options.elements.rectangle;

    rectangle._xScale = me.getScaleForId(meta.xAxisID);
    rectangle._yScale = me.getScaleForId(meta.yAxisID);
    rectangle._datasetIndex = me.index;
    rectangle._index = index;

    rectangle._model = {
      datasetLabel: dataset.label,
      label: chart.data.labels[index],
      borderSkipped: custom.borderSkipped ? custom.borderSkipped : rectangleOptions.borderSkipped,
      backgroundColor: custom.backgroundColor ? custom.backgroundColor : helpers.valueAtIndexOrDefault(dataset.backgroundColor, index, rectangleOptions.backgroundColor),
      borderColor: custom.borderColor ? custom.borderColor : helpers.valueAtIndexOrDefault(dataset.borderColor, index, rectangleOptions.borderColor),
      borderWidth: custom.borderWidth ? custom.borderWidth : helpers.valueAtIndexOrDefault(dataset.borderWidth, index, rectangleOptions.borderWidth),
      triangles: custom.triangles ? custom.triangles : helpers.valueAtIndexOrDefault(dataset.triangles, index, rectangleOptions.triangles) /// ADDED THIS LINE
    };

    me.updateElementGeometry(rectangle, index, reset);

    rectangle.pivot();
  },
})
*/
//#endregion



//#region Force Tooltips

/// Force tooltips to show constantly ///
/**
 * datasets = {
 *  data: [a,b,c,d],
 *  forceTooltips: true | [true,true,false,true] | 'first' | 'last' | function()
 *  forceTooltipsOptions: {} // Any options here will override the options. Same as tooltip options.
 * }
 */
 
Chart.plugins.register({
  beforeRender: function (chart) {
    // create an array of tooltips
    // we can't use the chart tooltip because there is only one tooltip per chart
    chart.pluginTooltips = [];
    chart.config.data.datasets.forEach(function (dataset, i) {
      if(dataset.forceTooltips){
        chart.getDatasetMeta(i).data.forEach(function (sector, j) {
          if(dataset.forceTooltips === true //if it's true, do for all
            || (Array.isArray(dataset.forceTooltips) && dataset.forceTooltips[j] === true) //if it's an array and true at the index
            || (typeof dataset.forceTooltips === "string" && (
              (dataset.forceTooltips.toLowerCase() === "first" && j === 0) //if it's "last", and the index is the first
              || (dataset.forceTooltips.toLowerCase() === "last" && j === dataset.data.length) //if it's "last", and the index is the last
              || (dataset.forceTooltips.toLowerCase() === "minmax" && dataset.data[j].minMax)
            ))
            || (typeof dataset.forceTooltips === "function" && dataset.forceTooltips.call(this,sector,{datasetIndex: i, index: j},chart.config.data.datasets)) //if it's a function, and the functions returns truthy
            ){
              var options = Object.assign({},chart.options.tooltips);
              if(dataset.forceTooltipsOptions) Object.assign(options,dataset.forceTooltipsOptions);
            chart.pluginTooltips.push(new Chart.Tooltip({
                _chart: chart.chart,
                _chartInstance: chart,
                _data: chart.data,
                _options: options,
                _active: [sector]
            }, chart));
          }
        });
      }
    });
  },
  afterDatasetsDraw: function (chart, easing) {
    if (chart.pluginTooltips) {
      Chart.helpers.each(chart.pluginTooltips, function (tooltip) {
        tooltip.initialize();
        tooltip.update();
        // we don't actually need this since we are not animating tooltips
        tooltip.pivot();
        tooltip.transition(easing).draw();
      });
    }
  }
});
//#endregion



//#region Highest and Lowest points

/// The radius of the highest and lowest points will be the only ones visible ///
/**
 * Can go in datasets or in options.elements.point
 * {
 *  minMax: {
 *    radius: 4 //any options specified in the options.elements.point, use the same name to override. Name must be options version, not dataset version for both (radius not pointRadius)
 *  }
 * }
 */

Chart.plugins.register({
  beforeUpdate: function(chart){
    var initPrefix = "init_";
    var globalPointToDatasetTranslation = {
      radius: "pointRadius",
      pointStyle: "pointStyle",
      rotation: "pointRotation",
      backgroundColor: "pointBackgroundColor",
      borderWidth: "pointBorderWidth",
      borderColor: "pointBorderColor",
      hitRadius: "pointHitRadius",
      hoverRadius: "pointHoverRadius",
      hoverBorderWidth: "pointHoverBorderWidth"
    }
    var globalPoint = chart.config.options.elements.point;
    var globalMinMax = globalPoint.minMax || {};
    chart.config.data.datasets.forEach(function (dataset, i) {
      var pointKeys = Object.keys(globalPoint);
      var datasetMinMax = dataset.minMax || {};
      var hasValSet = !!((Object.keys(datasetMinMax).length || Object.keys(globalMinMax).length)); 
      if(hasValSet){
        var newMeta = {};
        var setInit = function(key){
          var valInit = dataset.__metaDoMinMaxPoints ? dataset.__metaDoMinMaxPoints[initPrefix + key] : null;
          if(valInit === null){
            var datasetKey = globalPointToDatasetTranslation[key];
            valInit = (typeof dataset[datasetKey] !== "undefined") ? dataset[datasetKey] : globalPoint[key];
          }
          newMeta[initPrefix + key] = valInit;
        }
        for(var k = 0; k < pointKeys.length; k ++){
          setInit(pointKeys[k]);
        }
        dataset.__metaDoMinMaxPoints = newMeta;
      }
      
      if(dataset.__metaDoMinMaxPoints){
        if(!hasValSet){
          // delete dataset.__metaDoMinMaxPoints;
          return;
        }


        var data = dataset.data;
        var min = null;
        var max = null;
        for(var i = 0; i < data.length; i ++){
          var d = data[i];
          if(d.minMax) delete d.minMax;
          if(min === null || d.y < data[min].y) min = i;
          if(max === null || d.y >= data[max].y) max = i;
        }
        if(min !== null)
          data[min].minMax = "min";
        if(max !== null)
          data[max].minMax = "max";

        var doMinMaxArray = function(key){
          var customVal = typeof datasetMinMax[key] !== "undefined" ? datasetMinMax[key] : globalMinMax[key];
          if(typeof customVal !== "undefined" && customVal !== null){
            var arrName = globalPointToDatasetTranslation[key];
            var arr = Array.isArray(dataset[arrName]) ? dataset[arrName] : [];
            arr.length = data.length + 1;
            var init = dataset.__metaDoMinMaxPoints[initPrefix + key];
            if(Array.isArray(init)){
              arr.map(function(v,index){return init[index];})
            }else{
              arr.fill(init);
            }
            if(min !== null) arr[min] = customVal;
            if(max !== null) arr[max] = customVal;
            dataset[arrName] = arr;
          }
        }
        for(var k = 0; k < pointKeys.length; k ++){
          doMinMaxArray(pointKeys[k])
        }
      }
    });
  }
});
//#endregion
