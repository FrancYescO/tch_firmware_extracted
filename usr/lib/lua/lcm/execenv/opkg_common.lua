LuaQ    @opkg_common.lua           m      A@   E  À  Å  A E FÁÁ BÅA ÆÂ  AÂ  CE  B \   Á  Å  Ã Ü ÆÄ  AC  E   \   ÁÃ  Ê  ÉÃ$    dD              ¤    äÄ        	ÉÃä $E     	d             
      	ÉCdÅ ¤ äE          
$      dÆ   ÉCd   ÉCdF ÉC@  ÊF  ÉÆF\¤         äÆ    ÉÃä    
ÉÃäF      ÉÃÊ  $           ÉÞ          require    io    type    ipairs    setmetatable 	   tonumber    string    match    format    os    rename    tch.process    popen    lcm.execenv.native.ipk    lcm.execenv.native.opkg    lfs    attributes 	   lcm.ubus    lcm.errorcodes    lcm.execenv.native.execmon    __index    list    install    start    stop 
   uninstall    __mode    k 
   executing    inspect    notify    init        !   +       Z@       @ Á@     Æ@ ËÀÀ@ Ü  @ A        @        rootfs    etc/init.d/    env    nativePath    ino        "   "   #   %   %   %   %   &   &   &   &   '   '   '   '   '   '   (   *   *   *   +         self        	   pkg_name           init_script          script_file             attribs     -   @    5   Ä      @ ÜÚ@  @   @ A@Ê   âA Á  À  A   Ã   KÂ@Á \ÀKBA\    @D  \ Z   D  \ @@CÁÂ   @ C   ^    	      env 
   exec_args    r    read    *a    close 	    )   initscript failed for %s (action=%s): %s    (no error message)     5   1   1   1   1   2   2   3   3   5   5   5   5   5   5   5   6   6   6   6   6   7   8   8   9   9   9   9   :   :   :   <   <   <   <   <   <   <   <   <   <   <   <   =   =   =   =   =   >   >   >   =   >   @   	      self     4      name     4      action     4      init_script    4   
   exec_path    4      argv    4      output    4      init_output    4      rc    4         initscript    popen 	   tonumber    format     B   S       @À I IÀÀÀ    ÀÀ @A I IÀ  IÀA@Â I IÀ   À   À A À Ú   @ I Ã  I@Ã        name    Package     Maintainer    vendor    match    ^%s*([^<]-)%s*<    Technicolor    version    Version    enabled 
   autostart    0    1        C   C   D   E   E   E   F   F   F   F   F   G   G   I   K   K   L   M   M   M   M   M   N   N   O   O   Q   S         self           opkg_package           _          err             run_initscript     U   `       F @ K@À \    Ä     Ü À@ Â@B  @BA AÉ @  B ÂAÀá  @û          opkg    list    env    nativeEssential    execenv    specs    name 	          V   V   V   W   X   X   X   X   Y   Y   Y   Y   Y   Y   Z   Z   Z   [   [   [   [   \   \   \   X   ]   _   `         self           package_list          list          (for generator)          (for state)          (for control)          _          opkg_package             ipairs    translate_package     b   g     
   @     Á    @@               No package found    verify     
   c   c   d   d   d   f   f   f   f   g         ipk_pkg     	      ee_name     	           i   p           @À    Ä    @ ÜÀÚ@  CA  ÛA   Á  Á^          new    Package failed verification:     <unkown reason>        j   j   j   j   k   k   k   k   l   l   m   m   m   m   m   m   m   o   p      	   pkg_file           ee_name           ipk_pkg       	   verified          verification_error             ipk    verify_package     r          Z   À À     @À    @À     ÀÀ @     Ä   Æ ÁA    À Ä    A ÜÚ@  ÀÀ  Á  Ä  À @ ÜÀÚ   ÀDFÂA Á 
  FBÀ 	BJB  I 	B\A C  CÁA   Õ^ Ä    FC FÁÀÜÀÚ@   C  ÁCÀ ^ FÄ Z   FÄ ÁÀ W C  ADÁ ^ FÁÄ Z   FÁÄ À  C  EÁA ^ FÁÀ E ÁE Ä  ÜÆ@ÀÄ C    D  FÅC  á  üÆE ËÆ@ÜÚ  @ @  ÂÆBÂÆ  D  FÃ          downloadfile    ID    version    name    INTERNAL_ERROR &   Malformed package provided to install    %.ipk$    .ipk    call    lcm    modify_package    properties    INSTALL_FAILED    Failed to rename package:     specs    UNVERIFIED_PKG    updated_name    UPDATE_NAME_CHANGED -   Trying to update with different package name    updated_version    DUPLICATE_PKG -   Trying to update to the same package version    opkg    list    Package    Duplicate package detected    install    opkg_package    Package installation failed        s   s   s   s   s   s   s   s   s   s   s   s   s   s   t   t   t   t   t   w   x   x   x   x   x   x   y   y   y   z   z   z   z   {   {   }   }   }   }   }   }   }   }   }   }   }   }                                                                                                                                                                                                                                                               self           pkg           downloadfile          ok !   6      errmsg !   6      ipk_pkg ;         errmsg ;         name [         package_list ^         (for generator) a   o      (for state) a   o      (for control) a   o      _ b   m      opkg_package b   m      success s         	   errcodes    match    rename    ubus    verified_package    ipairs    translate_package        ¢        K @ Á@  \ÀZ                 match    ^(['"])(.*)%1$                          ¡   ¢         v           quoted          quoted_val               ¤   ¨         À A  F@  @   À Á  F@  @  ^          gsub    %$LCM_INSTALL_ROOT    rootfs    %${LCM_INSTALL_ROOT}        ¥   ¥   ¥   ¥   ¥   ¦   ¦   ¦   ¦   ¦   §   ¨         self           path                ª   ´          Ä   Æ À  Ü ËA@A  ÜÚ  @ @   À   À  Â@FA KBÁÀ\@á@  ú          lines    match    ^%s*[%w_]*PID_FILE=(.*) 	      env    nativePath        «   ¬   ¬   ¬   ¬   ¬   ­   ­   ­   ®   ®   ¯   ¯   ¯   ¯   ¯   ¯   ¯   °   °   °   °   °   °   °   ¬   ±   ³   ´         self        	   filename        
   pid_files          (for generator)          (for state)          (for control)          line       	   pid_file 	            io    resolve_pid_variables    unquote     ¶   ¼          À   À ÀÚ@       @            name        ·   ·   ·   ·   ¸   ¸   ¹   »   »   »   »   »   ¼         self           pkg           _          init_script             initscript    load_pid_files     ¾   À          À   À AA               name    start        ¿   ¿   ¿   ¿   ¿   ¿   À         self           pkg              run_initscript     Â   Ä          À   À AA               name    stop        Ã   Ã   Ã   Ã   Ã   Ã   Ä         self           pkg              run_initscript     Æ   È         @ @@À             opkg 
   uninstall    name        Ç   Ç   Ç   Ç   Ç   È         self           pkg                Ë   Ò          @ @  Ä  Æ ÀA@ D   À \Ü   Ä   É           ExecutionMonitor    env        Ì   Ì   Í   Í   Î   Î   Î   Î   Î   Î   Î   Î   Î   Ï   Ï   Ñ   Ò         self           pkg           m          	   monitors    execmon    package_pid_files     Ô   ×    
      À     Ë @KAÀ \ Ý   Þ        
   executing    inRunningState     
   Õ   Õ   Õ   Õ   Ö   Ö   Ö   Ö   Ö   ×         self     	      pkg     	      monitor    	         monitor_for     Ù   â    	    À Ä     ÜÀ Ú@   C ^KAÀÁ  \AÀÂ  Ê  ÉAÉÞ         downloadfile    query    Package    Version    name    version        Ú   Û   Û   Û   Ü   Ü   Ý   Ý   Ý   ß   ß   ß   à   à   à   á   á   á   á   â         self           pkg           downloadfile          ipk_pkg          errmsg          name          version             verified_package     ä   ê          Æ À  @@  À   À AÁ          Æ À   A@  À   À AA           
   autostart 	      name    enable 	       disable        å   å   å   å   å   æ   æ   æ   æ   æ   æ   æ   ç   ç   ç   ç   ç   è   è   è   è   è   è   ê         self           pkg           	   tonumber    run_initscript     î   
   =   Ä      Ü W À Ã A  Þ Æ@ Ú@   Ã Á  Þ Æ A Ú@  @Ã A @  Þ À    F@ Ü ÁAFA A   C À B F@  ÆA Á^J  Æ@ ÁAÁCADIA IIIÁ À          table %   The config section should be a table    .name #   The config section should be named    rootfs    An  #    EE should have a rootfs directory    new 0   Unable to load the opkg information present in      EE          specs    name    type    vendor    technicolor    version    1.0    opkg    env     =   ï   ï   ï   ï   ï   ð   ð   ð   ò   ò   ò   ó   ó   ó   õ   õ   õ   ö   ö   ö   ö   ö   ö   ø   ø   ø   ø   ù   ù   ù   ù   ù   ú   ú   û   û   û   ü   ü   ü   ü   ü   ü   þ   ÿ                         	  	  	  	  	  
        config     <      ee_type     <      envType     <      env    <      opkg     <      self 7   <         type    opkg_module    setmetatable    Opkg_EE_wrapper m                                                                                                                     +   +   @   @   @   @   @   S   S   `   `   `   U   g   p   p   p                           r   ¢   ¨   ´   ´   ´   ´   ¼   ¼   ¼   À   À   ¾   Ä   Ä   Â   È   Æ   Ê   Ê   Ê   Ê   Ê   Ò   Ò   Ò   Ò   ×   ×   Ô   â   â   Ù   ê   ê   ê   ä   ì   
  
  
  
  
  î             io    l      type    l      ipairs    l      setmetatable    l   	   tonumber    l      match    l      format    l      rename    l      popen    l      ipk    l      opkg_module    l      attribs    l      ubus    l   	   errcodes !   l      execmon $   l      Opkg_EE_wrapper %   l      initscript (   l      run_initscript -   l      translate_package /   l      verify_package 4   l      verified_package 7   l      unquote A   l      resolve_pid_variables B   l      load_pid_files F   l      package_pid_files I   l   	   monitors V   l      monitor_for Z   l      M e   l       