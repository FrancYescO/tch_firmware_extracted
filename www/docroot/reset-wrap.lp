--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')
  ngx.print('\
\
<div id="resetWrap">\
	<div class="resetButtons resetButtonsShort" id="resetButtonsShort">\
		<div class="rel">\
			<span class="left" id="resetB">&nbsp;</span>\
		</div>\
	</div>\
	<div id="resetBar" class="resetBar" style="display: none;">\
		<div style="" id="r">\
		<div class="clearfix">\
			<span id="resetT">\
				');  ngx.print(T"Do you want to reset this page to default settings?"); ngx.print('\
			</span>\
\
				<input value="');  ngx.print(T"Cancel"); ngx.print('" class="cancelR button button-cancel " id="cancelR" type="button">\
				<input value="');  ngx.print(T"Reset"); ngx.print('" class="resetR button button-apply" id="resetR" type="button">\
\
			<div class="reset-bar"></div>\
			</div>\
		</div>\
	</div>\
</div>\
\
<script>\
$(function() {\
	$("#resetButtonsShort").click(function(){\
		$(this).hide("slow");\
		$("#resetBar").slideDown("slow");\
	});\
	$("#cancelR, #resetR").click(function(){\
		$("#resetBar").slideUp("slow");\
		$("#resetButtonsShort").show("slow");\
	});\
});\
</script>\
'); 