// File wide helper methods
var units   = [ 'B',   'KB',   'MB',   'GB',   'TB',   'PB',   'EB',   'ZB',   'YB' ];
var unitsPS = [ 'bps', 'kbps', 'mbps', 'gbps', 'tbps', 'pbps', 'ebps', 'zbps', 'ybps']

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

function FormatBytes(bytes,multi=1000)
{
  var unit = GetUnits(bytes, multi);
  // Display bytes as int while kb and above return 1dp
  return ((unit[1] == 0) ? unit[0] : unit[0].toFixed(1)) + unitsPS[unit[1]];
}

function GetNetflixRating(speed)
{
  // Netflix rating, numbers based off netflix support website for each minimal speed
  var netflixRating = "-";
  if (speed > 25000)
    netflixRating = "<%= i18n.ultraHD %>";
  else if (speed > 5000)
    netflixRating = "<%= i18n.HD %>";
  else if (speed > 3000)
    netflixRating = "<%= i18n.SD %>";
  else
    netflixRating = "<%= i18n.insufficient %>";

  return netflixRating;
}
