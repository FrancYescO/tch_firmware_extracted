<style>
	.card-label {
		float: left;
		padding-right: 5px;
		font-weight: 500;
		font-size: 16px;
		cursor: default;
	}
	.card-control {
		cursor: default;
	}
</style>
<%
local ngx = ngx

-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")

local params = utils.get_params()

local session = ngx.ctx.session

-- In case we are waiting for the user to enter the PIN code, we redirect to the SIM page
local allowSimRedirect = false
if session:hasAccess("/modals/lte-sim.lp") then
	allowSimRedirect = true
end

local light = {
	status = "0",
	desc = T"Disabled"
}

local platform_capabilities = utils.getContent("rpc.mobiled.platform.capabilities.")
if platform_capabilities.module_power_control == "true" then
	local result = utils.getContent("uci.mobiled.platform.power_on")
	if result['power_on'] == "1" then
		light.desc = T"Enabled"
		light.status = "1"
	end
else
	local uci_device_path = utils.get_uci_device_path()
	local result = utils.getContent(uci_device_path .. "enabled")
	if result['enabled'] == "1" then
		light.desc = T"Enabled"
		light.status = "1"
	end
end

local modalPath = nil
local switchName = nil
if session:hasAccess("/modals/lte-modal.lp") then
	modalPath = "/modals/lte-modal.lp"
	switchName = "interface_enabled"
end
%>

<script language="javascript" type="text/javascript" src="js/knockout-min.js"></script>
<link href="/css/mobiled.css" rel="stylesheet">
<div class="span3" id="mobiletab">
	<div class="smallcard">
		<%= ui_helper.createCardHeader(params.card_title, modalPath, switchName, light.status) %>
		<div id="signal-strength-indicator-small">
			<div class="absolute">
				<div class="bar-small bar-small1"></div>
				<div class="bar-small bar-small2"></div>
				<div class="bar-small bar-small3"></div>
				<div class="bar-small bar-small4"></div>
				<div class="bar-small bar-small5"></div>
			</div>
		</div>
		<div class="content card_bg" data-bg-text="&#xf012;">
			<%= ui_helper.createSimpleLight(light.status, light.desc) %>
			<p class="subinfos">
				<div style="height: 25px;" data-bind="visible: mobileStatus().length > 0">
					<label class="card-label"><%= T"Status"..":" %></label>
					<div class="controls">
						<strong data-bind="text: mobileStatus"></strong>
					</div>
				</div>
				<div style="height: 25px;" data-bind="visible: radioType().length > 0">
					<label class="card-label"><%= T"Radio Type"..":" %></label>
					<div class="card-control">
						<strong data-bind="text: radioType"></strong>
					</div>
				</div>
				<div style="height: 25px;" data-bind="visible: signalQuality().length > 0">
					<label class="card-label"><%= T"Quality"..":" %></label>
					<div class="controls">
						<strong data-bind="text: signalQuality"></strong>
					</div>
				</div>
				<div style="height: 25px;" data-bind="visible: deviceStatus().length > 0">
					<div class="controls">
						<strong data-bind="text: deviceStatus"></strong>
					</div>
				</div>
			</p>
		</div>
	</div>
</div>
<script>
	$(document).ready(function () {
		var allowSimRedirect = <%= allowSimRedirect %>;
		var LteCard = function () {
			var self = this;
			this.signalQuality = ko.observable("");
			this.radioType = ko.observable("");
			this.mobileStatus = ko.observable("");
			this.deviceStatus = ko.observable("");
			this.updateBars = function(bars) {
				$('#signal-strength-indicator-small .absolute').children('.bar-small').each(function (index) {
					if(index < bars) {
						$(this).addClass('bar-small-active');
					} else {
						$(this).removeClass('bar-small-active');
					}
				});
			};
			this.refresh = function () {
				$.post("/ajax/mobiletab.lua", [tch.elementCSRFtoken()], function(data) {
					if(data.bars != undefined) {
						self.updateBars(data.bars);
					}
					if(data.radio_interface != undefined) {
						self.radioType(data.radio_interface);
					}
					if(data.status != undefined) {
						self.mobileStatus(data.status);
					}
					if(data.signal_quality != undefined) {
						self.signalQuality(data.signal_quality);
					}
					if(data.no_device != undefined) {
						self.deviceStatus(data.no_device);
					}
					if(data.redirect_sim != undefined) {
						if(data.redirect_sim === true && allowSimRedirect) {
							$.each($('.settings[data-id="lte-modal"]'), function () {
								$(this).attr('data-id', 'lte-sim');
								$(this).attr('data-remote', '/modals/lte-sim.lp');
							});
						} else {
							$.each($('.settings[data-id="lte-sim"]'), function () {
								$(this).attr('data-id', 'lte-modal');
								$(this).attr('data-remote', '/modals/lte-modal.lp');
							});
						}
					}
				}, "json");
			};
			setInterval(self.refresh, 50000);
			self.refresh();
		};

		var lteCard = new LteCard();
		ko.applyBindings(lteCard, document.getElementById('mobiletab'));
	});
</script>
