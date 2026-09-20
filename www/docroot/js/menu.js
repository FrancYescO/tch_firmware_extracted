var menuJson;
var source;
var userRole;
var loginRole;
$.xhrPool = [];

// When page is requested, user will be redirected last requested page
// all other request will be aborted.
function abortAll(obj) {
  $(obj).each(function(id, jqXHR) {
    jqXHR.abort();
  });
}

//Get request to be pushed into array before page is loaded
function requestCollection() {
  $.ajaxSetup({
    beforeSend: function(jqXHR) {
      $.xhrPool.push(jqXHR);
    }
  });
}
$(function() {
 loginRole=sessionStorage.getItem('loginRole');
 userRole=sessionStorage.getItem('userRole');
 $.getJSON( "menu_data.lp", function( data ) {
  menuJson=data;
  var cnt = sessionStorage.getItem('page_load_count');
  sessionStorage.setItem('apply_changes', "Y");
  var queries = {};
  $.each(document.location.search.substr(1).split('@'),function(c,q){
    if(q!=""){
      var i = q.split('=');
      queries[i[0].toString()] = i[1].toString();
    }
  });
  var title = sessionStorage.getItem('title');
  if(cnt > 0 || queries.menu){
    var menuTxt = sessionStorage.getItem('menuText');
    var link = sessionStorage.getItem('link');
    if(queries.menu){
      menuTxt=queries.menu;
    }
    if(queries.page){
     link=queries.page;
   }
   if(queries.title){
    title=queries.title;
  }
  $("#subnav-content").show();
  if (sessionStorage.getItem('modeVal')) {
    $("#top-info-mode select").val(sessionStorage.getItem('modeVal')).trigger('chosen:updated');
  }
  $('html head').find('title').text(title);
  topMenu(menuTxt, link);
  topMenuHighlight(menuTxt);
  leftMenuHighlight(link);
}
else{
  $("#overview-page").css("display", "block");
  $("#content-reset-wrap").hide();
  $("#overview-page").load("modals/overview.lp");
  $('html head').find('title').text($.trim($("#Overview").text()));
  $("#subnav-content").hide();
}
});
$(".lang-change").click(function(){
  var lang = $(this).attr('data-lang');
  var CSRFtoken = $("[name=CSRFtoken]").val();
  var params=[];
  params.push({
    name: "action",
    value: "language"
  },{
    name: "language",
    value: lang
  },{
    name: "CSRFtoken",
    value : CSRFtoken
  });
  $.post("home.lp",params, function(){});
  setCookie("webui_language", lang, 30);
  location.reload(true);
});
$('#top-info-mode #home-sel-mode').change(function() {
  var selectMode = $(this).val();
  if (selectMode == 0) {
    $("#home-form-logout").submit();
    return;
  }
  $(".button-right").addClass("hidden");
    if(selectMode == 34)
      $(".button-right").toggleClass("hidden");
  sessionStorage.setItem('modeVal', selectMode);
  var link = $('<div>').append($("ul.sub-navigation li.active").clone()).find('a').attr('data-src');
  var menuText = $('<div>').append($(".topmenu .active").clone()).find('a').attr('id');
  var subMenuMode = $('<div>').append($(".sub-navigation .active").clone()).find('a').attr('page-mode');
  var linkTxt = sessionStorage.getItem('link');
  if($.trim(menuText)=="Overview"){
    return;
  }
  if(subMenuMode <= selectMode) {
    if (selectMode != 0) {
      subMenuGenerate(menuText, link);
      leftMenuHighlight(linkTxt)
      $(".sub-navigation > ul > li > .sub-sub-navigation").addClass("hide");
      if($("ul.sub-navigation > ul > li:first-child").hasClass("active")){
        $("ul.sub-navigation > ul > li:first-child").find("ul.sub-sub-navigation").removeClass("hide");
      }
    }
  } else {
    $("#content-reset-wrap").hide();
    $("#content-reset-wrap1").show();
    $("#subnav-content").hide();
    $("#overview-page").css("display", "block");
    $("#overview-page").load("modals/overview.lp");
    $('html head').find('title').text("Overview");
    topMenuHighlight("Overview");
  }
});
$('#top-info-mode #home-sel-mobmode').change(function() {
  var menuLabel = $('<div>').append($(".menubar-ul .dropdown ").clone()).find('a.active').attr("id");
  var mobLink = sessionStorage.getItem('mobLink');
  if(menuLabel!="Overview"){
    mobileMenuGenerate(menuLabel, mobLink);
  }else{
   $("#collapseExample").removeClass("in");
 }
 $(".mac-btn-right").addClass("hidden");
   if($(this).val() == 34)
     $(".mac-btn-right").removeClass("hidden");
});
$(".logout a").click(function() {
  $("#home-form-logout").submit();
  return;
});
    // Click events for main menu navigation
    $(".topmenu > li > a").on("click mousedown", function(e){
      $("#overview-div-class, .overview-speed-div").addClass("hide");
      if ($.xhrPool.length > 0) { abortAll($.xhrPool); }
      sessionStorage.setItem('page_load_count', '1');
      var menuText = $('<div>').append($(this).clone()).find('a').attr('id');
      var link = $('<div>').append($(this).clone()).find('a').attr('data-src');
      var linkTxt = $('<div>').append($(this).clone()).find('a').text();
      if (e.which === 1) {
        $(this).attr("href","#");
        $("ul.topmenu").find("li.active").removeClass("active");
        $('ul li.sub-navigation-item').addClass("active");
        $(this).parent().addClass("active");
        if ($("#top-info-mode #home-sel-mode").val() == "35" && $.trim(menuText) == "Internet") {
          link = "modals/firewall.lp";
          linkTxt = "Firewall";
        }
        topMenu(menuText, link, linkTxt);
        if (typeof(Storage) !== "undefined") {
          sessionStorage.setItem('menuText', menuText);
          sessionStorage.setItem('link', link);
          sessionStorage.setItem('title', linkTxt);
        } else {
          console.log("Sorry! No Web Storage support..");
        }
        leftMenuHighlight(link);
        if($("#status").closest("li").hasClass("active")){
          $("ul.sub-sub-navigation").removeClass("hide");
        }
        return;
      }else{
        $(this).attr("href","?menu="+menuText+"@page="+link+"@title="+$.trim(linkTxt));
      }
    });
        //Click events for submenu navigaion
        $(document).on('click', '.sub-navigation > ul > li > a', function() {
          if ($.xhrPool.length > 0) { abortAll($.xhrPool); }
          var link = $('<div>').append($(this).clone()).find('a').attr('data-src');
          var linkTxt = $('<div>').append($(this).clone()).find('a').text();
          if (typeof(Storage) !== "undefined") {
                // Save data to sessionStorage
                sessionStorage.setItem('link', link);
                sessionStorage.setItem('page_load_count', '1');
                sessionStorage.setItem('title', linkTxt);
              } else {
                console.log("Sorry! No Web Storage support..");
              }
              $(".sub-navigation li").removeClass("active");
              $(this).parents('ul.sub-navigation li').removeClass("active");
              $(".sub-sub-navigation li").removeClass("active");
              $(".sub-navigation li").removeClass("active");
              $("ul.sub-sub-navigation").addClass("hide");
              $(this).parent().addClass("active");
              if($("a#analyser").closest("li").hasClass('active')) {
                $("a#analyser").closest("li").removeClass('active');
                $("a#analyser24").closest("li").addClass('active');
                linkTxt="2.4GHz"
              }
              else{
                $("a#analyser24").closest("li").removeClass('active');
              }
              requestCollection();
              $("#content").load(link,function() {
                $.xhrPool = [];
              });
              $('html head').find('title').text(linkTxt);
              sessionStorage.setItem('title', linkTxt);
              if($(this).closest("li.active")){
                $(this).closest("li").find("ul.sub-sub-navigation").removeClass("hide");
              }
            });

$(document).on('click', '.sub-sub-navigation > li> a', function() {
  if ($.xhrPool.length > 0) { abortAll($.xhrPool); }
  var linkTxt = $('<div>').append($(this).clone()).find('a').text();
  var link1 = $(this).attr('data-src');
  var linkId = $(this).attr('id');
  sessionStorage.setItem('title', linkTxt);
  $(this).parents('ul.sub-navigation li').removeClass("active");
  $(".sub-sub-navigation li").removeClass("active");
  $(".sub-navigation li").removeClass("active");
  $(this).parent().addClass("active");
  requestCollection();
  $("#content").load(link1, function() {
    $.xhrPool = [];
  });
  $('html head').find('title').text(linkTxt);
  if (typeof(Storage) !== "undefined") {
                // Save data to sessionStorage
                sessionStorage.setItem('page_load_count', '1');
                sessionStorage.setItem('link', link1);
                sessionStorage.setItem('linkId', linkId);
              } else {
                console.log("Sorry! No Web Storage support..");
              }
            });

    // mobile menu arrow up down Click
    $('.menubar-ul li a').on('click', function() {
      if ($.xhrPool.length > 0) { abortAll($.xhrPool); }
      var menuLabel = $('<div>').append($(this).clone()).find('a').attr('id');
      var link = $('<div>').append($(this).clone()).find('a').attr('data-src');
      sessionStorage.setItem('menuText', menuLabel);
      sessionStorage.setItem('page_load_count', '1');
      if ($.trim(menuLabel) == "Overview") {
        $("#content-reset-wrap").hide();
        $("#content-reset-wrap1").show();
        $("#subnav-content").hide();
        $("#overview-page").css("display", "block");
        $("#overview-page").load("modals/overview.lp", function() {
          $.xhrPool = [];
        });
        $("#collapseExample").removeClass("in");
        $('html head').find('title').text($.trim($('<div>').append($(this).clone()).find('a').text()));
        $(this).addClass("active");
      } else {
        $('.menubar-ul li a').removeClass("active");
        $(this).children('div').toggleClass('menu-arrow-down menu-arrow-up');
        $(this).next(".dropdown-menu").toggle();
        $(this).addClass('active');
        mobileMenuGenerate(menuLabel, link);
      }

      $('.menubar-ul li a').not($(this)).each(function() {
        $(this).next(".dropdown-menu").hide();
        $(this).children().removeClass('menu-arrow-up');
        $(this).removeClass('active');
      });
      return false;
    });
  // mobile sub menu click
  $(document).on('click', '.dropdown li a', function() {
    if ($.xhrPool.length > 0) { abortAll($.xhrPool); }
    var link = $('<div>').append($(this).clone()).find('a').attr('data-src');
    sessionStorage.setItem("mobLink", link);
    $(".dropdown li a").removeClass("active");
    $(this).addClass("active");
    $("#overview-page").css("display", "none");
    $("#content-reset-wrap").show();
    $("#content-reset-wrap1").hide();
    $("#subnav-content").show();
    $("#content").load(link, function() {
      $.xhrPool = [];
    });
    if ($('.dropdown a').children().hasClass('menu-arrow-up'))
      $('.dropdown a').children().removeClass("menu-arrow-up").addClass("menu-arrow-down");
    $("#collapseExample").removeClass("in");
    if (typeof(Storage) !== "undefined") {
      sessionStorage.setItem('page_load_count', '1');
    }
    if (typeof(Storage) !== "undefined") {
      sessionStorage.setItem('link', link);
    }
    var mobTitle = $('<div>').append($(this).clone()).find('a').text();
    $('html head').find('title').text(mobTitle);
  });
    //Mobile menu hide/show while click on body
    $("body").on("click", function(e) {
      if ($(e.target).is('div.menubar-overlay') || $(e.target).closest('div.menubar-overlay').length) {
            // do something
          } else {
            if ($(window).width() <= "980" && $(e.target).not('div#top-info-mode')) {
              if ($("#collapseExample").hasClass("in"))
                $("#collapseExample").removeClass("in");
            }
          }
        });
    // Mobile menu Close Button hide/show
    $(".menubar-close").click(function() {
      $("#collapseExample").removeClass("in");
    });

  });
