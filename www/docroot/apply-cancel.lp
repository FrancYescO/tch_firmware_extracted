--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')
  ngx.print('\
<div class="row apply-cancel-hr no-margin-right">\
  <div class="col-md-8 col-sm-8 col-xs-12 no-padding-right">\
    <div class="articlediv hide">\
      <div class="message-arrowbox-applied">\
        <div class="message-arrowbox-applied-right">\
          <p class="language-string success-info" id="save-info-msg">');  ngx.print(T"Your changes have been applied"); ngx.print('\
          </p>\
        </div>\
      </div>\
      <div class="message-arrowbox msg-error">\
        <div class="message-arrowbox-applied-right">\
          <p class="language-string success-info" id="save-err-msg">');  ngx.print(T"Your changes have not been updated"); ngx.print('\
          </p>\
        </div>\
      </div>\
    </div>\
  </div>\
  <div class="col-md-4 col-sm-4 col-xs-12 no-padding-right">\
    <input class="button button-apply mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('" type="button" id="global-apply">\
    <input class="button button-cancel mob-button-width mob-apply-cancel cancel-btn" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="global-cancel">\
  </div>\
</div>\
'); 