LuaQ    @devices.EC           K      A@   E     \    Αΐ   Ε    ά  AA €      €A  Α €   €Α         δ B dB    €      Α $Γ   d      €C         δ      ΗΓ δΓ      Η δ ΗC δC $    $Δ   Δ $  $D D $  $Δ Δ $  $D D $  $Δ Δ         require    json    error    devmarking 
   extenders    com.netdumasoftware.autoadmin    on_type_change    get_all_devices    get_interface_info 	   02:0f:b5 	   A8:5E:45    do_interface_update    interface_update    interface_domain_update    delete_interface    change_interface_dev    pin_interface    device_exist    device_interface_count    get_device_interfaces    get_interface    update_dev_name    update_dev_type    block_device               S   Z@  @    F @@  @Εΐ   @   @  @ΐ     Cά@  ΐΕ@ Aά ΐΑΖAW Βΐΐ     EA FΒA\ ά@  ΐΕΐ    ά  @A @ΐEB C\ ΐΑFCW Βΐ@   ΕB ΖΒCά \B    !  @ϋ  @  A BΑΑ  A  ΐ  @   A EA FΔΑ Ε    ά A       
   mark_type    dbcore    record    g_db     SELECT * FROM device WHERE id=?    type    utype    string        rpc    type_to_id    get_device_interfaces 	       ipairs    gtype    Other    syslog    LOG    WARNING    Device has no interfaces %s 	   tostring     S                                                                                                                                       	   	   	   	   	   	   	   	   
   
   
   
   
   
   
   
                                                                        	      e     R      n     R      t 
   R      r %   R      (for generator) +   >      (for state) +   >      (for control) +   >      d ,   <      r ,   <         r              	!   
   E   F@ΐ   Αΐ  \ @JA AIAAIAWΐA  A   IABIΑ ΖAB I ACΐ   Aa@  ΐω          dbcore    rows    g_db    SELECT * FROM device    uhost    utype    block 	      devid    id    interfaces    get_device_interfaces    table    insert     !                                                                                                            n           (for generator)          (for state)          (for control)          e          e                          E   F@ΐ   Αΐ     ]  ^           dbcore    record    g_db $   SELECT * FROM interface WHERE mac=?                                      e                   &    Z   Z@    A   Δ   Ϊ@  @Ε@  ΖΐΑ  E FAΑ ά  B@Α GΑ   A D   ΕΑ A Γ  D  Z  @EA  FΑΒA  Cΐ   ΑA  \ A  Cΐ  ΕΑ   άC  CFCΓ EC  FΓΔ\ C  CDΐ    ΐC  CDΐ     ΖΔΓΔ   ΓΔA     @ α  χ   @Ϊ@    Α  A    A @ ^            string    format    %s/%s 	   g_handle 
   parentdir    cloud/devdetect.json    reason    load    warning &   Unable to load devdetect because '%s'    sub    lower 	   	      ipairs 	      find 	   	   	   Computer    unnamed device     Z                                                                                                                                                                                                                                             !   !   "   "   "   #   #   #   %   %   %   &         i     Y      r     Y      c     Y      e          n    Y      d    Y      i %   N      o )   N      (for generator) ,   N      (for state) ,   N      (for control) ,   N      t -   L      e -   L      c 1   L      t 5   L         t    d     '   '      
      @@ E  ΐ  @   A              dbcore    safe_request    g_db &   INSERT INTO device (id) VALUES (NULL)    last_insert_rowid     
   '   '   '   '   '   '   '   '   '   '               (   (       E   F@ΐ    \    E   Fΐΐ   Δ   \G  E   F@Α    Ε  ] ^           string    lower    p    format    ^%s    find        (   (   (   (   (   (   (   (   (   (   (   (   (   (   (   (   (   (         e              r     )   0    0      @@ΐ          @ΐ   Α  Δ      ά Ϊ   ΐΕ   Ζ ΑA A  ά @ Ε   Ζ ΑA D  ά @ Κ   Α E FAΒ ΐ   \ EΒ FΓΐ \BaA   ώή          string    lower    match    :(%x%x:%x%x:%x%x)$    format    %s:%s 	   __:__:__ )   SELECT * FROM interface WHERE mac LIKE ?    dbcore    rows    g_db    table    insert     0   *   *   *   *   *   *   *   *   *   *   *   *   *   *   *   +   +   +   +   +   +   +   +   ,   ,   ,   ,   ,   ,   ,   -   -   -   -   -   -   -   -   -   .   .   .   .   .   -   .   /   0   	      e     /      n     /      t 
   /      e    /      t     /      (for generator) &   .      (for state) &   .      (for control) &   .      n '   ,         d    r     1   1       E   F@ΐ    \    E   Fΐΐ   Δ   \G  E   F@Α    Ε  ] ^           string    lower    p    format    ^%s    find        1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1         e              r     2   9    0      @@ΐ          @ΐ   Α  Δ      ά Ϊ   ΐΕ   Ζ ΑA A  ά @ Ε   Ζ ΑA D  ά @ Κ   Α E FAΒ ΐ   \ EΒ FΓΐ \BaA   ώή          string    lower    match    :(%x%x:%x%x:%x%x)$    format    %s:%s 	   __:__:__ )   SELECT * FROM interface WHERE mac LIKE ?    dbcore    rows    g_db    table    insert     0   3   3   3   3   3   3   3   3   3   3   3   3   3   3   3   4   4   4   4   4   4   4   4   5   5   5   5   5   5   5   6   6   6   6   6   6   6   6   6   7   7   7   7   7   6   7   8   9   	      e     /      n     /      t 
   /      e    /      t     /      (for generator) &   .      (for state) &   .      (for control) &   .      n '   ,         d    r     :   P    c   Ε   Ζ@ΐ  AΑ   ά   @   T  Α@ FA@ΑD   \  A@ Α@A     ΐ  ΐA@  Ϊ     @Α ΐ    B Α B @   E  FΒ  ΑΒ \B@   E  FΒ  Α \BE  FΒ  ΑB    @ ΐ     D     \B ΐE  FΒ  Α    @ ΐ      A ZD    A \BE  FΒ  ΑΒ \BE   \ BΑ         dbcore    record    g_db &   SELECT * FROM interface WHERE dhost=? 	      devid    type    string 	       is_if_wifi    safe_request    BEGIN TRANSACTION; '   INSERT INTO device (id) VALUES (NULL);            INSERT INTO interface
          ( mac, ghost, gtype, dhost, devid, wifi )
          VALUES ( ?, ?, ?, ?, last_insert_rowid(), ? );
                  INSERT INTO interface
          ( mac, ghost, gtype, dhost, devid, wifi )
          VALUES ( ?, ?, ?, ?, ?, ? );
          COMMIT;    get_interface_info     c   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   <   <   >   >   >   >   >   >   ?   ?   A   A   A   A   A   A   A   A   A   A   A   A   A   B   D   D   D   D   D   D   D   D   D   D   D   D   D   D   D   E   E   E   E   E   E   E   E   I   I   I   I   I   I   I   I   I   I   I   E   I   J   J   J   N   N   N   N   N   N   N   N   N   N   N   N   J   O   O   O   O   O   O   O   O   O   O   P   
      e     b      n     b      t     b      d    b      r 	   b      r    b      i )   b      r )   b      d ,   b      e `   b         i    s    o     Q   ]    E   Δ      @   άΐ F@A@W@  A   Ϊ@    Ζΐ@A    AZ@    F@AΕ    ά A   Ϊ     BAW  ΐΒAB    BBA @EΒ Y   B   Α \B@ D \ @ BCE Β ΐ  @    Α  ΪC    Α    B^         devid    wifi 	      ghost    gtype    dhost    is_if_wifi    pinned    dbcore    value -   SELECT COUNT(*) FROM interface WHERE devid=?    assert    Logic incorrect.    safe_request    g_db V    UPDATE interface SET
        ghost=?, gtype=?, dhost=?, devid=?, wifi=? WHERE mac=?  	        E   Q   Q   Q   Q   Q   Q   R   R   R   R   R   S   S   S   T   T   T   U   U   U   V   V   V   V   V   V   V   V   W   W   W   W   W   W   X   X   X   X   X   X   X   X   X   X   X   X   X   X   Y   Y   Y   [   [   [   \   \   \   \   \   \   \   \   \   \   \   \   [   \   ]   	      r     D      n     D      e     D      i    D      o    D      t    D      d    D      a    D      e '   3         o    c     ^   g    
I   Ε   Ζ@ΐ   A  άΪ       Δ   Ζΐΐ   ά Ϊ        Α   C  Ε@   ά  ΐΕ   ΖΑ  AΑ  ά @ Ε@    ά  Ϊ    E FΑΒ ΕA    ά B @  \A  E   ΐ  \  E FΑΒΑ ΕA    ά B @  \A  D   ΐ \ E  ΐ \A        string    find    00:00:00:00:00:00    is_extender    *    type    gsub    %c        get_interface_info    os    debug_print    repeat interface %s %s 	   tostring    do_interface_update    new interface %s %s    on_type_change     I   ^   ^   ^   ^   ^   ^   ^   ^   _   _   _   _   _   _   _   `   `   `   a   a   a   a   a   b   b   b   b   b   b   b   c   c   c   c   d   d   e   e   e   e   e   e   e   e   e   e   e   e   e   e   e   e   e   f   f   f   f   f   f   f   f   f   f   f   f   f   f   f   g   g   g   g   g         n     H      e     H      d     H      r !   H      t "   H         a    l     h   m     )   Ε   Ζ@ΐ   A  άΪ       Εΐ   Α@ Γ Ηΐ  Ε@    ά Ϊ@      Α  @ΑWΐA Α BΐA E FΑΒ ΐ   @   \A EA Γ\A         string    find    00:00:00:00:00:00 	   hostname    *    get_interface_info    gname        unnamed device 2   UPDATE interface SET ghost=?, gtype=? WHERE mac=?    dbcore    safe_request    g_db    on_type_change    devid     )   h   h   h   h   h   h   h   h   i   i   i   i   i   j   j   j   j   j   j   k   k   k   k   k   k   k   k   k   l   l   l   l   l   l   l   l   l   l   l   l   m         n     (      t     (      r     (      e    (      d    (           n   s        E   F@ΐ   Αΐ     \  Α @   @AΕ   @  @   ΐ        ΐ            dbcore    value    g_db -   SELECT COUNT(*) FROM interface WHERE devid=? 	       safe_request    DELETE FROM device WHERE id=?        n   n   n   n   n   n   n   n   o   o   o   o   o   o   o   o   o   o   q   q   q   s         e           n               t   w       E@     \ G   E   Z   E  Fΐΐ   Α@    \@ D      A]  ^   B   ^          inf    get_interface_info    dbcore    safe_request    g_db "   DELETE FROM interface WHERE mac=?    devid        t   t   t   t   t   t   t   u   u   u   u   u   u   u   u   u   u   u   v   v   w         e              n     x   x       Ε   Ζ@ΐ  AΑ   ΐ  ά@Ε  Ζ@Α AΑ Α   A ά@ Δ     έ  ή           dbcore    safe_request    g_db )   UPDATE interface SET devid=? WHERE mac=?    event    fire 	   g_handle    inf_migrate    mac    old    new        x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x         r           e           t              n     y   y        E   F@ΐ   Αΐ     \@ E  K Α ]  ^           dbcore    safe_request    g_db *   UPDATE interface SET pinned=? WHERE mac=?    changes        y   y   y   y   y   y   y   y   y   y   y         e     
           z   |        A   @  @Εΐ    @   W A  @    Ε@    @ @   X   A   ά@        '   SELECT COUNT(*) FROM device WHERE id=?    dbcore    value    g_db 	      assert    device_interface_count 	           z   z   z   z   z   z   z   z   z   z   z   {   {   {   {   {   {   {   {   {   {   {   {   |         n           e          e               }   }     	   A   @  @Εΐ    @            -   SELECT COUNT(*) FROM interface WHERE devid=?    dbcore    value    g_db     	   }   }   }   }   }   }   }   }   }         e           n               ~        
   J      Ε@  ΖΐΑ  @   ά  Ε ΖAΑ  @ άAα@   ώ^       &   SELECT * from interface where devid=?    dbcore    rows    g_db    table    insert        ~   ~   ~   ~   ~   ~   ~   ~   ~                  ~                  n           e          t          (for generator)          (for state)          (for control)          n 	                      	   A   @  @Εΐ    @            $   SELECT * from interface where mac=?    dbcore    record    g_db     	                                    n           e                             @@Ε  Α  @   @   A X  @              dbcore    safe_request    g_db %   UPDATE device SET uhost=? WHERE id=?    changes 	                                                                 e           n                              @@Ε  Α  @   @  ΐ   @   @A X   @              dbcore    safe_request    g_db %   UPDATE device SET utype=? WHERE id=?    on_type_change    changes 	                                                                          e           n                              @@Ε  Α  Z    A ZA    AA   @  A X  @              dbcore    safe_request    g_db %   UPDATE device SET block=? WHERE id=? 	   	       changes                                                                             e           n            K                                                                  &   &   &   '   (   (   (   0   0   0   1   1   1   9   9   9   P   P   P   P   ]   ]   ]   Q   g   g   g   ^   m   h   s   w   w   t   x   x   x   y   y   |   z   }   }      ~                                    d    J      e    J      r 	   J      a    J      t    J      e    J      o    J      c    J      r    J      d    J      i    J      r     J      d "   J      s %   J      l )   J      n 4   J       