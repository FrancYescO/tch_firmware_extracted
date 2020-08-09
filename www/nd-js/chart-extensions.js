/*
 * (C) 2017 NETDUMA Software
 * Luke Meppem <luke.meppem@netduma.com>
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
    var arcOpts = opts.elements.arc;
    var availableWidth = chartArea.right - chartArea.left - arcOpts.borderWidth;
    var availableHeight = chartArea.bottom - chartArea.top - arcOpts.borderWidth;
    var minSize = Math.min(availableWidth, availableHeight);
    var offset = { x: 0, y: 0 };
    var meta = me.getMeta();
    var cutoutPercentage = opts.cutoutPercentage;
    var circumference = opts.circumference;

    // If the chart's circumference isn't a full circle, calculate minSize as a ratio of the width/height of the arc
    if (circumference < Math.PI * 2.0) {
      var startAngle = opts.rotation % (Math.PI * 2.0);
      startAngle += Math.PI * 2.0 * (startAngle >= Math.PI ? -1 : startAngle < -Math.PI ? 1 : 0);
      var endAngle = startAngle + circumference;
      var start = { x: Math.cos(startAngle), y: Math.sin(startAngle) };
      var end = { x: Math.cos(endAngle), y: Math.sin(endAngle) };
      var contains0 = (startAngle <= 0 && endAngle >= 0) || (startAngle <= Math.PI * 2.0 && Math.PI * 2.0 <= endAngle);
      var contains90 = (startAngle <= Math.PI * 0.5 && Math.PI * 0.5 <= endAngle) || (startAngle <= Math.PI * 2.5 && Math.PI * 2.5 <= endAngle);
      var contains180 = (startAngle <= -Math.PI && -Math.PI <= endAngle) || (startAngle <= Math.PI && Math.PI <= endAngle);
      var contains270 = (startAngle <= -Math.PI * 0.5 && -Math.PI * 0.5 <= endAngle) || (startAngle <= Math.PI * 1.5 && Math.PI * 1.5 <= endAngle);
      var cutout = cutoutPercentage / 100.0;
      var min = { x: contains180 ? -1 : Math.min(start.x * (start.x < 0 ? 1 : cutout), end.x * (end.x < 0 ? 1 : cutout)), y: contains270 ? -1 : Math.min(start.y * (start.y < 0 ? 1 : cutout), end.y * (end.y < 0 ? 1 : cutout)) };
      var max = { x: contains0 ? 1 : Math.max(start.x * (start.x > 0 ? 1 : cutout), end.x * (end.x > 0 ? 1 : cutout)), y: contains90 ? 1 : Math.max(start.y * (start.y > 0 ? 1 : cutout), end.y * (end.y > 0 ? 1 : cutout)) };
      var size = { width: (max.x - min.x) * 0.5, height: (max.y - min.y) * 0.5 };
      minSize = Math.min(availableWidth / size.width, availableHeight / size.height);
      offset = { x: (max.x + min.x) * -0.5, y: (max.y + min.y) * -0.5 };
    }

    chart.borderWidth = me.getMaxBorderWidth(meta.data);
    chart.outerRadius = Math.max((minSize - chart.borderWidth) / 2, 0);
    chart.innerRadius = Math.max(cutoutPercentage ? (chart.outerRadius / 100) * (cutoutPercentage) : 0, 0);
    chart.radiusLength = (chart.outerRadius - chart.innerRadius) / chart.getVisibleDatasetCount();
    chart.offsetX = offset.x * chart.outerRadius;
    chart.offsetY = offset.y * chart.outerRadius;

    meta.total = me.calculateTotal();

    me.outerRadius = chart.outerRadius - (chart.radiusLength * me.getRingIndex(me.index));
    me.innerRadius = Math.max(me.outerRadius - chart.radiusLength, 0);

    /// ADDED THIS SECTION
    if (me.index > 0) {
      me.outerRadius -= opts.datasetRadiusBuffer;
      me.innerRadius -= opts.datasetRadiusBuffer;
    }
    /// END SECTION

    helpers.each(meta.data, function (arc, index) {
      me.updateElement(arc, index, reset);
    });
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
//#endregion



//#region Force Tooltips

/// Force tooltips to show constantly ///
/**
 * datasets = {
 *  data: [a,b,c,d],
 *  forceTooltips: true | [true,true,false,true]
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
          if(dataset.forceTooltips === true || dataset.forceTooltips[j] === true){
            chart.pluginTooltips.push(new Chart.Tooltip({
                _chart: chart.chart,
                _chartInstance: chart,
                _data: chart.data,
                _options: chart.options.tooltips,
                _active: [sector]
            }, chart));
          }
        });
      }
    });
  },
  afterDraw: function (chart, easing) {
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
