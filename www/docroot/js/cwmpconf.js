$(function() {
  if (FileUpload.length == 0)
  {
    $("#tr069-successmsg").removeClass("show").addClass("hide");
  }
  else
    $("#tr069-successmsg").removeClass("hide").addClass("show");
  $('input, textarea').focus(function () {
    $(this).data('placeholder', $(this).attr('placeholder')).attr('placeholder', '');
  }).blur(function () {
    $(this).attr('placeholder', $(this).data('placeholder'));
  });

  $("#btn-import").click(function() {
    $('#import-nofile-msg, #import-failed-msg, #tr69-info-invalidFile').css("display", "none")
    $("#importing-msg").addClass("hide");
    var stat = true;

    var nofile_msg = $("#tr069-nofile");
    if ($("#fileupload").val() == "") {
      nofile_msg.removeClass("hide");
      nofile_msg[0].scrollIntoView();
      return false;
    }
    nofile_msg.addClass("hide");

    if ($("#fileupload").val()) {
      $("#fileupload").hide();
      var fileName = $("#fileupload").val();
      var extensionPattern = new RegExp(/.+\.0$/);
      if (!extensionPattern.test(fileName) || stat == false) {
        $("#fileupload").show();
        nofile_msg.hide();
        $("#tr69-info-invalidFile").show();
        $("#fileupload").val("");
        return false;
      }
    }
    var _this = $(this).parents(".control-group");
    $("#fileupload").show();
    $("#import-failed-msg", "#tr69-info-invalidFile").addClass("hide");
    var importing_msg = $("#importing-msg");
    importing_msg.removeClass("hide");
    importing_msg[0].scrollIntoView();
    var params = [];
    var target = "modals/cwmpconf-modal.lp";
    var file = $("#fileupload").val();
    var myUrl = "modals/cwmpconf-modal.lp?action=import_config&name="+$('#fileupload')[0].files[0].name;
    var file = $("#fileupload").prop("files")[0];
    var form_data = new FormData();
    form_data.append("CSRFtoken", form_dataSession);
    form_data.append("configfile", file);
    $.ajax({
        url: myUrl,
        dataType: 'json',
        cache: false,
        contentType: false,
        processData: false,
        data: form_data,
        type: 'post',
        success: function(data){
          if (data.uploadStatus == "error" ) {
            $("#mainForm").prepend(data);
            $("#importing-msg").addClass("hide");
            $(".third-update-step").addClass("hide");
            $("#import-failed-msg").css("display", "block")
            return false;
          }
          else {
             var scrolltop = $(".modal-body").scrollTop();
             tch.loadModal(target, function () {
             $(".modal-body").scrollTop(scrolltop);
             $(".third-update-step").removeClass("hide");
             });
         }}
      });
   return false;
  });
});
