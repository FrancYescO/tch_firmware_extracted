// inspired by https://github.com/jfeldstein/jQuery.AjaxFileUpload.js
(function($){
  $.extend({
    fileUpload: function(form, options) {
      // process options
      var settings = $.extend({
        params: {},
        completeCallback: function() {}
      }, options);

      // callback to handle the result of the upload
      var handleResponse = function(loadedFrame, submitted_form) {
        var response, responseStr = loadedFrame.contentWindow.document.body.innerHTML;
        try {
          response = $.parseJSON(responseStr);
        } catch(e) {
          response = responseStr;
        }
        var hiddens = submitted_form.children("input[type='hidden']");
        for(key in settings.params) {
          hiddens.remove("input[name='"+key+"']");
        }
        submitted_form.removeAttr("target");
        settings.completeCallback(submitted_form, response);
      };

      // create iframe to target the upload
      var frame_id = 'ajaxUploader-iframe-' + Math.round(new Date().getTime() / 1000)
      $('body').after('<iframe width="0" height="0" style="display:none;" name="'+frame_id+'" id="'+frame_id+'"/>');
      $('#'+frame_id).load(function() {
        handleResponse(this, form);
      });
      form.attr("target", frame_id);
      form.prepend(function() {
        var key, html = '';
        for(key in settings.params) {
          var paramVal = settings.params[key];
          if (typeof paramVal === 'function') {
            paramVal = paramVal();
          }
          html += '<input type="hidden" name="' + key + '" value="' + paramVal + '" />';
        }
        return html;
      });
      // do the submit/upload
      form.submit(function(e) { e.stopPropagation(); }).submit();
    }
  });
})(jQuery);
