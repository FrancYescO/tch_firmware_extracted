--pretranslated: do not change this file
 

gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local params = utils.get_params()

local ltedoctor_sections = {
	{
		title = T"Status",
		id = "status",
		params = {
			{
				name = "nas_state",
				desc = T"Network Status",
				translations = {
					registered = utils.nas_state_map["registered"],
					not_registered = utils.nas_state_map["not_registered"],
					not_registered_searching = utils.nas_state_map["not_registered_searching"],
					registration_denied = utils.nas_state_map["registration_denied"]
				}
			},
			{
				name = "service_state",
				desc = T"Service Status",
				translations = {
					no_service = utils.nas_state_map["no_service"],
					limited_regional_service = utils.service_state_map["limited_regional_service"],
					limited_service = utils.service_state_map["limited_service"],
					normal_service = utils.service_state_map["normal_service"],
					sleeping = utils.service_state_map["sleeping"]
				}
			}
		}
	},
	{
		title = T"Signal Quality",
		id = "signal_quality",
		params = {
			{ name = "rssi", desc = T"RSSI", unit = "dBm" },
			{ name = "rsrp", desc = T"RSRP", unit = "dBm" },
			{ name = "rsrq", desc = T"RSRQ", unit = "dB" },
			{ name = "snr", desc = T"SNR", unit = "dB" },
			{ name = "sinr", desc = T"SINR", unit = "dB" },
			{ name = "cinr", desc = T"CINR", unit = "dB" },
			{ name = "path_loss", desc = T"Path Loss", unit = "dB" },
			{ name = "tx_power", desc = T"TX Power", unit = "dBm" },
			{ name = "ecio", desc = T"ECIO", unit = "dB" },
			{ name = "rscp", desc = T"RSCP", unit = "dBm" }
		}
	},
	{
		title = T"Operator Info",
		id = "operator_info",
		params = {
			{ name = "network_desc", desc = T"Operator" },
			{ name = "mcc", desc = T"MCC" },
			{ name = "mnc", desc = T"MNC" }
		}
	},
	{
		title = T"Cell Info",
		id = "cell_info",
		params = {
			{ name = "cell_id", desc = T"Cell ID" },
			{ name = "phy_cell_id", desc = T"Physical Cell ID" },
			{
				name = "radio_interface",
				desc = T"Access Technology",
				translations = {
					no_service = utils.radio_interface_map["no_service"],
					lte = utils.radio_interface_map["lte"],
					umts = utils.radio_interface_map["umts"],
					gsm = utils.radio_interface_map["gsm"],
					cdma = utils.radio_interface_map["cdma"],
				}
			},
			{ name = "radio_bearer_type", desc = T"Radio Bearer" },
			{ name = "tracking_area_code", desc = T"Tracking Area Code" },
			{
				name = "rrc_state",
				desc = T"RRC State",
				translations = {
					idle = utils.rrc_state_map["idle"],
					connected = utils.rrc_state_map["connected"]
				}
			},
			{ name = "dl_earfcn", desc = T"Downlink EARFCN" },
			{ name = "dl_arfcn", desc = T"Downlink ARFCN" },
			{ name = "dl_uarfcn", desc = T"Downlink UARFCN" },
			{ name = "ul_earfcn", desc = T"Uplink EARFCN" },
			{ name = "ul_arfcn", desc = T"Uplink ARFCN" },
			{ name = "ul_uarfcn", desc = T"Uplink UARFCN" },
			{ name = "lte_band", desc = T"Active Band" },
			{ name = "lte_dl_freq", desc = T"Downlink Frequency", unit = "MHz" },
			{ name = "lte_ul_freq", desc = T"Uplink Frequency", unit = "MHz" },
			{ name = "lte_ul_bandwidth", desc = T"Uplink Bandwidth", unit = "MHz" },
			{ name = "lte_dl_bandwidth", desc = T"Downlink Bandwidth", unit = "MHz" }
		}
	}
}

