var bIE10=false;
var anchorFound=false;
var settingsLoaded=false;
var sLoaded=false;
var requestedAnchor='';
var requestedFile='';
var stepCounter0=1;
var stepCounter1=1;
var stepCounter2=1;
var requestedId_array=new Array();
var level_array=new Array();
level_array['chapter']=0;
level_array['section']=1;
level_array['map']=2;
var book_xml;
var progressTimer;
var userVariables=[
		["1-productname01",strings_array["PRODUCT_NAME"]],
		["1-productname02",'Technicolor TG'],
		["2-companyname01",'Technicolor'],
		["2-customer01",'Telstra'],
		["7-devicenumber01",'799vac'],
		["a-icon-upload",'<span class="icon">&#xf01b;</span>'],
		["a-icon-download",'<span class="icon">&#xf01a;</span>'],
		["a-button-add",'<span class="icon">&#xf055;</span> (add)'],
		["a-button-apply",'<span class="icon">&#xf00c;</span> (apply)'],
		["a-button-edit",'<span class="icon">&#xf044;</span> (edit)'],
		["a-button-cancel",'<span class="icon">&#xf00d;</span> (cancel)']
	];
	

if(typeof String.prototype.trim !== 'function') {
  String.prototype.trim = function() {
    return this.replace(/^\s+|\s+$/g, ''); 
  }
}
	
	
	
function getVariable(variableName) {
	for (var i=0;i<userVariables.length;i++) {
		if (userVariables[i][0]==variableName)
			return userVariables[i][1];
	}
	return variableName;
}

function init() {	
	document.title=strings_array["WINDOW_TITLE"]
	requestedAnchor=getUrlParameter('anchor');	
	requestedFile=decodeURI(getUrlParameter('file')).replace('xml/','');
	if ((requestedAnchor=='') && (requestedFile==''))
		requestedAnchor='gateway';
	loadDataXml();
}

function displayProgressBar() {
	progressTimer = setTimeout('progress_update()',500);
}
		
function getFileName() {
	var url = document.location.href;
	url = url.substring(0, (url.indexOf("#") == -1) ? url.length : url.indexOf("#"));
	url = url.substring(0, (url.indexOf("?") == -1) ? url.length : url.indexOf("?"));
	url = url.substring(url.lastIndexOf("/") + 1, url.length);
	return url;
}
		
function progress_update() {
document.title+=document.title;
	try {
		
		document.getElementById('progress').setAttribute("width",Number(document.getElementById('progress').width)+100);
		progressTimer = setTimeout('progress_update()',500);
		if (Number(document.getElementById('progress').width)>=400)
			clearTimeout(progressTimer );
	} catch(err) {document.title+='err';
		progressTimer = setTimeout('progress_update()',500);
	}
}

	


function getUrlParameter(input_str) {
	var output_str='';
	if (location.search.indexOf(input_str+'=')!=-1) {
		output_str=location.search.substr(location.search.indexOf(input_str+'=')+input_str.length+1);
		output_str=output_str.split("&")[0]
	}
	return output_str;
	
	
}


//******************************************************************************************************************************************************
//******************************************************************* TOC *****************************************************************************
//******************************************************************************************************************************************************
function loadDataXml() {
	var data_xml = loadXMLDoc("xml/data.xml");
	processDataXml(data_xml);
}

function processDataXml(input_xml) {
	var toc_xml;
	book_xml=getNode(input_xml,"data/book");
	var requested_xml;
	if (requestedFile=='') {
		var xpath_str="//*[@anchors='"+requestedAnchor+"']";
		requested_xml=getNode(input_xml,xpath_str);
		requestedFile=requested_xml.getAttribute('location');
	} else {
		var xpath_str="//*[@location='"+requestedFile+"']";
		requested_xml=getNode(input_xml,xpath_str);
	}
	while (requested_xml.tagName!='book') {
		requestedId_array.splice(0,0,requested_xml.getAttribute('id'));
		requested_xml=requested_xml.parentNode;
	}
	document.getElementById("toc").innerHTML='<a class="icon-menu" href="javascript:toggleMenu()"></a><div id="menu">'+writeTOC(book_xml,'chapter')+'</div>';
	loadContentXml('xml/'+requestedFile);
	writeCopyright();
}

