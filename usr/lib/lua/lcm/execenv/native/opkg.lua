LuaQ 
   @opkg.lua           0      A@   E  Fΐΐ    AΕ@  ΑAE FΒ  ΑA  Ε   ά Β J  IB€     δB              IΒδ          $Γ      d    IBdC    IBJ  €   I^         require     lcm.execenv.native.opkg_package    io    lines    popen    ipairs    table    concat    insert    tch.process    tch.logger 	   .control    __index    list    install 
   uninstall    new           "    
!      Δ   @ ά ΛA@A  άΪA  ΐZ@  @ Κ  @ Τ ΜΑΐI@Z   ΐ Τ ΜΑΐ@C  α@  ϊZ    Τ  Μΐΐ@          status_file_path    match    ^%s*$ 	       !                                                                                                !   "         self         
   paragraph            paragraphs           (for generator)          (for state)          (for control)          line             lines     $   3    %   F @    Δ    @   ά    B@@ @ @ΔUΒΒ  AΐC   ΛAάB Δ ΖΒΑ  @άBΤ ΜΒ α   ω    	      package_info_path    new_package    Package    io    open    r    close    update_package 	       %   %   &   '   '   '   '   '   '   (   (   (   (   *   *   *   *   +   +   +   +   +   ,   ,   -   -   .   .   .   .   .   0   0   0   '   0   2   3         self     $      package_info_path    $   	   packages    $      (for generator)    #      (for state)    #      (for control)    #      _    !   
   paragraph    !      opkg_package    !      control_filename    !      control_file    !         ipairs    get_status_paragraphs    opkg_package_module    control_extension     5   B    /       @A  @   ΐ   @    ΐ@ΐ     A  Κ   AAΐAΙΐ  @Β ΐB !A  @ύ  @ ΛABά A   @ D ΑΑ \            debug    exec: %s(%s)    ,    popen    re    lines 	      rcv: %s    result: %d    close 	       
     /   6   6   6   6   6   6   6   6   6   7   7   7   7   7   7   8   9   9   9   :   :   :   ;   ;   ;   ;   ;   9   ;   =   =   =   =   =   =   >   >   >   ?   ?   ?   ?   ?   ?   A   A   B         cmd     .      args     .      f    .      output    .      (for generator)          (for state)          (for control)          line             logger    concat    process     D   N    	$     @  ΑA  @ ΥA   @  ΑΑ  A   @  Α A   @ A  @ AAA AΑ ΐΑ  ΐ         	      --offline-root=    install_root    --verbosity=0    --force-depends    env 
   exec_args 
   /bin/opkg     $   F   F   F   F   F   F   F   G   G   G   G   G   H   H   H   H   H   J   J   J   J   K   K   K   K   L   L   L   L   L   M   M   M   M   M   N         self     #      action     #      info     #      args     #   	   exec_cmd    #      argv    #         insert    run_cmd     P   R    	      ΐ     FAΐ  Α  Β  ’A             install 	   ipk_path 	   --nodeps    --force-downgrade        Q   Q   Q   Q   Q   Q   Q   Q   Q   Q   R         self     
      ipk     
         opkg_action     T   V    
      ΐ     @  ΑA  ’A             remove    --force-remove     
   U   U   U   U   U   U   U   U   U   V         self     	      name     	         opkg_action     Z   b           Λΐ @  Α  UάΐΛΐ @  A Uάΐ @ Εΐ   D  έ ή           install_root    package_info_path    nativePath    usr/lib/opkg/info/    status_file_path    usr/lib/opkg/status    env    setmetatable        [   \   ]   ]   ]   ]   ]   ]   ^   ^   ^   ^   ^   ^   _   a   a   a   a   a   b         install_root           environment           self             Opkg 0                                                         	         "   "   3   3   3   3   3   $   B   B   B   B   N   N   N   R   R   P   V   V   T   X   b   b   b   d   d         opkg_package_module    /      lines    /      popen    /      ipairs    /      concat    /      insert    /      process    /      logger    /      control_extension    /      Opkg    /      get_status_paragraphs    /      run_cmd !   /      opkg_action $   /      M +   /       