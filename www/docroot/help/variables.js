//*********************** GLOBAL VARIABLES ***********************
var year=new Date().getFullYear();
var build='<!-- #echo var="_BUILD"-->';
var release=build.slice(0,build.lastIndexOf('.'));
var prodName='Technicolor';
var prodNumber='TG799vac';
var prodFriendlyName='Modem';
var variantFriendlyName='<!-- #echo var="_VARIANT_FRIENDLY_NAME"-->';
var buildVariant='<!-- #echo var="_BUILDVARIANT"-->';
var boardName='<!-- #echo var="_BOARD_NAME"-->';
var companyName='Technicolor';
var copyright='Copyright '+year+' Technicolor';
var voiceType='<!-- #echo var="_VOIP_TYPE"-->';
var ssidPrefix='<!-- #echo var="_SSID_SERIAL_PREFIX"-->';

//*********************** STRINGS ***********************
var strings_array=new Array();
strings_array["LOADING"]='Loading content...';
strings_array["PRODUCT_NAME"]=prodFriendlyName;
strings_array["WINDOW_TITLE"]='Telstra Modem Advanced View Help';
strings_array["TG_MENU_LABEL"]=prodFriendlyName;
strings_array["GUI_NAME"]='_BRAND_NAME Web Interface';