function toggleMenu() {
	if (document.getElementById("menu").className != "expanded")
		document.getElementById("menu").className = "expanded";
	else
		document.getElementById("menu").className = "collapsed";
}

function collapseMenu() {
	document.getElementById("menu").style.display = "none";
}

function sectionContainsAnchor(input_xml,targetAnchor) {
	var fileName_str=getFileName();
	if ((fileName_str.charAt(0)=='e')&&(targetAnchor!='home')) {
		var location_str=getAttributeValue(input_xml,"location");
		if (location_str.charAt(0)=='b') {
			return false;
		}
	}
	
	var anchor_str=','+getAttributeValue(input_xml,"anchors").replace(/, /g,',')+",";
	if (anchor_str.indexOf(','+targetAnchor+',')>-1) 
		return true;
	else
		return false;
}

function getChildNode(input_xml,input_str) {
	for (var i=0;i<input_xml.childNodes.length;i++) {
		
		if (input_xml.childNodes[i].nodeName==input_str)
			return input_xml.childNodes[i];
	}
	return null;
}


function writeTOC(chapter_xml,name_str) {
	var code='';
	var xml_array=chapter_xml.getElementsByTagName(name_str);
	var level;
	switch(name_str) {
		case 'chapter':
			level=0;
			break;
		case 'section':
			level=1;
			break;
		case 'map':
			level=2;
	}
	for (var i=0;i<xml_array.length;i++) {
		var item_xml=xml_array[i].getElementsByTagName('title')[0];
		var location_str=xml_array[i].getAttribute('location');
		var label_str=ProcessContentXml(item_xml);
		var inner_str;
		if (xml_array[i].getAttribute('id')==requestedId_array[level]) {
			var class_str;
			if (requestedId_array.length-1==level) {
				code+='<li class="selected">';
			} else {
				code+='<li class="open">';
			}
			code+='<a href="?file=xml/'+location_str+'">'+label_str+'</a>';
			switch(name_str) {
				case 'chapter':
					code+=writeTOC(xml_array[i],'section');
					break;
				case 'section':
					code+=writeTOC(xml_array[i],'map');
					break;
			}
		} else {
			if (level==0)
				code+='<li><a href="?file=xml/'+location_str+'">'+label_str+'</a>';
			else
				code+='<li><a href="?file=xml/'+location_str+'">'+label_str+'</a>';
		}
			code+='</li>';
	}
	if (code!='') {
		code='<ul>'+code+'</ul>';
	}
	return code;
}



function getNode(input_xml,xpath_str) {	
	if (window.ActiveXObject || bIE10==true)
	{
		input_xml.setProperty("SelectionLanguage","XPath");
		return input_xml.selectNodes(xpath_str)[0];
	}
	// code for Chrome, Firefox, Opera, etc.
	else if (document.implementation && document.implementation.createDocument)
	{
		var nodes=input_xml.evaluate(xpath_str, input_xml, null, XPathResult.ANY_TYPE, null);
		return nodes.iterateNext();
	}
}

function getAttributeValue(inputNode,attributeName) {
	var output="";
	try {
		output=inputNode.attributes.getNamedItem(attributeName).value;
	} catch(err) {}
	return output
}

function loadContentXml(xmlFile) {
	if (window.XMLHttpRequest) {
		var xmlhttp=new XMLHttpRequest();
	} else {
		// Internet Explorer 5/6
		var xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}
	xmlhttp.open("GET",xmlFile,false);
	xmlhttp.send(null);
	var content_xml = xmlhttp.responseXML.documentElement;
	document.getElementById("content").innerHTML=ProcessContentXml(content_xml);
	//fillSubMenuList();
}

function resetStepCounter(level) {
	switch (level) {
		case 0:
			stepCounter0=1;
		case 1:
			stepCounter1=1;
		case 2:
			stepCounter2=1;
			break;
	}
}

