var duma = duma || {};
duma.applications = duma.applications || {};

duma.devices.get_application_icon_path = function(file) {
  return "duma-application-icons:" + file;
}

duma.applications.type_to_application_icons_array =  {
  categories: duma.devices.get_application_icon_path("categories"),
  "file sharing": duma.devices.get_application_icon_path("fileshare"),
  gaming: duma.devices.get_application_icon_path("gaming"),
  livestream: duma.devices.get_application_icon_path("livestream"),
  media: duma.devices.get_application_icon_path("media"),
  "chat & messaging": duma.devices.get_application_icon_path("messaging"),
  uncategorised: duma.devices.get_application_icon_path("other"),
  voip: duma.devices.get_application_icon_path("voip"),
  vpn: duma.devices.get_application_icon_path("vpn"),
  "web (general)": duma.devices.get_application_icon_path("web"),
};

duma.applications.get_application_icon = function(type)
{
  if(typeof type !== "string") return null;
  return duma.applications.type_to_application_icons_array[type.toLowerCase()] || null; //duma.devices.type_to_device_icons_array.other;
}
