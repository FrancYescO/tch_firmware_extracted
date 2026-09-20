var duma = duma || {};
duma.applications = duma.applications || {};

duma.applications.get_application_icon_path = function(file) {
  return "duma-application-icons:" + file;
}

duma.applications.type_to_application_icons_array =  {
  categories: duma.applications.get_application_icon_path("categories"),
  "file sharing": duma.applications.get_application_icon_path("fileshare"),
  gaming: duma.applications.get_application_icon_path("gaming"),
  livestream: duma.applications.get_application_icon_path("livestream"),
  media: duma.applications.get_application_icon_path("media"),
  "chat & messaging": duma.applications.get_application_icon_path("messaging"),
  uncategorized: duma.applications.get_application_icon_path("other"),
  voip: duma.applications.get_application_icon_path("voip"),
  vpn: duma.applications.get_application_icon_path("vpn"),
  "web (general)": duma.applications.get_application_icon_path("web"),
  "cloud gaming": duma.applications.get_application_icon_path("cloud_gaming"),
  "workathome": duma.applications.get_application_icon_path("work_from_home"),
};

duma.applications.get_application_icon = function(type)
{
  if(typeof type !== "string") return null;
  return duma.applications.type_to_application_icons_array[type.toLowerCase()] || duma.applications.type_to_application_icons_array.uncategorized; //duma.devices.type_to_device_icons_array.other;
}
