--pretranslated: do not change this file
 
  --Enable localization
  gettext.textdomain('webui-core')
  ngx.print('\
<div class="row">\
  <div role="alert" class="alert alert-info under_construction">');  ngx.print(T"Page Under Construction..."); ngx.print('</div>\
</div>\
'); 