local ltedoctor_optional_sections = {
	additional_carriers = {
		title = T"Carrier Aggregation",
		id = 'additional_carrier',
		class = 'additional_carrier',
		params = {
			{ name = "rssi", desc = T"RSSI", unit = "dBm" },
			{ name = "rsrp", desc = T"RSRP", unit = "dBm" },
			{ name = "rsrq", desc = T"RSRQ", unit = "dB" },
			{ name = "sinr", desc = T"SINR", unit = "dB" },
			{ name = "phy_cell_id", desc = T"Physical Cell ID"},
			{ name = "lte_band", desc = T"Active Band" },
			{ name = "dl_earfcn", desc = T"Downlink EARFCN" }
		}
	}
}

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. string.format("%s", uri:match("/([^/]+)%.lp")) }

local no_signal = {
	alert = {
		class = "alert-info",
		id = "no-signal-results",
		style = "margin-top: 10px;"
	}
}
  ngx.print('\
\
<link href="/css/mobiled.css" rel="stylesheet">\
<script language="javascript" type="text/javascript" src="js/flot-min.js"></script>\
\
');  ngx.print( ui_helper.createHeader(params.modal_title, false, true, nil, help_link)); ngx.print('\
<div class="modal-body update" id="lte-doctor-body" style="min-height: 400px; min-width: 300px;">\
	<form class="form-horizontal" method="post" action="modals/lte-doctor.lp">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")
			local mobiled = {
				num_devices = "rpc.mobiled.DeviceNumberOfEntries"
			}
			content_helper.getExactContent(mobiled)
			mobiled.num_devices = tonumber(mobiled.num_devices)
			if not mobiled.num_devices or mobiled.num_devices == 0 then
				ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
				ngx.print("</form></div>")
				ngx.print(ui_helper.createFooter())
				ngx.exit(ngx.HTTP_OK)
			end
		  ngx.print('\
		<div id="waiting" class="loading"></div>\
		<div class=\'row-fluid\' style=\'visibility: hidden;\'>\
			<div class="span12" id="plot-container">\
				<select id="plot-period" class="no-save">\
					<option value="last_five_minutes" selected>');  ngx.print( T"Last five minutes" ); ngx.print('</option>\
					<option value="last_twenty_minutes">');  ngx.print( T"Last twenty minutes" ); ngx.print('</option>\
					<option value="last_hour">');  ngx.print( T"Last hour" ); ngx.print('</option>\
				</select>\
				');  ngx.print( ui_helper.createAlertBlock(T"No signal quality history available for the selected period", no_signal) ); ngx.print('\
				<div id="plot-container-inner">\
					<div id="signal-strength-indicator">\
						<div class="bar bar1"></div>\
						<div class="bar bar2"></div>\
						<div class="bar bar3"></div>\
						<div class="bar bar4"></div>\
						<div class="bar bar5"></div>\
					</div>\
					<div id="plot-tooltip"></div>\
					<div id="plot" style="height: 300px; width: 100%; clear:both;"></div>\
					<div id="plot-legend"></div>\
				</div>\
			</div>\
		</div>\
		<div class=\'row-fluid\' style=\'visibility: hidden;\'>\
				<div id="parameters-container">\
					<div id="lte-doctor-values" class="hidden"></div>\
				</div>\
			</div>\
		</div>\
	</form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
	var LteDoctor = function () {\
		this.observables = {};\
		this.refreshRate = 6;\
		this.plotMinValue = -150;\
		this.sections = ');  ngx.print( json.encode(ltedoctor_sections) ); ngx.print(';\
		this.optionalSections = ');  ngx.print( json.encode(ltedoctor_optional_sections) ); ngx.print(';\
		this.plotData = {\
			rssi : {\
				label: "RSSI (dBm)",\
				color: "#07a9f0",\
				data: []\
			},\
			rsrq : {\
				label: "RSRQ (dB)",\
				color: "#8904B1",\
				data: []\
			},\
			rsrp : {\
				label: "RSRP (dBm)",\
				color: "#4C0B5F",\
				data: []\
			},\
			rscp : {\
				label: "RSCP (dBm)",\
				color: "#7FFF00",\
				data: []\
			}\
		};\
		this.period_seconds = 0;\
		this.removeOldData = function(uptime) {\
			var i;\
			for (var key in this.plotData) {\
				i = this.plotData[key].data.length;\
				while (i--) {\
					if(parseInt(this.plotData[key].data[i].uptime) < uptime) {\
						this.plotData[key].data.splice(i, 1);\
					}\
				}\
			}\
		};\
		this.getData = function(period) {\
			var params = [{ name: "data_period", value: period },\
						  tch.elementCSRFtoken()];\
			if(this.since_uptime !== undefined) {\
				params.push({ name: "since_uptime", value: this.since_uptime });\
			}\
\
			var self = this;\
			$.post("/ajax/radioparameters.lua", params, function(data) {\
				if (data !== null && typeof data === \'object\') {\
					self.period_seconds = parseInt(data.history.period_seconds);\
					var starting_uptime = parseInt(data.history.starting_uptime);\
					if (!isNaN(starting_uptime)) {\
						self.removeOldData(starting_uptime);\
					}\
					for (var i = 0; i < data.history.data.length; i++) {\
						var line = data.history.data[i];\
						for (var key in self.plotData) {\
							var val = line[key];\
							if(val !== "") {\
								self.plotData[key].data.push({uptime: parseInt(line.uptime), value: val});\
							}\
						}\
					}\
\
					self.updateParameters(data.current);\
\
					var fullRefresh = false;\
					if (self.since_uptime === undefined) {\
						fullRefresh = true;\
					}\
					self.since_uptime = parseInt(data.history.current_uptime);\
					var plotData = self.getPlotData();\
\
					if (plotData.length == 0) {\
						$("#plot-container-inner").hide();\
					}\
\
					if (fullRefresh) {\
						var axes = self.plot.getAxes();\
						var ticks = [];\
						var suffix;\
						var divider;\
						if (self.period_seconds <= 300) {\
							suffix = "s";\
							divider = 1;\
						} else if (self.period_seconds <= 3600) {\
							suffix = "m";\
							divider = 60;\
						} else {\
							suffix = "h";\
							divider = 3600;\
						}\
\
						var length = self.period_seconds/divider;\
						var increment = length/10;\
						var j = 0;\
						for(var i = 0; i < self.period_seconds; i += increment*divider) {\
							if(i === 0) {\
								ticks.push([self.period_seconds, "Now"]);\
							} else {\
								var val = (j*increment) | 0;\
								ticks.push([self.period_seconds-i, "-"+val+suffix]);\
							}\
							j++;\
						}\
\
						axes.xaxis.options.ticks = ticks;\
						axes.xaxis.options.max = self.period_seconds;\
						axes.xaxis.options.zoomRange = [self.refreshRate, self.period_seconds];\
						axes.xaxis.options.panRange = [self.refreshRate, self.period_seconds];\
						// Redraw\
						self.plot.setData(plotData);\
						self.plot.setupGrid();\
						self.plot.draw();\
						self.plot.zoomOut();\
						$(".loading").hide();\
						$(".row-fluid").css("visibility", "");\
					} else {\
						self.plot.setData(plotData);\
						self.plot.draw();\
					}\
					if (plotData.length > 0) {\
						$("#no-signal-results").hide();\
						$("#plot-container-inner").show();\
					} else {\
						$("#no-signal-results").show();\
					}\
				}\
				self.timer = setTimeout(function () { self.refreshParameters(); }, self.refreshRate*1000);\
			}, "json");\
		};\
		this.getPlotData = function() {\
			var plotData = [];\
			for (var key in this.plotData) {\
				var res = [];\
				var length = this.plotData[key].data.length;\
				if (length) {\
					function dynamicSort(property) {\
						var sortOrder = 1;\
						if(property[0] === "-") {\
							sortOrder = -1;\
							property = property.substr(1);\
						}\
						return function (a,b) {\
							var result = (a[property] < b[property]) ? -1 : (a[property] > b[property]) ? 1 : 0;\
							return result * sortOrder;\
						}\
					}\
					this.plotData[key].data.sort(dynamicSort("uptime"));\
					for (var i = 0; i < length; i++) {\
						res.push([this.period_seconds - (this.since_uptime - this.plotData[key].data[i].uptime), this.plotData[key].data[i].value]);\
					}\
					plotData.push({ data : res, label : this.plotData[key].label, color : this.plotData[key].color });\
				}\
			}\
			return plotData;\
		};\
		this.setBars = function(bars) {\
			$(\'#signal-strength-indicator\').children(\'.bar\').each(function (index, item) {\
				if(index < bars) {\
					$(this).addClass(\'bar-active\');\
				} else {\
					$(this).removeClass(\'bar-active\');\
				}\
			});\
		};\
		this.getTranslation = function(param, value) {\
			for (var k in this.sections) {\
				var section = this.sections[k];\
				for (var i in section.params) {\
					var p = section.params[i];\
					if (p.name == param && typeof p.translations != \'undefined\') {\
						return p.translations[value];\
					}\
				}\
			}\
		};\
		this.updateParameters = function(data) {\
			$(\'#lte-doctor-values\').removeClass(\'hidden\');\
\
			for (var key in data) {\
				if(key == "bars") {\
					this.setBars(data[key]);\
				} else if (typeof this.observables[key] != \'undefined\') {\
					var translation = this.getTranslation(key, data[key]);\
					if (translation != undefined) {\
						this.observables[key](translation);\
					} else {\
						this.observables[key](data[key]);\
					}\
				}\
			}\
\
			var self = this;\
			if(data.additional_carriers !== undefined && data.additional_carriers.length > 0) {\
				var section = self.optionalSections.additional_carriers;\
				$.each(data.additional_carriers, function(key, carrier) {\
					if($(\'#\' + section.id + key).length == 0) {\
						var html = \'<div id="\' + section.id + key + \'" class="additional_carrier">\';\
						html += \'<h4 class="sigval-title">\' + section.title + \'</h4>\';\
						for (var k in section.params) {\
							var param = section.params[k];\
							var name = \'carrier\' + key + \'_\' + param.name;\
							self.observables[name] = ko.observable("");\
							var bind = name;\
							if (param.unit != undefined) {\
								self.observables[name + \'_full\'] = function(param, unit) {\
									return self.observables[param]() + " " + unit;\
								};\
								bind += "_full(\'"+name+ "\',\'"+param.unit+"\')";\
							}\
							html += \'<div data-bind="visible: observables.\' + name + \'().length > 0" class="control-group">\';\
							html += \'<label class="control-label">\' + param.desc + \'</label>\';\
							html += \'<div class="controls">\';\
							html += \'<span class="simple-desc span5" data-bind="text: observables.\' + bind + \'"></span>\';\
							html += \'</div></div>\';\
						}\
						html += \'</div>\';\
						$( ".span6" ).last().append(html);\
						var elem = document.getElementById(\'lte-doctor-values\');\
						ko.cleanNode(elem);\
						ko.applyBindings(self, elem);\
					}\
					for (var val in carrier) {\
						var name = \'carrier\' + key + \'_\' + val;\
						if (typeof self.observables[name] != \'undefined\') {\
							self.observables[name](carrier[val]);\
						}\
					}\
				});\
			} else {\
				$(\'.additional_carrier\').remove();\
			}\
		};\
		this.shouldBeVisible = function(name) {\
			var self = this;\
			var visible = false;\
			$.each(this.sections, function(key, section) {\
				if(section.id == name) {\
					for (var k in section.params) {\
						var params = section.params[k];\
						if(self.observables[params.name]() != "") {\
							visible = true;\
							return;\
						}\
					}\
				}\
			});\
			return visible;\
		};\
		this.refresh = function() {\
			clearTimeout(this.timer);\
			delete this.since_uptime;\
			for (var key in this.plotData) {\
				this.plotData[key].data = [];\
			}\
			this.refreshParameters();\
		};\
		this.refreshParameters = function() {\
			this.getData($(\'#plot-period\').val());\
		};\
		this.addPanArrow = function(dir, right, top, offset, placeholder) {\
			var self = this;\
			$("<img class=\'navbutton\' src=\'/img/arrow-" + dir + ".gif\' style=\'right:" + right + "px;top:" + top + "px\'>")\
			.appendTo(placeholder)\
			.click(function (e) {\
				e.preventDefault();\
				self.plot.pan(offset);\
			});\
		};\
		this.addZoomArrow = function(dir, right, top, placeholder) {\
			var self = this;\
			$("<img class=\'navbutton\' src=\'/img/arrow-" + dir + ".gif\' style=\'right:" + right + "px;top:" + top + "px\'>")\
			.appendTo(placeholder)\
			.click(function (e) {\
				e.preventDefault();\
				if (dir == "up") {\
					self.plot.zoom(100);\
				} else if (dir == "down") {\
					self.plot.zoomOut();\
				}\
			});\
		};\
		this.init = function() {\
			var self = this;\
			var html = \'<div class="span6">\';\
			var split = Math.floor(this.sections.length/2);\
			$.each(this.sections, function(key, section) {\
					html += \'<div id="\' + section.id + \'" data-bind="visible: shouldBeVisible(\\\'\'+ section.id + \'\\\')">\';\
					html += \'<h4 class="sigval-title">\' + section.title + \'</h4>\';\
					for (var k in section.params) {\
						var param = section.params[k];\
						self.observables[param.name] = ko.observable("");\
						var bind = param.name;\
						if (param.unit != undefined) {\
							self.observables[param.name + \'_full\'] = function(param, unit) {\
								return self.observables[param]() + " " + unit;\
							};\
							bind += "_full(\'"+param.name+ "\',\'"+param.unit+"\')";\
						}\
						html += \'<div data-bind="visible: observables.\' + param.name + \'().length > 0" class="control-group">\';\
						html += \'<label class="control-label">\' + param.desc + \'</label>\';\
						html += \'<div class="controls">\';\
						html += \'<span class="simple-desc span5" data-bind="text: observables.\' + bind + \'"></span>\';\
						html += \'</div></div>\';\
					}\
					html += \'</div>\';\
					if (key % split == 0 && key != 0) {\
						html += \'</div><div class="span6">\';\
					}\
			});\
			$(\'#lte-doctor-values\').append(html);\
\
			var placeholder = $("#plot");\
			this.plot = $.plot(placeholder, this.getPlotData(), {\
				series: {\
					shadowSize: 0,\
					lines: {\
						show: true\
					},\
					points: {\
						show: true\
					}\
				},\
				legend: {\
					noColumns: 0,\
					container: $("#plot-legend")\
				},\
				grid: { hoverable: true, clickable: true },\
				yaxis: {\
					min: this.plotMinValue,\
					max: 0,\
					zoomRange: false,\
					panRange: false\
				},\
				xaxis: {\
					min: 0\
				},\
				zoom: {\
					interactive: true\
				},\
				pan: {\
					interactive: true\
				}\
			});\
\
			placeholder.bind("plothover", function (event, pos, item) {\
				if (item) {\
					var y = item.datapoint[1].toFixed(2);\
					$("#plot-tooltip").html(y).css({top: item.pageY+5, left: item.pageX+5}).show();\
				} else {\
					$("#plot-tooltip").hide();\
				}\
			});\
\
			// Zooming with more than 100 doesn\'t seem to work\
			this.plot.zoom(100);\
			this.plot.zoom(100);\
			this.plot.zoom(100);\
			this.plot.pan({ left: 600 });\
			this.addPanArrow("left", 55, 60, { left: -100 }, placeholder);\
			this.addPanArrow("right", 25, 60, { left: 100 }, placeholder);\
			this.addZoomArrow("up", 40, 45, placeholder);\
			this.addZoomArrow("down", 40, 75, placeholder);\
\
			$(\'#plot-period\').on(\'change\', function() {\
				self.refresh();\
			});\
\
			ko.applyBindings(this, document.getElementById(\'lte-doctor-values\'));\
			this.refresh();\
		};\
	};\
\
	var id = window.setTimeout(function() {}, 0);\
	while (id--) {\
		window.clearTimeout(id);\
	}\
\
	var lteDoctor = new LteDoctor();\
	lteDoctor.init();\
</script>\
'); 