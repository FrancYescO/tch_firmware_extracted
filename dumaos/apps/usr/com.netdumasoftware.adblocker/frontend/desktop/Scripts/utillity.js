// File wide helper methods
var units   = [ '',   'K',   'M',   'B',   'T'];

// Returns [bytes = value in unit, unit = unit index for list above]
function GetUnits(bytes, multi=1000)
{
  var unit = 0;
  while (bytes >= multi)
  {
    bytes /= multi;
    unit++;
  }

  return [bytes, unit];
}

function FormatUnits(bytes,multi=1000)
{
  var unit = GetUnits(bytes, multi);
  // Display bytes as int while kb and above return 1dp
  return (Math.round(unit[0] * 10) / 10).toString() + ((unit[1] == 0) ? "" : units[unit[1]]);
}

function AddThousandsSeparators(value)
{
  return value.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1,'); //add decimal points
}

function FormatTimeAgo(secondsAgo, addAgo = false)
{
  secondsAgo = Math.round(secondsAgo);
  
  if (secondsAgo == 0)
    return "Now";

  var minsAgo = Math.floor(secondsAgo / 60);
  var hoursAgo = Math.floor(minsAgo / 60);
  var remainingSecondsAgo = Math.round(secondsAgo - (minsAgo * 60));
  var remainingMinsAgo = minsAgo - (hoursAgo * 60);

  var outputString = "";

  if (hoursAgo > 0)
  {
    outputString = hoursAgo + "h";
    if (remainingMinsAgo != 0)
      outputString += " " + remainingMinsAgo + "m";
  }
  else if (remainingMinsAgo > 0)
  {
    outputString = remainingMinsAgo + "m";
    if (remainingSecondsAgo != 0)
      outputString += " " + remainingSecondsAgo + "s";
  }
  else
    outputString = remainingSecondsAgo + "s";
  
  if (addAgo)
    outputString += " Ago";

  return outputString;
}
