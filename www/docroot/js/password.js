function passwordCheck(password)
{
  var level = 0;

  //if password has both lower and uppercase characters give 1 point
  if ( ( password.match(std_lower_char) ) && ( password.match(std_upper_char) ) ) level++;

    //if password has at least one number give 1 point
    if (password.match(/\d+/)) level++;

    //if password has at least one special caracther give 1 point
    if ( password.match(spl_char) )     level++;

    //if password length is greater than or equal to minimum length give 1 point
    if ( password.length >= passwordlength ) level++;

    //if password length is greater than minimum length and passwordCheck level is equal to 4 give 1 point
    if (( password.length > passwordlength ) && (level == 4)) level++;

    $('#Password_Strength').removeClass().addClass("pstrength" + level).addClass("span3");
    return level;
}

$(document).ready(
  function() {
    var tries = 0;

    function display_error()
    {
      $("#change-my-pass").text(changePassword);
      $("#erroruserpass").show();
      $(".control-group").addClass("error");
      tries++;
      if(triesbeforemsg > 0 && tries >= triesbeforemsg) {
        $("#defaultpassword").show();
      }
    }
    // Set the focus on the first input field
    $('form:first *:input[type!=hidden]:first').focus();
    // Handle press of enter. Could be handled by adding a hidden input submit but
    // this requires a lot of css tweaking to get it right since display:none does
    // not work on every browser. So go for the js way
    $('form input').keydown(function(e) {
      if(e.which == 13 || e.which == 10) {
        e.preventDefault();
        $("#change-my-pass").click();
      }
    });

    $("#change-my-pass").on("click", function () {
      if(passwordStrength){
         $(".alert").hide();
      }
      if ($("#srp_password_new_1")[0].value != $("#srp_password_new_2")[0].value) {
        display_error();
        return false;
      }
      if(passwordStrength){
         var password1 = $("#srp_password_new_1")[0].value;
         var password2 = $("#srp_password_new_2")[0].value;
         if(passwordCheck(password1) < 4)
         {
           if(password1.length == 0)
           {
             $("#erroruserpass_3").show();
             $(".control-group").addClass("error");
             return false;
           }
           $("#erroruserpass_2").show();
           $(".control-group").addClass("error");
           return false;
         }
         var password = $("#srp_password")[0].value;
         //Start for legacy migration: GUI username/password [NG-48489]
         /*
         If the user has option legacy_salt, means it's migrated from the legacy build.
         Then user the sha1 hash of the password to authenticate.
         */
         var index = -1;
         var userNameArray = userNames.split(",")
         var legacySaltArray = legacySalts.split(",")

         for (var i = 0; i < userNameArray.length - 1; i ++)
         {
           if ( username == userNameArray[i] )
           {
             index = i;
           }
         }
         if (index >= 0)
         {
           var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");
           password = hashObj.getHash("SHA-1", "HEX");
         }
     }
     //End for legacy migration: GUI username/password [NG-48489]
     var srp = new SRP();
     srp.success = function() {
       if(passwordStrength){
          $("#change-my-pass").text(updating);
          srp.generateSaltAndVerifier("/password", username, $("#srp_password_new_1")[0].value)
          //Start for legacy migration: GUI username/password [NG-48489]
          if(index >= 0)
          {
            $.post("/password.lp", { CSRFtoken:$("meta[name=CSRFtoken]").attr("content"), resetLegacySalt:"1"});
          }
          //End for legacy migration: GUI username/password [NG-48489]
       }
       else{
          srp.generateSaltAndVerifier("/password", username, $("#srp_password_new_1")[0].value)
       }
    }
    srp.passwordchanged = function() {
      if(passwordStrength){
         var params = []
         params.push({
           name : "action",
           value : "PasswordChanged"
         }, tch.elementCSRFtoken());
         $.post("password.lp", params, function(){
           window.location = "/";
         });
      }
      else{
         window.location = "/";
      }
    }
    srp.error_message = function() {
      if(passwordStrength){
         $("#change-my-pass").text(changePassword);
         $("#erroruserpass_4").show();
         $(".control-group").addClass("error");
      }
      else{
         display_error();
      }
    }
    if(passwordStrength){
       srp.identify("/password", username, password);
    }else{
       srp.identify("/password", username, $("#srp_password")[0].value);
    }
  });
  
  $("#ask-me-again").on("click",function(a){
       a.preventDefault();
       a=$("<form>",{action:"/password.lp",method:"post"})
       .append($("<input>",{name:"action",value:"later",type:"hidden"}))
       .append($("<input>",{name:"CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content"),type:"hidden"}));
       $("body").append(a);
       a.submit();
      });
  $("#skip").on("click",function(a){
     a.preventDefault();
     a=$("<form>",{action:"/password.lp",method:"post"})
     .append($("<input>",{name:"action",value:"skip",type:"hidden"}))
     .append($("<input>",{name:"CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content"),type:"hidden"}));
     $("body").append(a);
     a.submit();
    });
})
