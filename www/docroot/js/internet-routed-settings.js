$("#interface").change(function(){
  var params = [];
  var intf = $(this).val();
    params.push({
      name : "interface",
      value : intf
    },
    {
      name : "CSRFtoken",
      value : getCSRFtoken
    },
    {
      name  : "action",
      value :  "SELECT"
    }
    );
  $.post($("#interface-form").attr("action"),params);
});

var target = $(".modal form").attr("action");

$("#btn-dhcp-release-renew").click(function() {
  $.post(target, { CSRFtoken:$("meta[name=CSRFtoken]").attr("content"), action:"ReleaseAndRenew"})
})
