--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')
  ngx.print('\
\
<div id="resetWrapMobile" class="clearfix">\
	<div class="resetButtons resetButtonsShort" style="display: block;">\
		');  ngx.print(T"Reset to default settings"); ngx.print('\
		<div class="rel">\
			<span class="left" id="resetB">&nbsp;</span>\
		</div>\
	</div>\
	<div class="resetBar" style="display: none;">\
		<div class="close-icon cancelR">\
\
		</div>\
		<h3 class="page-title-container" id="resetheader"></h3>\
		<span>\
			');  ngx.print(T"Do you want to reset this page to default settings?"); ngx.print('\
		</span>\
			<input value="');  ngx.print(T"Reset"); ngx.print('" class="resetR button button-apply" type="button" id="resetrmobile">\
			<input value="');  ngx.print(T"Cancel"); ngx.print('" class="cancelR button button-cancel " type="button">\
		<div class="reset-bar"></div>\
	</div>\
</div>\
\
<script>\
$(function() {\
	$(".resetButtonsShort").click(function(){\
		$(".resetBar").slideDown();\
	});\
	$(".cancelR, .resetR").click(function(){\
		$(".resetBar").slideUp();\
	});\
});\
var resettitle = document.getElementsByTagName("TITLE")[0].text;\
document.getElementById("resetheader").innerHTML = resettitle;\
</script>\
'); 