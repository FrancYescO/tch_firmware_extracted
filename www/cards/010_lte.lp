--pretranslated: do not change this file
 ngx.print('<style>\
	.card-label {\
		float: left;\
		padding-right: 5px;\
		font-weight: 500;\
		font-size: 16px;\
		cursor: default;\
	}\
	.card-control {\
		cursor: default;\
	}\
</style>\
');  
local ngx = ngx

-- Enable localization
gettext.textdomain('webui-mobiled')
local session = ngx.ctx.session
local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")

local result = utils.getContent("rpc.mobiled.DeviceNumberOfEntries")
local devices = tonumber(result.DeviceNumberOfEntries)
if not devices then devices = 0 end
local role = session:getrole()  
local params = utils.get_params()

-- In case we are waiting for the user to enter the PIN code, we redirect to the SIM page
local allowSimRedirect = false

if session:hasAccess("/modals/lte-sim.lp") and ((role == "engineer") or (role ~= "engineer" and devices >= 1))  then
	allowSimRedirect = true


local light = {
	status = "0",
	desc = T"Disabled"
}

local uci_device_path = utils.get_uci_device_path()
local result = utils.getContent(uci_device_path .. "enabled")
if result['enabled'] == "1" then
	light.status = "1"
	light.desc = T"Enabled"
end

local modalPath = nil
if session:hasAccess("/modals/lte-modal.lp") then
	modalPath = "/modals/lte-modal.lp"
end
ngx.print('\
\
<script language="javascript" type="text/javascript" src="js/knockout-min.js"></script>\
<link href="/css/mobiled.css" rel="stylesheet">\
<div class="span3" id="mobiletab">\
	<div class="smallcard">',
		ui_helper.createCardHeader(params.card_title, modalPath), '\
		<div id="signal-strength-indicator-small">\
			<div class="absolute">\
				<div class="bar-small bar-small1"></div>\
				<div class="bar-small bar-small2"></div>\
				<div class="bar-small bar-small3"></div>\
				<div class="bar-small bar-small4"></div>\
				<div class="bar-small bar-small5"></div>\
			</div>\
		</div>\
		<div class="content card_bg" data-bg-text="&#xf012;">\
    	<div class="divtable">',
			ui_helper.createSimpleLight(light.status, light.desc), '\
				<div class="subinfos" style="height: 25px;" data-bind="visible: mobileStatus().length > 0"  class="subinfos">\
					<label class="card-label">', T"Status"..":", '</label>\
					<div class="controls">\
						<strong data-bind="text: mobileStatus"></strong>\
					</div>\
				</div>\
				<div class="subinfos" style="height: 25px;" data-bind="visible: radioType().length > 0" class="subinfos">\
					<label class="card-label">', T"Radio Type"..":", '</label>\
					<div class="card-control">\
						<strong data-bind="text: radioType"></strong>\
					</div>\
				</div>\
				<div class="subinfos" style="height: 25px;" data-bind="visible: signalQuality().length > 0" class="subinfos">\
					<label class="card-label">', T"Quality"..":", '</label>\
					<div class="controls">\
						<strong data-bind="text: signalQuality"></strong>\
					</div>\
				</div>\
				<div class="subinfos" style="height: 25px;" data-bind="visible: deviceStatus().length > 0" class="subinfos">\
					<div class="controls">\
						<strong data-bind="text: deviceStatus"></strong>\
					</div>\
				</div>\
			</div>\
		</div>\
	</div>\
</div>\
<script>\
	$(document).ready(function () {\
		var allowSimRedirect = ', allowSimRedirect, ';\
		var LteCard = function () {\
			var self = this;\
			this.signalQuality = ko.observable("");\
			this.radioType = ko.observable("");\
			this.mobileStatus = ko.observable("");\
			this.deviceStatus = ko.observable("");\
			this.updateBars = function(bars) {\
				$(\'#signal-strength-indicator-small .absolute\').children(\'.bar-small\').each(function (index) {\
					if(index < bars) {\
						$(this).addClass(\'bar-small-active\');\
					} else {\
						$(this).removeClass(\'bar-small-active\');\
					}\
				});\
			};\
			this.refresh = function () {\
				$.post("/ajax/mobiletab.lua?auto_update=true", [tch.elementCSRFtoken()], function(data) {\
					if((data.bars != undefined)&&(data.status == "Connected")) {\
						self.updateBars(data.bars);\
				        }else{\
				            	self.updateBars("0");\
					}\
					if((data.radio_interface != undefined)&&(data.status == "Connected")) {\
						self.radioType(data.radio_interface);\
          				}else{\
            					self.radioType("");\
					}\
					if(data.status != undefined) {\
						self.mobileStatus(data.status);\
					}\
					if((data.signal_quality != undefined)&&(data.status == "Connected")) {\
						self.signalQuality(data.signal_quality);\
          				}else{\
            					self.signalQuality("N/A");\
					}\
					if(data.no_device != undefined) {\
						self.deviceStatus(data.no_device);\
					}\
					if(data.redirect_sim != undefined) {\
						if(data.redirect_sim === true && allowSimRedirect) {\
							$.each($(\'.settings[data-id="lte-modal"]\'), function () {\
								$(this).attr(\'data-id\', \'lte-sim\');\
								$(this).attr(\'data-remote\', \'/modals/lte-sim.lp\');\
							});\
						} else {\
							$.each($(\'.settings[data-id="lte-sim"]\'), function () {\
								$(this).attr(\'data-id\', \'lte-modal\');\
								$(this).attr(\'data-remote\', \'/modals/lte-modal.lp\');\
							});\
						}\
					}\
				}, "json");\
			};\
			setInterval(self.refresh, 50000);\
			self.refresh();\
		};\
\
		var lteCard = new LteCard();\
		ko.applyBindings(lteCard, document.getElementById(\'mobiletab\'));\
	});\
</script>');
end