--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("help_menubar.lp")
  ngx.print('\
');  
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1
local symbolv2 = telstra_helper.symbolnamev2
  ngx.print('\
<div class="container toplevel" style="width:830px">\
    <div class="row">\
        <div class="span11">\
            <div class="span3 help-block">\
                <legend style="border-bottom: 0px; margin-top: 10px;">User Settings</legend>\
            </div>\
            <div class="span7 container">\
                <div class="container span7">\
                    <br>\
                    <p style="margin: 0 0 0">In this section you will be able to change/view settings that are related to user that is accessing the ');  ngx.print( symbolv1 ); ngx.print(' Web Management Interface</p>\
                    \
                    <div class="container span7">\
                        <legend>Step 1:</legend>&nbsp;&nbsp;Click on \'User Settings\' tab on the menu bar\
                    </div>\
                \
                    <div class="container span7">\
                        <legend>Step 2:</legend>&nbsp;&nbsp;Enter the \'Password\' and \'Confirm Password\' in the field\
                    </div>\
                  \
                     <div class="container span7">\
                        <legend>Step 3:</legend>&nbsp;&nbsp;Click on \'Save\' button to save your configuration\
                    </div>\
   \
                </div>\
            </div>\
        </div>\
    </div>\
</div>\
\
');  
lp.include("footer.lp")
  ngx.print('\
\
\
'); 