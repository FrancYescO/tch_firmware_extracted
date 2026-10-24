function setCookie(name,value,days) {
    if (days) {
       var date = new Date();
       date.setTime(date.getTime()+(days*24*60*60*1000));
       var expires = "; expires="+date.toGMTString();
    }
    else var expires = "";
        document.cookie = name+"="+value+expires+"; path=/";
}

function lang_change(param, page) {
  //This check is done only when browser is closed/tabs are closed
  if (page === "login") {
    //Set the webui language cookie to spanish when the Login page is loaded
    if (param) {
      setCookie("webui_language", param, 30);
    }else{
      setCookie("webui_language", "spn", 30);
    }
    //The pageLoaded variable is set to true throughout session
    //Avoids setting the cookie to spanish again in case english was selected in the same session
    sessionStorage.setItem("pageLoaded", "true");
  } else {
    //Set the webui language cookie to english/spanish based on type of language selected
    setCookie("webui_language", param, 30);
    //The langCode variable is set to the language code(eg:en-us, spn)
    sessionStorage.setItem("langCode", param);
    //In case user clears all cookies from browser, the pageLoaded session variable need to be removed
    sessionStorage.removeItem("pageLoaded");
  }
  location.reload(true);
}

