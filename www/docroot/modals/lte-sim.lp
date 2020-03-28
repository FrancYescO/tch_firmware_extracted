<style>
	.float-left {
		float: left;
		margin-right: 5px;
	}
</style>
<%
local ngx, tinsert = ngx, table.insert

-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local params = utils.get_params()

local function createFunctionButton(content, action, param, text)
	if param ~= nil then
		tinsert(content, '<div data-bind="click: function(){ ' .. action .. '(\'' .. param .. '\'); }" class="btn float-left">'.. text .. '</div>')
	else
		tinsert(content, '<div data-bind="click: function(){ ' .. action .. '(); }" class="btn float-left">'.. text .. '</div>')
	end
end

local sim = utils.getContent("rpc.mobiled.device.@1.sim.")

ngx.print(ui_helper.createHeader(params.modal_title, true, true, nil))

ngx.print('<div class="modal-body no-save update" id="lte-sim-body">')

ngx.print('<form class="form-horizontal" method="post" action="modals/lte-sim.lp">')

local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("tabs-mobiled.lp")

local html = {}

local pin_error = {
	alert = {
		class = "alert-error hide",
		id = "pin-error-msg"
	}
}

local advanced = {
	group = {
		class = "advanced hide"
	},
	span = {
		class = "span5"
	}
}

if sim.sim_state == "ready" or sim.sim_state == "locked" or sim.sim_state == "blocked" then
	local option = {}
	option['data-bind'] = "text: pinStateReadable"
	option['class'] = "span5"
	local options = {span = option}

	tinsert(html, "<fieldset><legend>" .. T"PIN Protection" .. "</legend>")

	tinsert(html, ui_helper.createAlertBlock("", pin_error))

	tinsert(html, '<div data-bind="visible: simViewState() == \'default\'">')

	tinsert(html, '<div style="height: 40px;" data-bind="visible: pinState() != \'blocked\'">')

	tinsert(html, ui_helper.createInputPassword(T"PIN Code", "pin"))

	tinsert(html, '<div data-bind="visible: pinState() == \'locked\'">')
	createFunctionButton(html, "unlockPin", nil, T"Unlock")
	tinsert(html, '</div>')

	tinsert(html, '<div data-bind="visible: pinState() == \'disabled\'">')
	createFunctionButton(html, "setPinState", "enable", T"Enable PIN")
	tinsert(html, '</div>')
	tinsert(html, '<div data-bind="visible: pinState() != \'disabled\'">')
	createFunctionButton(html, "setPinState", "disable", T"Disable PIN")
	tinsert(html, '</div>')

	createFunctionButton(html, "changePin", nil, T"Change PIN")

	tinsert(html, '</div>') -- pinState() != 'blocked'
	tinsert(html, '</div>') -- simViewState() == 'default'

	tinsert(html, '<div data-bind="visible: pinState() == \'blocked\' || simViewState() == \'change\'">')
	tinsert(html, ui_helper.createInputPassword(T"New PIN Code", "newpin"))
	tinsert(html, '</div>')

	tinsert(html, '<div data-bind="visible: simViewState() == \'default\'">')

	tinsert(html, '<div data-bind="visible: pinState() == \'blocked\'">')
	tinsert(html, ui_helper.createInputPassword(T"PUK Code", "puk"))
	createFunctionButton(html, "unblockPin", nil, T"Unblock")
	tinsert(html, '</div>') -- pinState() == 'blocked'
	tinsert(html, '</div>') -- simViewState() == 'default'

	tinsert(html, '<div margin-left: 180px;" data-bind="visible: simViewState() == \'change\'">')
	createFunctionButton(html, "doChangePin", nil, T"Ok")
	createFunctionButton(html, "setSimView", "default", T"Cancel")
	tinsert(html, '</div>') -- simViewState() == 'change'

	tinsert(html, '<div style="clear: both;" data-bind="visible: simViewState() == \'default\'">')
	tinsert(html, '<div data-bind="visible: pinStateReadable().length > 0">')
	tinsert(html, ui_helper.createLabel(T"Status"..":", "", options))
	tinsert(html, '</div>')
	option['data-bind'] = "text: pinRetriesLeft"
	tinsert(html, ui_helper.createLabel(T"Unlock Retries Left"..":", "", options))
	option['data-bind'] = "text: pukRetriesLeft"
	tinsert(html, ui_helper.createLabel(T"Unblock Retries Left"..":", "", options))
	tinsert(html, '</div>') -- simViewState() == 'default'

	tinsert(html, "</fieldset>")

	tinsert(html, "<fieldset><legend>" .. T"SIM Card" .. "</legend>")

	if sim.iccid ~= "" then
		tinsert(html, ui_helper.createLabel(T"ICCID"..":", sim.iccid))
	end

	if sim.msisdn ~= "" then
		tinsert(html, ui_helper.createLabel(T"MSISDN"..":", sim.msisdn))
	end

	advanced['span']['data-bind'] = "text: imsi"
	tinsert(html, '<div data-bind="visible: imsi().length > 0">')
	tinsert(html, ui_helper.createLabel(T"IMSI"..":", "", advanced))
	tinsert(html, '</div>')
	tinsert(html, "</fieldset>")
