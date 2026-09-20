function setCookie(name,value,days) {
    if (days) {
       var date = new Date();
       date.setTime(date.getTime()+(days*24*60*60*1000));
       var expires = "; expires="+date.toGMTString();
    }
    else var expires = "";
        document.cookie = name+"="+value+expires+"; path=/";
}

function lang_change(param){
    setCookie("webui_language", param, 30);
    location.reload(true);
}

