//cannot be called analytics.js -> blocked by ublock / adblockers

(function(context) {
	var packageId = "com.netdumasoftware.trafficcontroller";

	function display_analytic(ruleName,enabled,status,packets,bytes) {
		var row = $("<tr></tr>").attr("active",enabled ? "true" : null)
			.append($("<td></td>")
        		.text(ruleName))
			.append($("<td></td>")
				.html("<granite-led "+(status ? "powered" : "")+"></granite-led>"))
			.append($("<td></td>")
				.text(packets))
			.append($("<td></td>")
				.text(format_bytes(bytes)));

		$("#firewall-analytics", context).append(row);
	}
	function clear_analytics(){
		$("#firewall-analytics", context).empty();
	}
	var byteSymbols = ['B','KB','MB','GB','TB','PB','EB','ZB','YB'];
	function format_bytes(bytes,scale=10){
		for(var i = 0;i < byteSymbols.length; ++i){
			var pow = Math.pow(1024,i);
			var amount = (bytes / pow).toFixed(2);
			if(amount > 1024*scale){
				continue;
			}
			//So when Bytes, it displays as an int, not as a decimal
			if(i == 0) {
				return bytes + ' ' + byteSymbols[i];
			}else{
				return amount + ' ' + byteSymbols[i];
			}
		}
		return bytes;
	}

	function isRuleActive(rule){
		if(!rule.enabled){ return false; }
		now = Date(Date.now());
		/*foreach time in rule.intervals
			if now > interval.start && now < interval.end
				return true
		*/
		return false;
	}

  start_cycle(function () {
    return [long_rpc_promise(packageId, "get_rules", [])];
  
    }, function (anas) {
		clear_analytics();
		anas = anas[0];
		for(var i = 0;i<anas.length; i++){
			display_analytic(anas[i].name,anas[i].enabled,anas[i].active,anas[i].packets,anas[i].bytes);
		}
		
		$("duma-panel", context).prop("loaded", true);
	}, 1500);

})(this);
