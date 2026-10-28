// This is the function for displaying Empty Table's default Value(NA)
function tableCreate(id){
  var count = $(id).length;
  $("tbody:empty").append($('<tr></tr>'))
  var tableDataAppend
  for (var i = 1; i <= count ; i++) {
    tableDataAppend += '<td></td>'
  }
  $("tr:empty").append(tableDataAppend)
  $("td:empty").addClass('pingroute')
  $(".pingroute").text("NA")
}
tableCreate("#pingtrace th")
tableCreate("#routehops th")