function ProcessContentXml(input_xml) {
	var currentElement;
	var text='';
	if(input_xml==null)
		return ""
	for (var i=0;i<input_xml.childNodes.length;i++) {
		currentElement=input_xml.childNodes[i];
		var content=ProcessContentXml(currentElement);
		var contentIsEmpty=false;
		if (content.replace(/\s/g,'').length==0)
			contentIsEmpty=true
		if (currentElement.nodeType==1) {
			var nodeName=currentElement.nodeName.toLowerCase();
			switch(nodeName) {
				case "br":
					text+="<br />"
					break;
				case "cond":
					if (showChildren(currentElement))
						text+=content;
					break;
				case "a":
					text+='<a name="'+getAttributeValue(currentElement,"name")+'"></a>';
					break;
				case "link":
					if (contentIsEmpty==false)
						text+='<a href="' + indexFile + '?file=' + getAttributeValue(currentElement,"href") + '">' + content + '</a>';
					break;
				case "note":
					if(currentElement.ownerDocument.firstChild.nodeName=='data')
						break;
					if (contentIsEmpty==false)
						text+='<table class="note" cellspacing="0"><tr><td width="30"><p><span class="icon">&#xf05a;</span></p></td><td>'+content+'</td><tr></table>';
					break;
				case "warning":
				case "caution":
				case "danger":
					if(currentElement.ownerDocument.firstChild.nodeName=='data')
						break;
					if (contentIsEmpty==false)
						text+='<table class="note" cellspacing="0"><tr><td width="30"><p><span class="icon">&#xf06a;</span></p></td><td>'+content+'</td><tr></table>';
					break;
				case "step1":
					if (contentIsEmpty==false)
						text+=writeStructureTable(stepCounter0++, content,1);
					break;
				case "step2":
					if (contentIsEmpty==false)
						text+=writeStructureTable(stepCounter1++, content,2);
					break;
				case "step3":
					if (contentIsEmpty==false)
						text+=writeStructureTable(stepCounter2++, content,3);
					break;
				case "li1":
				case "li2":	
				case "li3":	
					if (contentIsEmpty==false)
						text+=writeStructureTable('<div class="bullet'+ nodeName.replace('li','')  +'" />', content,nodeName.substr(nodeName.length-1));
					break;
				case "indent1":
					if (contentIsEmpty==false)
						text+='<table class="structure" cellspacing="0"><tr><td width="15"><p>&nbsp;</p></td><td><p>'+content+'</p></td></tr></table>';
					break;
				case "indent2":
					if (contentIsEmpty==false)
						text+='<table class="structure" cellspacing="0"><tr><td width="30">&nbsp;</td><td><p>'+content+'</p></td></tr></table>';
					break;	
				//CHARACTER STYLES
				case "var":
					var varname_str=currentElement.attributes.getNamedItem("name").value;
					if (varname_str=='_menutoc_') {
						text+='<span id="subMenuList">&nbsp;</span>';
					/*} else if (varname_str.indexOf('a-')==0) {
						text+='<span class="icon '+varname_str.substr(2)+'"></span>';*/
					} else {
						text+=getVariable(varname_str);
					}
					break;
				case "img":
					text+='<img src="../img/'+getAttributeValue(currentElement,"src")+'">'
					break;
				case "table":
					text+='<'+currentElement.nodeName.toLowerCase()+writeAttributes(currentElement)+' cellspacing="0">'+content+'</'+currentElement.nodeName.toLowerCase()+'>';
					break;
				//PARAGRAPH STYLES
				case "h1":
				case "h2":
				case "h3":
				case "h4":
					resetStepCounter(0);
					text+='<'+currentElement.nodeName.toLowerCase()+writeAttributes(currentElement)+'>'+content+'</'+currentElement.nodeName.toLowerCase()+'>';
					break;
				case "p":
					if (input_xml.nodeName!='note' && input_xml.nodeName!='warning' && input_xml.nodeName!='table')
						resetStepCounter(0);
					if (content.trim()=='') {
						break;
					}
				default:
					var output=content;
					if (output.length>0)
						text+='<'+currentElement.nodeName.toLowerCase()+writeAttributes(currentElement)+'>'+output+'</'+currentElement.nodeName.toLowerCase()+'>';
			}
		} else if (currentElement.nodeType==3) {
			text+=currentElement.nodeValue;
		}
	}
	return text;
}

