//*********************** CONDITIONS ***********************
var conditionTags=new Array();
if (voiceType.indexOf('SIP')>-1)
	conditionTags=['RES','VoIP','VoIP-SIP']
else if (voiceType.indexOf('MGCP')>-1)
	conditionTags=['RES','VoIP','VoIP-MGCP']
else
	conditionTags=['RES']