LuaQ 	   @main.EC           ¯      A@   E     \@ E   À  \@ E     \    Á@  Å    Ü  J  Á Å ÆAÂ @ Ü BBAÂ  J  bB B ÀÅ ÆCÂ  E FÄÃ\ Ü  IÂÅ DÜC ¡  ü¤     äB     $  dÃ         ¤   äC    $ dÄ   ¤             äD $      dÅ                	   
  	  ¤         
    E  äE         Å ä         Å äÅ       Å ä       Å äE         Å ä       Å äÅ         Å ä           Å äE     Å ä       Å äÅ Å ä   Å äE    Å ä   
  Å¤Å       E  ä    $F    ¢E    #      require    cloud_notification 	   libtable    libos 	   filesync    dbcore    lfs    /dumaos/themes    string    format 	   %s/cloud 	   %s/ready 3   http://netdumasoftware.com/themes/%s/themes-v1.asc    ipairs    os    board    print    on_init    rpc    pin    unpin 
   unpin_all    unpin_rapp 
   is_pinned    get_pinned    update_pinned    get_notifications    delete_cloud_notification    delete_rapp_notifications    set_authentication    set_active_theme    get_active_theme    get_themes    on_add_notification    on_db_upgrade               
$   E      \ @À  J      Å     Ü  ÅA  ÆÁÀ  @ ÜAá@   þÅ@  Æ Á  Ü@ Å    Ü À   FÂ  I á  @þ^              type    table    pairs    insert    sort     $                                                                                                   	   	               e     #      t    !      n    !      (for generator) 
         (for state) 
         (for control) 
         e          (for generator)           (for state)           (for control)           o          n             r               E      \ @À ÀE  FÀÀ    À     ]   ^   À E     ]  ^           type    table    json    encode 	   tostring                                                                    e              r             	*      @@Á     ÅÀ   AA@ ÜÀÚ   @ A  E Á BÁA   \A   FBZA  E Á BÁÁ   \A   FCW@@E Á BÁA   \A          string    format    %s/manifest.json    pcall    json    load    syslog    LOG    WARNING    Theme without manifest '%s'    version #   Theme does not have a version '%s'    id $   Theme path does match manifest '%s'     *                                                                                                                                       e     )      n     )      e    )      t 
   )      e 
   )              %     
