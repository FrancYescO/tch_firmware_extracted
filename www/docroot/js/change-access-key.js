$("#password_reminder").modal();
          $("#save-config").click(function(){
            var value = $("input[name=passwordchange]:checked").val();
            if(value == "now"){
               window.location = "/password.lp";
            }else if(value == "remindlater"){
               $("#password_reminder").modal('hide');
            }else if(value == "dontremind"){
               var params = [];
               var target = $(".modal form").attr("action");
               params.push({
                 name : "action",
                 value : "SAVE"
               },
               {
                 name : "passwordchange",
                 value : value
               }, tch.elementCSRFtoken());
               $.post(target, params);
               $("#password_reminder").modal('hide');
            }
            return false;
          });

