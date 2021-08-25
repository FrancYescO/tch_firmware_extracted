
<%
require("libos")

local platform_information = os.platform_information()
%>
void function() {

	"use strict";

	function populate_dom(dom,node) {
		if (node.id) {
			dom[node.id] = node;
		}

		for (var i = 0; i < node.childNodes.length; ++i) {
			populate_dom(dom,node.childNodes[i]);
		}
	}

	function Slide(id,div,on_enter,on_exit) {
		this.id = id;
		this.idx = 0;
		this.dom = {};
		this.on_enter = on_enter;
		this.on_exit = on_exit;

		if (div) {
			populate_dom(this.dom,document.querySelector(div));
		}
	}

	var slides = function() {

		var element = null;
		var last_slide = 0;
		var slide_list = [];
		var slide_map = {};
		
		return {
			init: function() {
				element = document.getElementById("slides");

				if (element.selected === undefined) {
					element.selected = 0;
				}

				var focusThis = function(elem){
					setTimeout(function(){
						$(elem).focus();
						if(elem.select) return elem.select();
						if(elem.$ && elem.$.input && elem.$.input.select) return elem.$.input.select();
					},100)
				}

				window.addEventListener("keypress",function(e){
					if(e.key === "Enter"){
						var current = slide_list[element.selected];
						var currentSlide = element.selectedItem;
						var activeInput = $(document.activeElement).closest("input, paper-item")[0];
						var inputs = $(currentSlide).find("input").filter(function(index,element){
							var inSubAnim = $(element).parents("neon-animatable[name]");
							if(inSubAnim.length){
								return inSubAnim.hasClass("iron-selected");
							}
							return true;
						});
						if(activeInput){
							if($(activeInput).closest(".dropdown-trigger")[0]) return;

							var inputIndex = 0;
							for(var i = 0; i < inputs.length; i++){
								if(inputs[i] === activeInput){
									inputIndex = i;
									break;
								}
							}
							if(inputIndex !== null){
								var focusOn = inputIndex + 1;
								if(focusOn < inputs.length){
									return focusThis(inputs[focusOn]);
								}
							}
						}else if(inputs.length){
							return focusThis(inputs[0]);
						}
						var nextButton = current.dom.button_submit || current.dom.button_next || current.dom.button_start;
						$(nextButton).click();
					}
				});
			},

			show: function() {
				setTimeout(function() {
					var res = document.getElementsByTagName("duma-alert");
					if(res[0]){
						element.parentElement.classList.toggle("hidden");
						var page_loader = document.getElementById("page-loader");
		
						page_loader.classList.add("hidden");
						page_loader.parentNode.removeChild(page_loader);
					}else{
						slides.show();
					}
				},500);
			},

			add: function(id,element_selectors,on_enter) {
				var slide = new Slide(id,element_selectors,on_enter);

				slide.idx = slide_list.length;
				slide_list.push(slide);
				slide_map[slide.id] = slide;
			},

			set: function(id) {
				var new_slide = null;

				if (typeof(id) === "string") {
					new_slide = slide_map[id];
				} else if (typeof(id) === "number") {
					new_slide = slide_list[id];
				}

				if (!new_slide) {
					return;
				}

				var args = [new_slide.dom];

				if (arguments.length > 1) {
					for (var i = 1; i < arguments.length; ++i) {
						args.push(arguments[i]);
					}
				}
			
				post_command("set_slide",[new_slide.idx],function(result) {
					if (!result) {
						return;
					}
					
					var old_slide = slide_list[element.selected];

					if (old_slide.on_exit) { old_slide.on_exit.apply(old_slide,args); }
					if (new_slide.on_enter) { new_slide.on_enter.apply(new_slide,args); }

					last_slide = old_slide.idx;
					element.selected = new_slide.idx;
				});
			}
		};
	}();

	window.onload = function() {
		post_commands([
			{method: "get_platform", args: []},
			{method: "get_countries", args: []},
		],function(platform,countryInfo) {
			try {
				countryInfo = JSON.parse(countryInfo);
			} catch(exception) {
				countryInfo = null;
			}
			<% if platform_information.model ~= "R1" then %>
			var skipCountry = !countryInfo;
			<% else %>
			var skipCountry = true;
			<% end %>
			
			slides.init();
			
			slides.add(
				"empty",
				undefined,

				function(dom) {
					slides.set("eula");
				}
			);
			
			slides.add(
				"eula",
				"#div_eula",

				function(dom) {
					dom.button_accept.onclick = function() {
						post_command("accept_eula",[],function(result) {
							if (!result) {
								return;
							}

							slides.set("welcome");
						});
					}

					dom.button_cancel.onclick = function() {
						slides.set("eula_cancel");
					}
				},
			);

			slides.add(
				"eula_cancel",
				"#div_eula_cancel",

				function(dom) {
					dom.button_return.onclick = function() {
						slides.set("eula");
					}
				}
			);

			slides.add(
				"welcome",
				"#div_welcome",				

				function(dom) {
					dom.button_start.onclick = function() {
						slides.set("check_wan");
					}
				}
			);

			slides.add(
				"check_wan",
				"#div_check_wan",

				function(dom) {
					var attempts = 0;
					var max_attempts = 5;

					function check_wan() {
						post_command("check_wan",[],function(result) {
							if (!result) {
								if (++attempts === max_attempts) {
									slides.set("fail_wan");
								} else {
									setTimeout(check_wan,1000);
								}
							} else {
								slides.set("found_wan");
							}
						});
					}
          
					dom.spinner.active = true;
					check_wan();
				},

				function(dom) {
					dom.spinner.active = false;
				}
			);

			slides.add(
				"fail_wan",
				"#div_fail_wan",

				function(dom) {
					dom.button_retry.onclick = function() {
						slides.set("check_wan");
					}

					dom.button_next.onclick = function() {
						slides.set("wan_setup");
					}
				}
			);

			slides.add(
				"found_wan",
				"#div_found_wan",

				function(dom) {
					dom.button_next.onclick = function() {
						if (platform === "NETGEAR") {
							slides.set("speedtest");
						} else {
							slides.set("bandwidth");
						}
					}
					dom.button_more_wan.onclick = function() {
						slides.set("wan_setup");
					}
				}
			);

			slides.add(
				"wan_setup",
				"#div_wan_advanced",

				function(dom) {
					dom.wan_type_listbox.addEventListener("selected-changed",function(e){
						var sel = e.detail.value;
						dom.wan_pages.selected = sel;
					})
					
					post_command("get_ipv6",[],function(result) {
						if(result){
							result = JSON.parse(result);
							dom.ipv6_wan.checked = result.wan;
							dom.ipv6_lan.checked = result.lan;
						}
					});

					dom.button_submit.onclick = function() {
						dom.button_submit.disabled = true;
						var wan_type = dom.wan_pages.selected;

						var after = function(wan_args){
							post_command("wan_setup",[dom.ipv6_wan.checked,dom.ipv6_lan.checked,wan_type].concat(wan_args || []),function(result) {
								if(result == "true"){
									slides.set("check_wan");
								}
								dom.button_submit.disabled = false;
							});
						}

						if(wan_type === "static"){
							if(dom.ip.validate() && dom.subnet_mask.validate() && dom.gateway.validate()){
								after([dom.ip.value,dom.subnet_mask.value,dom.gateway.value]);
							}else{
								dom.button_submit.disabled = false;
							}
						}else if(wan_type === "pppoe"){
							if(dom.pppoe_username.validate() && dom.pppoe_password.validate() && dom.pppoe_service.validate()){
								after([dom.pppoe_username.value,dom.pppoe_password.value,dom.pppoe_service.value]);
							}else{
								dom.button_submit.disabled = false;
							}
						}else{
							after([dom.dhcp_clientid.value,dom.dhcp_vendorid.value]);
						}
					}
					dom.button_skip.onclick = function() {
						slides.set("bandwidth");
					}
				}
			);

			slides.add(
				"speedtest",
				"#div_speedtest",

				function(dom) {
					if (platform !== "NETGEAR") {
						slides.set("bandwidth");
					} else {

						var timeout = 3000;
						var timeout_id = 0;

						function check_speedtest_result() {
							post_command("get_speedtest",[],function(result) {
								try {
									result = JSON.parse(result);
								} catch(exception) {
									result = null;
									console.warn(exception);
								}

								if (result && result.up && result.down) {
									slides.set("bandwidth");
								} else {
									slides.set("fail_speedtest");
								}
							});
						}

						function is_speedtest_running() {
							post_command("is_speedtest_running",[],function(result) {
								if (result) {
									timeout_id = setTimeout(is_speedtest_running,timeout);
								} else {
									timeout_id = 0;
									check_speedtest_result();
								}
							});
						}

						function start_speedtest(result) {
							if (result) {
								post_command("is_speedtest_running",[],function(result) {
									if (result) {
										timeout_id = setTimeout(is_speedtest_running,timeout);
									} else {
										slides.set("fail_speedtest");
									}
								});
							} else {
								slides.set("fail_speedtest");
							}
						}

						dom.button_cancel.onclick = function() {
							if (timeout_id) {
								clearTimeout(timeout_id);
								timeout_id = 0;
							}
							post_command("stop_speedtest",[],function() { slides.set("fail_speedtest"); });
						}
            
						dom.spinner.active = true;
						post_command("start_speedtest",[],start_speedtest);
					}
				},

			function(dom) {
					dom.spinner.active = false;
				}
			);

			slides.add(
				"fail_speedtest",
				"#div_fail_speedtest",

				function(dom) {
					if (platform !== "NETGEAR") {
						slides.set("bandwidth");
					}

					dom.button_retry.onclick = function() {
						slides.set("speedtest");
					}

					dom.button_next.onclick = function() {
						slides.set("bandwidth");
					}
				}
			);

			slides.add(
				"bandwidth",
				"#div_bandwidth",

				function(dom) {
					if (platform === "NETGEAR") {
						post_command("get_speedtest",[],function(result) {
							try {
								result = JSON.parse(result);
							} catch(exception) {
								result = null;
								console.warn(exception);
							}

							if (result) {
								dom.input_upload.value = result.up > 0.0 ? Math.floor(result.up).toString(): "1000";
								dom.input_download.value = result.down > 0.0 ? Math.floor(result.down).toString(): "1000";
							} else {
								dom.input_upload.value = "1000";
								dom.input_download.value = "1000";
							}
						});

						dom.button_retry.onclick = function() {
							slides.set("speedtest");
						}

					} else {
						remove_from_dom(dom.button_retry);
						if (!dom.input_upload.value) { dom.input_upload.value = "1000"; }
						if (!dom.input_download.value) { dom.input_download.value = "1000"; }
					}

					dom.button_back.onclick = function() {
						slides.set("check_wan");
					}

					dom.button_next.onclick = function() {
						var upload = dom.input_upload.value;
						var download = dom.input_download.value;
					
						if (!dom.input_upload.validate() 
						|| !dom.input_download.validate()
						|| !upload.length
						|| !download.length) {
							return;
						}

						post_command("set_bandwidth",[upload,download],function(result) {
							if (!result) {
								return;
							}

							slides.set("authentication");
						});
					}
				}
			);

			slides.add(
				"authentication",
				"#div_authentication",

				function(dom) {
					function escapeRegExp(string) {
						return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // $& means the whole matched string
					}
					dom.input_password.onchange = function() {
						dom.input_password_repeat.pattern = "^" + escapeRegExp(this.value) + "$";
					}

					dom.button_back.onclick = function() {
						slides.set("bandwidth");
					}

					dom.button_submit.onclick = function() {
						if (!dom.input_username.validate()
						||  !dom.input_password.validate()
						||  !dom.input_password_repeat.validate()) {
							return;
						}

						post_command("set_authentication",[dom.input_username.value,dom.input_password.value],function(result) {
							if (result) {
								slides.set(skipCountry ? "wifi" : "country" );
							}
						});
					}
				}
			);

			<% if platform_information.model ~= "R1" then %>
			slides.add(
				"country",
				"#div_country",
				function(dom) {
					if(countryInfo){
						var items = [];
						for(var key in countryInfo.map){
							items.push({code: key, name: countryInfo.map[key]});
						}
						dom.country_items.items = items.sort(function(a,b){
							return a.name > b.name ? 1 : -1;
						});
						dom.country_listbox.selected = countryInfo.current;
					}else{
						slides.set("wifi");
					}

					dom.button_back.onclick = function() {
						slides.set("authentication");
					}

					dom.button_submit.onclick = function() {
						if(dom.country_listbox.selected){
							post_command("set_country",[dom.country_listbox.selected],function(result) {
								if (result) {
									countryInfo.current = dom.country_listbox.selected;
									slides.set("wifi");
								}
							});
						}else{
							dom.country_drop.invalid = true;
						}
					}
				}
			);
			<% end %>

			slides.add(
				"wifi",
				"#div_wifi",

				function(dom) {
					post_command("get_wifi",[],function(wifi) {
						try {
							wifi = JSON.parse(wifi);
						} catch(exception) {
							console.warn(exception);
							wifi = null;
						}

						if (wifi) {
							dom.input_ssid.value = wifi.ssid;
							dom.input_password.value = wifi.key;
							dom.input_password_repeat.value = wifi.key;
							dom.input_password_repeat.pattern = wifi.key;
						}
					});

					dom.input_password.onchange = function() {
						dom.input_password_repeat.pattern = "^" + this.value + "$";
					}

					dom.button_back.onclick = function() {
						slides.set(skipCountry ? "authentication" : "country");
					}

					dom.button_submit.onclick = function() {
						if (!dom.input_ssid.validate()
						||  !dom.input_password.validate()
						||  !dom.input_password_repeat.validate()) {
							return;
						}

						post_command("set_wifi",[dom.input_ssid.value,dom.input_password.value],function(result) {
							if (result) {
								slides.set("wait_wifi");
							}
						});
					}
				}
			);

			slides.add(
				"wait_wifi",
				"#div_wait_wifi",

				function(dom) {
					function check_wifi() {
						post_command("check_wifi",[],function(result) {
							if (result) {
								slides.set("time_zone");
							} else {
								setTimeout(check_wifi,3000);
							}
						});
					}

					dom.spinner.active = true;
					setTimeout(check_wifi,3000);
				},

				function (dom) {
					dom.spinner.active = false;
				}
			);

			slides.add(
				"time_zone",
				"#div_time_zone",
				function(dom) {
					post_command("get_time_zones",[],function(zoneInfo) {
						try {
							zoneInfo = JSON.parse(zoneInfo);
						} catch(exception) {
							console.warn(exception);
							zoneInfo = null;
						}

						if (zoneInfo) {
							dom.time_zone_items.items = zoneInfo.zones;
							dom.time_zone_listbox.selected = zoneInfo.current;
							dom.time_zone_dst.checked = zoneInfo.dst;
						}
					});

					dom.button_back.onclick = function() {
						slides.set("wifi");
					}

					dom.button_submit.onclick = function() {

						post_command("set_time_zone",[dom.time_zone_listbox.selected,dom.time_zone_dst.checked],function(result) {
							if (result) {
								if (platform === "NETDUMA") {
									<% if platform_information.model ~= "R1" then %>
									slides.set("preferences");
									<% else %>
									slides.set("done");
									<% end %>
								} else {
									slides.set("done");
								}
							}
						});
					}
				}
			);

			<% if platform_information.model ~= "R1" then %>
			slides.add(
				"preferences",
				"#div_preferences",
				function(dom) {

					dom.button_back.onclick = function() {
						slides.set("time_zone");
					}

					dom.button_submit.onclick = function() {

						post_command("set_telem",[dom.tele.checked],function(result) {
							if (result) {
								slides.set("done");
							}
						});
					}

					dom.toggle_explain.onclick = function() {
						dom.explain.classList.toggle("open");
					}
				}
			);
			<% end %>

			slides.add(
				"done",
				"#div_done",

				function(dom) {
					post_command("done",[],function(result) {
						set_location("/desktop/index.html?forceTourStart=true&showWelcome=true");
					});
				}
			);

			post_command("get_slide",[],function(slide) {
				slides.show();
				slides.set(parseInt(slide));
			});
		});
	}

}();
