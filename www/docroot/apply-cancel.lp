--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')
  local vdf_helper = require("vodafone_helper")
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
  ');  if vdf_helper.getVariant() == "NZ" then   ngx.print('\
    <div class="modal fade" id="apply-cancel-popup" role="dialog" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-body no-padding mobile-modal-padding-top">\
            <form class="form-horizontal">\
              <div class="form-group no-margin-bottom">\
                <div class="col-md-12 col-sm-12 col-lg-12">\
                  <p class="title">\
                    ');  ngx.print(T"Unsaved Changes"); ngx.print('\
                  </p>\
                </div>\
                <div>\
                  <p>');  ngx.print(T"Please apply or cancel your changes before you proceed further."); ngx.print('</p>\
                </div>\
              </div>\
                <div class="row apply-cancel-hr no-margin-right">\
                  <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                    <input class="button button-apply mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('" type="button" id="modal-apply">\
                    <input class="button button-cancel mob-button-width mob-apply-cancel cancel-btn" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="modal-cancel">\
                  </div>\
                </div>\
            </form>\
          </div>\
        </div>\
      </div>\
    </div>\
  ');  end  ngx.print('\
</div>'); 