&   
   E   F@À    Á  \Z   ÀD  FÀÀ    \  E FAÁ Ä    \ WÀA W B À     ÅA ÆÂ   @ ÜAa@   ú          io    open    r    dir    string    format    %s/%s    .    ..    table    insert     &                                                                                                                 !   $   %         n    %      (for generator)    $      (for state)    $      (for control)    $      e    "      t    "      e    "         t    m    r     &   +       E      \ À AÀ    ^ a  @þ        ipairs    id        &   &   &   &   '   '   '   (   &   )   +         n     
      (for generator)    
      (for state)    
      (for control)    
      t          e             o     ,   /       D      \ Z   @   @@Á  ÁÀ @À  Å@ ÆÁÁ [A    A @    @@Á@    @  
      os    config_set    DumaOS_Theme_Version    version    syslog    LOG    WARNING (   The selected theme does not exist: '%s'    nil    DumaOS_Theme        ,   ,   ,   ,   ,   -   -   -   -   -   -   .   .   .   .   .   .   .   .   /   /   /   /   /   /         e           n             m     0   0            @@ A               os    config_get    DumaOS_Theme        0   0   0   0   0   0               1   1     	      @@ E  FÀÀ   Ä   \ @          os    execute    string    format 
   rm -rf %s     	   1   1   1   1   1   1   1   1   1             t     2   2    
   A      @@Ä   @ ¤     À   A                wau3Y!*m72VvAj#d^z#!fafoq 	   sync_tar    Themes        2   2           @@ D     @  @         os    save    false        2   2   2   2   2   2   2   2             s    m    2   2   2   2   2   2   2   2   2   2   2   2   2   2   2   2         e           n             f    i    t    s    m     3   9           À     ÆA@@@ Â Þ ¡   þ             ipairs    id        3   3   3   3   4   4   4   5   5   3   6   8   8   9         e           n           (for generator)          (for state)          (for control)          t    	      e    	           :   :           @@ E  FÀÀ   Ä     D   \  @          os    execute    string    format ?   mkdir -p %s && rm -f %s/default && ln -s %s/default %s/default        :   :   :   :   :   :   :   :   :   :   :   :             t    d     ;   F   	  	(      @@ D    W@   @    @  @ D  \@ D \ H  D  \ À  Á    AAE  FÁ À$                   \   B A         os    load    true 	Q 	@8     cyclic_timer    create_exp_backoff        ?   F   	  "      d               @  D  \@ D \ H  D    Ä \Z@   D     \@ E@  FÀ  ÁÀ  \@D  ^          default    os    save    true        ?   A           @       D    @    A   @ @  @ AÀ  @ @   A D  @ @        default    os    execute    sync    save    true        ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   @   @   @   A   A   A   A   A   A   A   A   A   A             i    o    l    f    e    r    s "   ?   A   A   A   A   A   A   A   A   ?   A   A   B   B   B   B   B   B   B   B   B   B   B   C   C   C   D   D   D   D   D   E   E   F         t 
   !   	      p    i    o    l    f    e    r    s    n (   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   <   <   =   =   =   =   =   =   >   ?   ?   ?   ?   ?   ?   F   F   F   F   F   F   F   F   F   F   ?   ?   F   F   F         e    '      e    '      t    '      n    '   	      s    m    o    l    u    p    i    f    r     G   H       Ä  Æ À   Ü È   @  Ä  Ü@ Ä ÆÀÜ@         connect 	   g_handle    init        G   G   G   G   G   G   H   H   H   H   H   H         t           o           o              n    e    d    c     I   O       D   \  Ú@    Á   A      AA   @Ä  @   À  @ A      	   i         INSERT INTO panel
      ( package, url, data, colsize, rowsize )
      VALUES ( ?, ?, ?, ?, ? )
      safe_request        I   I   I   I   I   I   I   J   J   J   O   O   O   O   O   O   O   O   O   O   O   O         i           r           t           s           o           a             a    e    n     P   S    
   Ä     Ü  Á    A@D À    @ A      F       DELETE FROM panel WHERE
        package=? AND url=? AND data=?
      safe_request        P   P   P   P   S   S   S   S   S   S   S   S   S   S         o           s           t           a             a    e    n     T   W    	      Ä   Æ@À @   À Ü@     ;       DELETE FROM panel WHERE
        package=? AND url=?
      safe_request     	   W   W   W   W   W   W   W   W   W         a           o           t             e    n     X   [       A      @@Ä    @  @      1       DELETE FROM panel WHERE
        package=?
      safe_request        [   [   [   [   [   [   [   [         o           t             e    n     \   `    
   Ä     Ü  Á    A@D À    @  E   \  EÁ  W A W@A  A   \A W@A  BA  B ^      O       SELECT COUNT(*) FROM panel WHERE
        package=? AND url=? AND data=?
      value 	   tonumber    assert 	    	          \   \   \   \   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   `         i           s           t           o          e             a    e    n     a   f        
   D   F À   Á@  \ ÀFÁ@	A	ÁEA FÁ  À \Aa@  @ý          rows    SELECT * FROM panel    path    url     table    insert        a   a   a   a   a   a   a   b   b   c   d   d   d   d   d   a   d   e   f         t          (for generator)          (for state)          (for control)          e             e    n     g   m       A   @  À    @Ä  ÆÀ @ Â@ÆACAFAÃAÆB FDB ÜA  ¡  Àû  
   j       UPDATE panel
    SET colsize=?, rowsize=?, xpos=?, ypos=?
    WHERE package=? AND url=? AND data=?
      ipairs    safe_request    width    height    x    y    package    file    data        k   k   k   k   k   l   l   l   l   l   l   l   l   l   l   l   l   l   l   k   l   m         t           o          (for generator)          (for state)          (for control)          s          t             e    n    a     n   u     
      J   @  Ä   ÆÀÜ     ÅÁ  ÆÁ  @ ÜA¡   þ  @AÄ       Á  AÀ  A¡@   þ^       #       SELECT * FROM notifications
      ipairs    get_notifications    table    insert    rows        p   p   p   p   p   p   p   p   q   q   q   q   q   p   q   r   r   r   r   r   r   s   s   s   s   s   r   s   t   u         o          t          (for generator)          (for state)          (for control)          n          e          (for generator)          (for state)          (for control)          e             c    e    n     v   x          À D   F À    \@         remove_notification        v   v   w   w   w   w   x         e              c     y   y           @Ä  A  @   @        safe_request 6   DELETE FROM notifications WHERE package=? AND title=?        y   y   y   y   y   y   y   y         t           o              e    n     z   |     +      Û    Ô   XÀ  Â@  Â    @   Û   Ô  XÀ  Â@  Â  Á  @  @A ÆAÀÁÀÅ  Æ@Â @   Ü  ÁBA Â  A  ACA A         assert 	    	   username 	   password    os    platform_information    sdk    OpenWRT    string    format 	   /:%s:%s
    save    /etc/httpd.conf    execute !   /www/cgi-bin/uhttpd.sh restart &     +   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   z   {   {   {   {   {   {   {   {   {   {   {   {   {   {   {   {   |         n     *      e     *      t    *      e     *           }   }       D      ]  ^                }   }   }   }   }         e              r     ~   ~                             ~   ~   ~   ~             u                @ @ D   \@ D  ^                                         e              d    o                  Ä   Æ@À @ À ÆÁÀ Á FBÁ Á Ü@ ÅÀ Æ ÂË@Â@  A  ÁBÜ@      x       INSERT INTO notifications (
      'title', 'icon', 'package', 'description', 'data'
    ) VALUES (?, ?, ?, ?, ?)
      safe_request    title    icon    package    description    data 	   g_handle    conn    reply    result                                                                       o           t           a             e    n               Ä   Æ À  AA  Ü@Ä   Æ À  A  Ü@ÅÀ  Æ ÁÜ Ú    Ä   Æ@Á  A Ü@        safe_request H         ALTER TABLE panel
      ADD COLUMN xpos INTEGER DEFAULT NULL
     H         ALTER TABLE panel
      ADD COLUMN ypos INTEGER DEFAULT NULL
        os !   implements_netgear_specification    safe_execute á          INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/network-status.html','nil',4,4,0,0);
        INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/system-information.html','nil',4,4,4,0);
        INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/installed-apps.html','nil',4,4,8,0);
        INSERT INTO panel VALUES('com.netdumasoftware.qos','/apps/com.netdumasoftware.qos/desktop/flower.html','nil',6,8,0,4);
        INSERT INTO panel VALUES('com.netdumasoftware.devicemanager','/apps/com.netdumasoftware.devicemanager/desktop/device-tree.html','nil',6,8,6,4);
                                                                                   t           n           t              e        §       Å   Æ@ÀÜ   @@ Á   A AÁA@  ÁA@  AÀAÂB   ÁA@ Á A        os    platform_information    value    SELECT COUNT(*) FROM panel 	       sdk    OpenWRT    safe_execute             INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/cpu-usage.html','nil',4,4,8,4);
          INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/installed-apps.html','nil',4,4,8,8);
          INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/ram-usage.html','nil',4,4,4,0);
          INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/flash-usage.html','nil',4,4,8,0);
          INSERT INTO panel VALUES('com.netdumasoftware.networkmonitor','/apps/com.netdumasoftware.networkmonitor/desktop/overview-graph.html','nil',8,8,0,4);
          INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/network-status.html','nil',4,4,0,0);
            vendor    TELSTRA ¡            INSERT INTO panel VALUES('com.netdumasoftware.networkmonitor','/apps/com.netdumasoftware.networkmonitor/desktop/snapshot-graph.html','nil',8,6,4,0);
          INSERT INTO panel VALUES('com.netdumasoftware.networkmonitor','/apps/com.netdumasoftware.networkmonitor/desktop/first-level-breakdown-graph.html','{"download":true,"deviceId":"Total Usage"}',4,6,0,0);
          INSERT INTO panel VALUES('com.netdumasoftware.systeminfo','/apps/com.netdumasoftware.systeminfo/desktop/system-information.html','nil',8,6,0,6);
          INSERT INTO panel VALUES('com.netdumasoftware.qos','/apps/com.netdumasoftware.qos/desktop/lane-information.html','nil',4,6,8,6);
                                                                                              ¥       §         t           n           t           t             e ¯                                                                                                                                                                           %   %   %   %   +   +   /   /   0   1   1   2   2   2   2   2   2   9   :   :   :   F   F   F   F   F   F   F   F   F   F   H   H   H   H   H   G   I   O   O   O   O   I   P   S   S   S   S   P   T   W   W   W   T   X   [   [   [   X   \   `   `   `   `   \   a   f   f   f   a   g   m   m   m   m   g   n   u   u   u   u   n   v   x   x   v   y   y   y   y   y   z   |   z   }   }   }   }   ~   ~   ~   ~                                       §   §   §   §   §         c    ®      f    ®      e    ®      m    ®      n    ®      o    ®      d    ®      t    ®      s    ®      i "   ®      (for generator) %   3      (for state) %   3      (for control) %   3      e &   1      n &   1      r 5   ®      a 7   ®      r 8   ®      l <   ®      m >   ®      r @   ®      u A   ®      m C   ®      p I   ®      f J   ®      i M   ®      d W   ®       