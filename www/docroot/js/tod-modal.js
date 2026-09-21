$(function () {
    var opt = {
      theme: 'android-ics light',
      display: 'bubble',
      mode: 'scroller',
      headerText: false,
      timeFormat: 'HH:ii',
      stepMinute: 15
    };
    $("#starttime").mobiscroll().time(opt);
    $("#stoptime").mobiscroll().time(opt);
  });
  $(".additional-edit .checkbox input").click(function() {
    if ($(this).attr("checked"))
      $(this).removeAttr("checked");
    else
      $(this).attr("checked", "checked");
  });

$("[name ='id']").change(function () {
  if ((this.value) == "custom" && (this.name) == "id") {
    $(this).replaceWith($('<input/>',{'type':'text', 'name':'id','id' : 'macAddressInput'}));
  }
});

$('.line-edit').hide();
