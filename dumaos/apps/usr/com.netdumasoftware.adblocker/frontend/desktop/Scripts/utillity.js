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

var _time_ago_strings = {
  hours: "<%= i18n.hoursFormat %>",
  minutes: "<%= i18n.minutesFormat %>",
  seconds: "<%= i18n.secondsFormat %>",
  hoursAndMinutes: "<%= i18n.hoursAndMinutesFormat %>",
  minutesAndSeconds: "<%= i18n.minutesAndSecondsFormat %>",
}
var _time_ago_strings_long = {
  hours: "<%= i18n.hoursFormat_long %>",
  minutes: "<%= i18n.minutesFormat_long %>",
  seconds: "<%= i18n.secondsFormat_long %>",
  hoursAndMinutes: "<%= i18n.hoursAndMinutesFormat_long %>",
  minutesAndSeconds: "<%= i18n.minutesAndSecondsFormat_long %>",
}
function FormatTimeAgo(secondsAgo, addAgo = false, long = false)
{
  secondsAgo = Math.round(secondsAgo);

  var strings = long ? _time_ago_strings_long : _time_ago_strings;
  
  if (secondsAgo == 0)
    return "<%= i18n.now %>";

  var minsAgo = Math.floor(secondsAgo / 60);
  var hoursAgo = Math.floor(minsAgo / 60);
  var remainingSecondsAgo = Math.round(secondsAgo - (minsAgo * 60));
  var remainingMinsAgo = minsAgo - (hoursAgo * 60);

  var outputString = "";

  if (hoursAgo > 0)
  {
    outputString = remainingMinsAgo != 0 ? strings.hoursAndMinutes.format(hoursAgo,remainingMinsAgo) : strings.hours.format(hoursAgo);
  }
  else if (remainingMinsAgo > 0)
  {
    outputString = remainingSecondsAgo != 0 ?  strings.minutesAndSeconds.format(remainingMinsAgo,remainingSecondsAgo) : strings.minutes.format(remainingMinsAgo);
  }
  else
    outputString = strings.seconds.format(remainingSecondsAgo);
  
  if (addAgo)
    outputString = "<%= i18n.timeAgo %>".format(outputString);

  return outputString;
}