else
	local mobiled = {
		num_devices = "rpc.mobiled.DeviceNumberOfEntries"
	}
	content_helper.getExactContent(mobiled)
	mobiled.num_devices = tonumber(mobiled.num_devices)
	if not mobiled.num_devices or mobiled.num_devices == 0 then
		tinsert(html, ui_helper.createAlertBlock(utils.string_map["no_device"]))
	else
		tinsert(html, ui_helper.createAlertBlock(T"SIM Not Present"))
	end
end

ngx.print(html)
ngx.print('</form></div>')
ngx.print(ui_helper.createFooter())
%>

<script>
	$(document).ready(function() {
		var pin_error_msg = "<%= T"The PIN code must be composed of 4 to 8 digits." %>";
		var new_error_msg = "<%= T"Please enter the correct current PIN." %>"+" "+pin_error_msg;

		var id = window.setTimeout(function() {}, 0);
		while (id--) {
			window.clearTimeout(id);
		}

		function validatePin(code) {
			return /^\d{4,8}$/.test(code);
		}

		function showError(selector, msg) {
			$(selector).text(msg);
			$(selector).removeClass('hide');
		}

		function hideError(selector) {
			$(selector).addClass('hide');
		}

		var simView = function () {
			var oldpin = "";
			var self = this;
			this.imsi = ko.observable("");
			this.pinStateReadable = ko.observable("");
			this.pinRetriesLeft = ko.observable("");
			this.pukRetriesLeft = ko.observable("");
			this.pinState = ko.observable("");
			this.simViewState = ko.observable("default");
			this.setSimView = function(state) {
				$("input[name='pin']").val('');
				$("input[name='puk']").val('');
				$("input[name='newpin']").val('');
				hideError('#pin-error-msg');
				this.simViewState(state);
			};
			this.changePin = function() {
				var pin = $("input[name='pin']").val();
				if(validatePin(pin)) {
					this.oldpin = pin;
					this.setSimView("change");
				} else {
					showError('#pin-error-msg', new_error_msg);
				}
			};
			this.doChangePin = function() {
				var newpin = $("input[name='newpin']").val();
				var params = [{ name: "action", value: "change"},
							{ name: "old_pin", value: this.oldpin},
							{ name: "new_pin", value: newpin},
							tch.elementCSRFtoken()];
				$.post("/ajax/sim.lua", params, self.updateView, 'json');
			};
			this.setPinState = function(state) {
				var pin = $("input[name='pin']").val();
				var params = [{ name: "action", value: state},
							{ name: "pin", value: pin},
							tch.elementCSRFtoken()];
				$.post("/ajax/sim.lua", params, self.updateView, 'json');
			};
			this.unlockPin = function() {
				var pin = $("input[name='pin']").val();
				var params = [{ name: "action", value: "unlock"},
							{ name: "pin", value: pin},
							tch.elementCSRFtoken()];
				$.post("/ajax/sim.lua", params, self.updateView, 'json');
			};
			this.unblockPin = function() {
				var params = [{ name: "action", value: "unblock"},
							{ name: "pin", value: $("input[name='newpin']").val()},
							{ name: "puk", value: $("input[name='puk']").val()},
							tch.elementCSRFtoken()];
				$.post("/ajax/sim.lua", params, self.updateView, 'json');
			};
			this.refresh = function() {
				var params = [{ name: "action", value: "default"},
				tch.elementCSRFtoken()];
				$.post("/ajax/sim.lua", params, self.updateView, 'json');
			};
			this.updatePinInfo = function(pinInfo) {
				if(pinInfo.unblock_retries_left != undefined) {
					self.pukRetriesLeft(pinInfo.unblock_retries_left);
				}
				if(pinInfo.unlock_retries_left != undefined) {
					self.pinRetriesLeft(pinInfo.unlock_retries_left);
				}
				if(pinInfo.pin_state != undefined) {
					if(pinInfo.pin_state == "enabled_not_verified") {
						self.pinState("locked");
					} else if(pinInfo.pin_state == "blocked") {
						self.pinState("blocked");
					} else if(pinInfo.pin_state == "disabled") {
						self.pinState("disabled");
					} else {
						self.pinState("unlocked");
					}
				}
				if(pinInfo.pin_state_hr != undefined) {
					self.pinStateReadable(pinInfo.pin_state_hr);
				} 
			};
			this.updateSimInfo = function(simInfo) {
				if(simInfo.imsi != undefined) {
					self.imsi(simInfo.imsi);
				} 
			};
			this.updateView = function(data) {
				if(data.status != undefined) {
					if(data.pin_info != undefined) {
						self.updatePinInfo(data.pin_info);
					}
					if(data.sim_info != undefined) {
						self.updateSimInfo(data.sim_info);
					}
					self.setSimView("default");
					if(data.status == false && data.error) {
						showError('#pin-error-msg', data.error);
					}
				}
			};
		};

		var simView = new simView();
		ko.applyBindings(simView, document.getElementById('lte-sim-body'));
		simView.refresh();
	});
</script>
