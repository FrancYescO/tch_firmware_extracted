<%
	require("libos")

	local platform_information = os.platform_information()
%>

function remove_from_dom(element) {
	if (element.parentNode) {
		element.parentNode.removeChild(element);
	}
}

function ajax(method,mime_type,response_type,url,data,callback) {
	function on_response() {
		if (callback) {
			callback(this.response);
		}
	}

	var request = new XMLHttpRequest();

	request.overrideMimeType(mime_type);
	request.responseType = response_type;
	request.onload = on_response;
	request.onerror = on_response;
	request.open(method,url,true);
	request.send(data);

	return request;
}

var disable_input = function() {

	var active = 0;

	function actually_disable_input(disabled) {
		var elements = document.querySelectorAll("button,input");

		for (var i = 0; i < elements.length; ++i) {
			elements[i].disabled = disabled;
		}
	}

	return function(disabled) {
		if (disabled && !active++) {
			actually_disable_input(true);
		} else if (!disabled && !--active) {
			actually_disable_input(false);
		}
	}
}();

var validate_result = function() {
	
	var newline_regex = new RegExp("[\n\r]","g");
	var whitespace_regex = new RegExp("^ *","");

	return function(result) {
		newline_regex.lastIndex = 0;
		result = result.replace(newline_regex,"").replace(whitespace_regex,"");

		if (result === "nil") {
			return undefined;
		} else {
			return result;
		}
	}
}();

function post_command(method,args,callback) {
	function callback_wrapper(result) {
		callback(validate_result(result));
		disable_input(false);
	}

	var form = new FormData();

	form.append("method",method);

	for (var i = 0; i < args.length; ++i) {
		form.append("arg_" + (i + 1).toString(),args[i].toString());
	}

	disable_input(true);

	return ajax(
		"POST",
		"multipart/form-data",
		"text",
		"/cgi-bin/dumaos_setup.lua",
		form,
		callback_wrapper
	);
}

function post_commands(commands,callback) {
	var active = commands.length;
	var results = [];
	    results.length = commands.length;

	function check_results(i,result) {
		results[i] = validate_result(result);

		if (!--active) {
			callback.apply(null,results);
			disable_input(false);
		}
	}

	disable_input(true);

	for (var i = 0; i < commands.length; ++i) {
		var method = commands[i].method;
		var args = commands[i].args;
		var form = new FormData();

		form.append("method",method);
		
		for (var j = 0; j < args.length; ++j) {
			form.append("arg_" + (j + 1).toString(),args[j].toString());
		}

		ajax(
			"POST",
			"multipart/form-data",
			"text",
			"/cgi-bin/dumaos_setup.lua",
			form,
			check_results.bind(null,i)
		);
	}
}

var ip_regex = new RegExp("^(?:[0-9]{1,3}\.?){4}$","");

function set_location(path) {
	var hostname = null;
	
	if (ip_regex.test(hostname)) {
		hostname = hostname;
	} else {
		hostname = "<%= platform_information == "NETGEAR"
				and "routerlogin.net"
				or "dumaos" %>";
		
	}

	location.replace("http://" + hostname + path);
}