function writeStructureTable(leftColumnContent, rightColumnContent,level) {
	var code=""
	code+='<table class="structure" cellspacing="0"><tr>';
	for (var i=1;i<level;i++) {
		code+='<td width="15" class="stepno"><p>&nbsp;</p></td>';
	}
	code+='<td width="15" class="stepno"><p>'+ leftColumnContent +'</p></td>';
	code+='<td><p>'+rightColumnContent+'</p></td>';
	code+='</tr></table>';
	resetStepCounter(level);
	return code;
}

function writeAttributes(input_xml) {
	var attribute_str='';
	for (var i=0;i<input_xml.attributes.length;i++) {
		attribute_str=' '+input_xml.attributes[0].name+'="'+input_xml.attributes[0].value+'"';
	}
	return attribute_str;
}

function showChildren(inputXml) {
	var output=false;
	if (conditionTags.length==0)
		return true;
	else {
		output=false;
		var condOfElement=inputXml.attributes.getNamedItem("show").value;
		if (condOfElement.indexOf('#')>-1) {
			condOfElement=condOfElement.substring(1,condOfElement.length-1);
			for (var i=0;i<forbiddenAnchors.length;i++) {
				if (forbiddenAnchors[i]==condOfElement)
					return false;
			}
			return true;
		}
		for (var i=0;i<conditionTags.length;i++) {
			if (conditionTags[i]==condOfElement)
				return true;
		}
	}		
	return output;
}

function getRequestedAnchor() {
	var query_str=location.search.substring(1);
	return query_str.split('=')[1];
}

function getCorrespondingAnchorFromFile(fileName) {
	var result;
	fileName=fileName.substr(fileName.lastIndexOf("/")+1)
	var node_xml=getElementWithAttribute(book_xml,fileName);
	while ((getAttributeValue(node_xml,"anchors")=='') && (node_xml.nodeName!='chapter')) {
		node_xml=node_xml.parentNode
	}
	if (getAttributeValue(node_xml,"anchors")!='') {
		return getAttributeValue(node_xml,"anchors").split(',')[0];
	}
	else {
		for (var i=0;i<node_xml.childNodes.length;i++) {
		//try to find the anchor in the other sections
			if (getAttributeValue(node_xml.childNodes[i],"anchors")!='') {
				return getAttributeValue(node_xml.childNodes[i],"anchors");

			}
		}
	}
	return ''
}

function getElementWithAttribute(input_xml,search_str) {
	for (var i=0;i<input_xml.childNodes.length;i++) {
		if (input_xml.childNodes[i].nodeType==1) {
			if (getAttributeValue(input_xml.childNodes[i],"location")==search_str) {
				return input_xml.childNodes[i];
			} else if (input_xml.childNodes[i].hasChildNodes()) {
				var result=null;
				result=getElementWithAttribute(input_xml.childNodes[i],search_str)
				if (result!=null)
					return result;
			}
		}					
	}
	return null;
}

function writeCopyright() {
	document.getElementById("footer").innerHTML='<iframe height="120" src ="footer.html" width="100%" frameborder="0" scrolling="no" align="bottom" marginheight="0" > </iframe>';
}
function loadXMLDoc(dname)
{
	if (window.XMLHttpRequest)
	  {
		xhttp=new XMLHttpRequest();
	  }
	else
	  {
		xhttp=new ActiveXObject("Microsoft.XMLHTTP");
	  }
	xhttp.open("GET",dname,false);
	try {xhttp.responseType="msxml-document"} catch(err) {} // Helping IE
	if (xhttp.responseType=="msxml-document") {
		bIE10=true;
	}
	xhttp.send("");
	return xhttp.responseXML;
}
