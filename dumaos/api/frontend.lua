LuaQ                     A@   E     \@ E   ΐ  \@ E     \    Κ   $      $A       $  dΑ     @          require 	   template    libtranslator    libos    json    parse    launch    get_client_code           2    S     ΖA@  ΕΑ   ά BACWΑ@WΐΑΐ W Β@ @Β@ΒΕΒ  Γ ά B  ΐ
 Γ@	B CΑΒ  AC  ΖΓD     W EΕB ΖΕ  AΓ άΪ  Ε   AC άBΚ  @@Δ  ΖΖ  ά ΖΒΖFΗΖΒΓ  AC  άB  ΐ  ΑΒ  BΒΕΒ   ά B  B ΖΘC@FC@FCΑΐ  ά B    #   
   assertion    root    No root page    require    translator    type    android    ios    tab-android    tab-ios    register_gui_objects    translators.f7    desktop    os    get_cmd_output /    %s -p /dumaos/apps/system/%s rpc %s "['%s']"     /dumaos/api/exec.lua    com.netdumasoftware.desktop    get_package_pinned_panels    package        string    find    null    warning F   could not get panels probably because desktop backend is not running.    decode    result 	      translators.desktop 
   exception    Unknown platform '%s'    translators.generic    print 
   translate                     4   J    ,    AΕ  B@ @ ά ΑΑΐΖA ΑΕ ΖΑΑ ά ΑΓW@Β@WΒΐ WΐΒ@  Γ@ ΑA ΐΓ@ ΑΑ ΐ  AB B D  FΒΔΐ \B       	   platform    name    internationalise_text    index    package    translations    table 
   to_string    country    android    ios    tab-android    tab-ios    /dumaos/api/templates/f7.html    desktop #   /dumaos/api/templates/desktop.html 
   exception    Unknown platform '%s'    print    compile_file                     L   T        E      \   ΖAΐ Ζ@ΐΐ@ ΖAή ‘   ώa  ό        ipairs 	   bindings    event    init    func                     V   {    S   @A      A  [  F@Z  @ F@FΐΑ  AA  F@FΑA AΑ BAA @@ 
  E FΑΒ ΕΑ ΖΒ ά \A  EA C Ε  \ ZA  ΐ Α Α B A ΑBΐ  A ΑBΐ Β BA Β Δ  @Aά ΪB    Γ Ε ΖΕ@ά   A  A Ε  ΒE@  AB άA          controller 
   assertion    source    No controller.source property    bind    No controller bindings array.    file    string    format    %s.lua    table    insert J       local api = require "translator"
    api.remote = require "remote"
   	   get_code 
   parentdir 
   exception (   Unable to load client code because '%s'    e ι       _on_page_init = %s
    local bindings = %s
    for _, object in ipairs(bindings.bind) do
      for _, binding in ipairs(object.bindings) do
        translator.bind(object.id, binding.event, _G[binding.func])
      end
    end
   	   tostring 
   to_string    print    script    concat    
    application/lua                             