var builddata = function(data, type) {
  if (type == "m")
    var mode = $('#top-info-mode select.mobile').val();
  else
    var mode = $('#top-info-mode select').val();
  var source = [];
  var items = [];
  for (i = 0; i < data.length; i++) {
    var item = data[i];
    if (mode == "33") {
      if (item.mode == "33") {
        var label = item["text"];
        var parentid = item["parentid"];
        var id = item["id"];
        var link = item["link"];
        var pageMode=item["mode"];
        var pageId=item["pid"];
      }
    } else if (mode == "34") {
      if (mode == item.mode || item.mode == "33") {
        var label = item["text"];
        var parentid = item["parentid"];
        var id = item["id"];
        var link = item["link"];
        var pageMode=item["mode"];
        var pageId=item["pid"];
      }

    } else if (mode == "35") {
      var label = item["text"];
      var parentid = item["parentid"];
      var id = item["id"];
      var link = item["link"];
      var pageMode=item["mode"];
      var pageId=item["pid"];
    }
    if (items[parentid]) {
      if (mode == "33") {
        if (item.mode == "33") {
          var item = {
            parentid: parentid,
            label: label,
            item: item,
            link: link,
            pageMode: pageMode,
            pageId: pageId
          };
        }
      } else if (mode == "34") {
        if (mode == item.mode || item.mode == "33") {
          var item = {
            parentid: parentid,
            label: label,
            item: item,
            link: link,
            pageMode: pageMode,
            pageId: pageId
          };
        }
      } else if (mode == "35") {
        var item = {
          parentid: parentid,
          label: label,
          item: item,
          link: link,
          pageMode: pageMode,
          pageId: pageId
        };
      }


      if (!items[parentid].items) {
        items[parentid].items = [];
      }
      items[parentid].items[items[parentid].items.length] = item;
      items[id] = item;
    } else {
      items[id] = {
        parentid: parentid,
        label: label,
        item: item,
        link: link,
        pageMode: pageMode,
        pageId: pageId
      };
      source[id] = items[id];
    }
  }
  return source;
}
        // Desktop ul Creation
        var buildUL = function(parent, items) {
          $.each(items, function() {
            var itmeLen = items.length - 1;
            if (this.label) {
                // create LI element and append it to the parent element.
                if (this.items && this.items.length > 0) {
                  var li = $("<li class='nav nav-item-page-alias-status sub-navigation-item navigation-item page-id-3312 subnavigation-has-sub-sub sub-sub-size-3 open'><a id='"+this.pageId+"' page-mode='" + this.pageMode + "' data-src='" + this.link + "' role='button'>" + this.label + "</a></li>");

                } else {
                  if (this.item.id == 1) {
                    var li = $("<li class='nav nav-item-page-alias-status sub-navigation-item navigation-item page-id-3312  sub-sub-size-3 open'><a id='"+this.pageId+"'  page-mode='" + this.pageMode + "' data-src='" + this.link + "' role='button'>" + this.label + "</a></li>");
                  } else {
                    if (itmeLen == 1) {
                      var li = $("<li class='nav'><a id='"+this.pageId+"' page-mode='" + this.pageMode + "' data-src='" + this.link + "' role='button'>" + this.label + "</a></li>");
                    } else {
                      var li = $("<li class='nav'><a id='"+this.pageId+"' page-mode='" + this.pageMode + "' data-src='" + this.link + "' role='button'>" + this.label + "</a></li>");
                    }
                  }
                }
                /*If logged user is Vodafone user, check if it has access to VF wifi network page.
                If the user has access, show it in the left side menu list, else hide it from the menu list.
                If logged user is admin/support, show the entire menu list*/
                if(!(loginRole =="user" && userRole.length == 0 && this.pageId =="wifi-network"))
                {
                  li.appendTo(parent);
                    // if there are sub items, call the buildUL function.
                    if (this.items && this.items.length > 0) {
                      var ul = $("<ul class='sub-sub-navigation'></ul>");
                      ul.appendTo(li);
                      buildUL(ul, this.items);

                    }
                  }
                }
              });
}
topMenu = function(menuText, link, linkTxt) {
  requestCollection();
  if ($.trim(menuText) == "Overview") {
    $("#content-reset-wrap").hide();
    $("#content-reset-wrap1").show();
    $("#subnav-content").hide();
    $("#overview-page").css("display", "block");
    $("#overview-page").load("modals/overview.lp", function() {
      $.xhrPool = [];
    });
    $('html head').find('title').text(linkTxt);
    $("#subnav-content").hide();
  } else {
    $("#overview-page").css("display", "none");
    $("#content-reset-wrap").show();
    $("#content-reset-wrap1").hide();
    $("#subnav-content").show();
    subMenuGenerate(menuText, link);
    if (typeof(Storage) !== "undefined") {
      sessionStorage.setItem('page_load_count', '1');
    } else {
      console.log("Sorry! No Web Storage support..");
    }
    $('html head').find('title').text(linkTxt);
    $("#subnav-content").show();
  }
  $(".sub-sub-navigation").addClass("hide");
}
        // Submenu Generation
        subMenuGenerate = function(menuText, link) {
          $.each(menuJson.menu, function(key, value) {
            if ($.trim(menuText) == key) {
              source = builddata(value, "");
            }
          });
          $("#overview-page").css("display", "none");
          $("#subnav-content").show();
          $("#content").empty();
          $("#content").load(link, function() {
            $.xhrPool = [];
          });
          $('.sub-navigation').empty();
          var ul = $("<ul></ul>");
          ul.appendTo(".sub-navigation");
          buildUL(ul, source);
          ShowTitleBar(link);
        }
   // Mobile Menu Generation
   mobileMenuGenerate = function(menuLabel, link) {
    requestCollection();
    if ($.trim(menuLabel) == "Overview") {
      $("#subnav-content").hide();
      $("#overview-page").css("display", "block");
      $("#overview-page").load("overview.lp", function() {
        $.xhrPool = [];
      });
      $("#collapseExample").removeClass("in");
    } else {
      $.each(menuJson.menu, function(key, value) {
        if ($.trim(menuLabel) == key) {
          source = builddata(value, "m");
        }
      });
    }
    $('.dropdown-menu').empty();
    var ul = $("<ul></ul>");
    ul.appendTo(".dropdown-menu");
    buildMobileUL(ul, source);
  }
  var buildMobileUL = function(parent, items) {
    $.each(items, function() {
      var itmeLen = items.length - 1;
      if (this.label) {
        var li = $("<li class='no-padding-left'><a data-src='" + this.link + "' role='button'>" + this.label + "</a></li>");
        if(!(loginRole =="user" && userRole.length == 0 && this.label =="VF WiFi network"))
        {
          li.appendTo(".dropdown-menu");
          if (this.items && this.items.length > 0) {
            var ul = $("<ul></ul>");
            ul.appendTo(li);
            buildMobileUL(ul, this.items);
          }
        }
      }
    });
  }
  ShowTitleBar = function(link) {
    var subMenuItems = $("#subnavigation .sub-navigation li");
    subMenuItems.each(function(idx, li) {
      var href = $(this).find('a').attr('data-src');
      if ($.trim(href) == $.trim(link)) {
        return;
      }
    });
  }
  leftMenuHighlight = function(link) {
    var subMenuItems = $("#subnavigation .sub-navigation li");
    linkId=sessionStorage.getItem('linkId');
    if(link)
      var linkValue=link.indexOf("modals/analyser");
    subMenuItems.each(function(idx, li) {
      var href;
      if(linkValue == 0)
      {
        href = $(this).find('a').attr('id');
        link=linkId;
      }
      else
      {
        href = $(this).find('a').attr('data-src');
      }
      if ($.trim(href) == $.trim(link)) {
        $("#subnavigation .sub-navigation li").removeClass("active");
        $(this).addClass("active");
        return;
      }
    });
  }
  mobSubMenuHighLight = function(link) {
    var subMenuItems = $(".dropdown-menu li");
    subMenuItems.each(function(idx, li) {
      var href = $(this).find('a').attr('data-src');
      if ($.trim(href) == $.trim(link)) {
        $(".dropdown-menu li").removeClass("active");
        $(this).children().addClass("active");
        return;
      }
    });
  }
  var topMenuHighlight = function(menuTxt) {
    var mainMenuItems = $("#navigation .topmenu li");
    mainMenuItems.each(function(idx, li) {
      var topLable = $(this).find('a').attr('id');
      if ($.trim(topLable) == $.trim(menuTxt)) {
        $("#navigation .topmenu li").removeClass("active");
        $(this).addClass("active");
        return;
      }
    });
  }
  var applyChangesWarningShow = function() {
    $(".articlediv > .msg-error").removeClass("show").addClass("hide");
    $(".articlediv").removeClass("hide").addClass("show");
    $(".articlediv > .msg-warning").removeClass("hide").addClass("show");
  }
  var applyChangesWarningHide = function() {
    $(".msg-warning").removeClass("show").addClass("hide");
    $(".articlediv").removeClass("show").addClass("hide");
  }
  function setCookie(name,value,days) {
    if (days) {
     var date = new Date();
     date.setTime(date.getTime()+(days*24*60*60*1000));
     var expires = "; expires="+date.toGMTString();
   }
   else var expires = "";
   document.cookie = name+"="+value+expires+"; path=/";
 }
