LuaQ    @netsync.EC           +³      A@  @    A  @    Aΐ  @    A  @    A@  E    \    Αΐ  Ε    ά   AA  E   \   ΑΑ  Ε   ά   AB  E   \   ΑΒ  Ε   ά   AC  E   \ Γ Α D A   Κ  
  C$    dF     €     δΖ  $    
  	          dG    Dd   €Η   δ     $H   d €Θ δ          ΔδH      	  $      dΙ        	€	     €I    	  	€   €Ι   	€	   €I      		€   €Ι        δ	    Δ	δI Δδ     Δ	δΙ $
     $J     
$             $Κ          
$
 dJ         GΚ	 E

 FJΚ
 \ WΐΚ     ,      require 	   libtable    libos 
   libstring 
   constants    math.rectset    math.multirectset    math.tableset    math.multiinterval    net    geodb    iprules    posix.signal 	   validate    multi_service    error    cloud    domain    rtt "   com.netdumasoftware.devicemanager    com.netdumasoftware.autoadmin    com.netdumasoftware.geofilter    /usr/bin/geoip    resync    populate_ipsets    install_gf    uninstall_gf    update_radius    update_mode    update_polygons    update_strict    update_home    update_rtt    stop_geoip_daemons    start_geoip_daemons    insert_host    remove_host    init    cleanup    on_domain_map    os    getenv    LUA_UNIT_TEST    netsync.lua "                    E  ZA    EA    ΐ Βΐ@ Αΐ   CA@  ά A Β ΐB         uninstall_rules    install_rules    create_geofilter_rules    nfq    strict 	   subfield    forward    mangle                                                                                a           i           t           e           n           n          l          e             s            
     @   ΐ  B  A                                            i           l           e           n              o            
     @   ΐ  B A                                            n           e           l           i              o        	       K@\@@  ΐ   e  \B  aA  ΐύ     	   iterator                                         	   	      e           n           i           l           arg           (for generator)          (for state)          (for control)          i    	           
       E   Ϊ      A     D KΐΕA    ά \   A    @ Λ@@άΒ  Ε ΖBΑ @   ά B  Β  Α  ΓΑ KΓA\ ΓΑ ΐB ΐ   @ ΐ B ΐ   @ΐ B 	A ΒΑ XΐΒA Xΐ ΒΑ @ B B   
      new    unpack    join    print    string    format    devid=%d #arr_services=%d    cardinality 	       flush_denied_conntracks     E   
   
   
   
   
   
                                                                                                                                                                                                
      e     D      t     D      c     D      n     D      a    D      d    D      l    D      l    D      o    D      i    D         q    d    _    r    p    g            
   A    @     Z@   FA@FFΐD    ΐ   @\A        devid_to_gf    device    service                                                                       l           n           e           i           e             y                   E@    δ            J €A         bA  ’@  \@      	       try    catch                	      E@   E    ΑΑ    \  AAΐ  AΘ  !  ό        ipairs    g_subfields 
   long_call    reserve    table    merge                                                                    (for generator)          (for state)          (for control)          i          e          n 	            n    l            
   A      Α   `EA  F  Δ Β  @A _ΐύE  @ AΑΐ \@E     \@   	   	      g_subfields 
   long_call 
   unreserve    syslog    LOG    ERROR    Failed to reserve subfields    error                                                                             e           (for index)          (for limit)          (for step)          e          e             l    n                                                          l             n             	      E@    E    ΑΑ    \A !   ώ        ipairs    g_subfields 
   long_call 
   unreserve                                                  (for generator)          (for state)          (for control)          l    	      e    	         n        !       Δ   Ζ ΐά Ϊ@         Ε@   A    A ά@         ready 
   long_call    ipset_add_file    id    path                                                            !         l           e           i              f    n     "   &       Ε      ά @Bΐ   D  Β  Κ  ΙB ΙB α  ΐό        ipairs    allow 
   long_call    ipset_add_member    id    ip        "   "   "   "   #   #   #   $   $   $   $   $   $   $   "   $   &         e           a           i           (for generator)          (for state)          (for control)          e          l             n     '   '            E@  @         chains_create 	   g_chains        '   '   '   '               (   (            E@  @         chains_destroy 	   g_chains        (   (   (   (               )   3     
?      E@   ΐF@Z   EΑ    Α 
B  F@	B\A FAAΑ E FAΒB\ ZA    J  	A@FAAΐΒ@D BΖ@ \A  FAA ΓΐD AC Ζ@ \A @FAAΓΐD AC Ζ@  \A  EΑ   \A !  @ρ        ipairs 	   g_ipsets    id 
   long_call    ipset_flush 
   data_type    domain    domains    json    load    path 	   linedata    allow    get_all_hosts    deny    assert     ?   )   )   )   )   *   *   *   +   +   +   +   +   +   +   +   +   +   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   -   -   -   -   -   -   -   -   -   .   .   .   .   .   .   .   .   .   .   .   /   /   /   /   /   /   /   /   0   0   0   )   1   3         (for generator)    >      (for state)    >      (for control)    >      l    <      e    <         n    d    o    t     4   6     
      E@   ΐEΑ    Α 
B  FBA	B\ 	A!  @ύ  A @ ΐ @   @         ipairs 	   g_ipsets    id 
   long_call    ipset_create    isnet    populate_ipsets    init_global_chain_templates        4   4   4   4   5   5   5   5   5   5   5   5   4   5   6   6   6   6   6   6   6   6         (for generator)          (for state)          (for control)          i          l             n    e    c     7   9     
      @    E@   E   ΑΑ  
B  FA	B\A !  ύ        ipairs 	   g_ipsets 
   long_call    ipset_destroy    id        7   7   7   7   7   7   8   8   8   8   8   8   8   7   8   9         (for generator)          (for state)          (for control)          l          e             r    n     :   ?    A   D      Α@  @ A    Α  D FΑ\ Z  ΐFAA Z   FA Z  @FAA Α BΑA  Ε Β ΖΖΓB E FΒΓ ΐ   @ ΐ  @\BD FΔ  \B D FBΔ  \B D FΔ  \B D FΒΔ  \B D FΕ  \B D FBΕ  \B         /usr/networks    /usr/geoseq    homeip    1.2.3.4    ready    nfq    ipc    string    format    /tmp/geoip_ipc%u    g_subfields    SUBFIELD_PSTATE_VERDICT    lshift *   %s -d -n %s -g %s -i %s -f %s -u %u -s %u    os    safe_execute    update_radius    update_home    update_rtt    update_strict    update_mode    update_polygons     A   :   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   ;   <   =   =   =   =   =   =   =   =   =   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   >   ?   	      n     @      t    @      i    @      c    @      a    @      l    @      o    @      d    @      r    @         l    f    e     @   H       B      Κ  $              EA   δA            ’A \ β@  @             try    catch        A   B           E@    Α  
  \ 	@    E  F@Α  Δ   Ζ ΐ\	@ΐ E      @\  @       D   @   	      nfq 
   long_call    acquire_nfqueue    ipc    string    format    /tmp/geoip_ipc%u    chains_create !   create_geofilter_chain_templates        A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   A   B   B   B   B             e    n    l    o     B   G    #   D   Z   @E   @  Δ  Ζΐ  \@  D  Fΐ Z   @Eΐ    Α  
A  D Fΐ	A\@ D  IAEΐ   @BΑ Α @   \@  E     \@         chains_destroy !   create_geofilter_chain_templates    nfq 
   long_call    release_nfqueue    id     syslog    LOG    ERROR %   installing geoip failed because '%s' 	   tostring    error     #   B   B   B   C   C   C   C   C   C   D   D   D   D   E   E   E   E   E   E   E   E   E   E   G   G   G   G   G   G   G   G   G   G   G   G         i     "         l    e    n    @   A   A   B   B   B   B   B   B   B   G   G   G   G   G   B   G   A   G   G   H         e           l             n    o     I   L       E   @  Ζ@   \@  D   Fΐΐ \@ F@ Z   ΐE    Α@ 
A  F@ 	A\@ 	ΐA        chains_destroy !   create_geofilter_chain_templates    nfq    stop_geoip_daemons 
   long_call    release_nfqueue    id         I   I   I   I   I   I   I   I   I   I   I   J   J   J   J   J   J   J   J   L         l              e    n     M   O       A   @@      ΐ@ΐ    FA A@ @@ @         %s -m %u -f %s    ipc    os    safe_execute    radius    flush_denied_conntracks        M   M   M   M   N   N   N   N   N   N   N   O   O   O         e           n             l     P   R       A   @@      ΐ@ΐ    FA A@ @@ @         %s -M %u -f %s    ipc    os    safe_execute    mode    flush_denied_conntracks        P   P   P   P   Q   Q   Q   Q   Q   Q   Q   R   R   R         e           n             l     S   U       A   @@      ΐ@ΐ    FA A@ @@ @         %s -P %s -f %s    ipc    os    safe_execute    polygonpath    flush_denied_conntracks        S   S   S   S   T   T   T   T   T   T   T   U   U   U         e           n             l     V   X          Ζ@@  ΐΔ  Ζΐ  ά   Β@@ D  FΑ ΐ  \B D  FBΑ ΐ   \B ‘  @ϊ @         pairs    device    merge_multi_services    instantiate    flush_device    sync_device    flush_denied_conntracks        V   V   V   V   W   W   W   W   W   W   W   W   W   W   W   W   W   W   W   W   W   W   W   W   V   W   X   X   X   	      n           a           (for generator)          (for state)          (for control)          l          t          t          t             i    e     Y   [       A   @@    ΐ  ΐ@ΐ    FA@ A ΖAA @  @         %s -f %s -h -a "%d" -l "%d"    ipc    os    safe_execute    lat    lng    flush_denied_conntracks        Y   Y   Y   Y   Z   Z   Z   Z   Z   Z   Z   Z   [   [   [         e           n             l     \   `    (   @       @ Ζ @ Xΐ  Β@  Β    @ EΑ   ΐ \AEA   ΐ 
Β  D FΒΑFΑ	BD FΒΑFBΒ	BEΒ FΓ BCΐ  @  \  	B\A         rtt 	       rwd    print    action: 
   long_call    name    chain_rtt_drop    tab    table    rules    json    encode    generate_rules     (   \   \   \   ]   ^   ^   ^   ^   ^   _   _   _   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `   `         e     '      i     '      t    '      l 	   '      e    '         n    a    m     a   a    	      ΐ    @   ΐ   A  @        del_custom_rule    add_custom_rule     	   a   a   a   a   a   a   a   a   a         n           e              l     b   b            @@ A  @    @@ Aΐ  @    @@ A  @    @@ A@ @    @@ A @         os    execute    killall geoip    sleep 1    killall -2 geoip    sleep 2    killall -9 geoip        b   b   b   b   b   b   b   b   b   b   b   b   b   b   b   b   b   b   b   b   b               c   e     
       @ A@       D     \@         get_gfinstance 	       
   c   c   c   c   c   c   d   d   d   e         e    	         t    o     f   k           @E   @  F Fΐ ^   E   ΐ  F Fΐ ^       	   g_ipsets    IPSETS_ALLOWHOST    id    IPSETS_DENYHOST        f   f   g   g   g   g   g   g   i   i   i   i   i   k         e                l   l          ΐ   Ε    AA     ά@ Ε  ά@      
   long_call    ipset_add_member    id    ip    flush_denied_conntracks        l   l   l   l   l   l   l   l   l   l   l   l   l         e           i           l             l    n     m   m          ΐ   Ε    AA     ά@ Ε  ά@      
   long_call    ipset_rm_member    id    ip    flush_denied_conntracks        m   m   m   m   m   m   m   m   m   m   m   m   m         e           i           l             l    n     n   n           @   @    @ @ @  D    Κ     @ D   ΐG  ΐ          install_framework 
   long_call    get_devmark    g_appid_lshift    g_appid_mask 	   rpc_call    get_cmark_mask        n   n   n   n   n   n   n   n   n   n   n   n   n   n   n   n   n   n   n   n             p    d    a    s    u     o   o     	       @ B  @   @   @         install_framework     	   o   o   o   o   o   o   o   o   o             a    c    _     p   |     1      Β     A@@  @    FΑ@ FΑ@FBAZ  ΐE  FΑBAΐ \Z    Β  FΒAZ  ΐE  FΑΒAΐ \Z    Β  FBZ   EB FΒ ΖB\B!  ΐχ             string    lower    ipairs 	      names    name    find    cname    ipv4    table    insert     1   p   p   q   q   q   q   q   q   q   q   q   q   r   r   r   r   r   r   r   r   r   r   s   u   u   u   u   u   u   u   u   u   u   v   x   x   x   y   y   y   y   y   q   y   {   {   {   {   |   	      e     0      n     0      i    0      l    0      (for generator)    ,      (for state)    ,      (for control)    ,      a    *      e    *           }       :       @Ζ@ΐ Ζΐ@ ΐ  Ε   @ΖAAΪ  
ΖAΐΑΐ	ΕΑ  Bά@ @   ΐEC  \C EΓ FCΒ \C EΓ   \    D D     ΕΔ  AE   ΖEAΕEάD a  ϋα  ΐφ‘  ΐσ        intercept_domain 	      names    ipairs 	   g_ipsets    id 
   data_type    domain    domains    print    INSERTING IPS    table    isadd    ipset_add_member    ipset_rm_member 
   long_call    ip     :   }   }   }   }   }   }   }   }   }   ~   ~   ~   ~   ~   ~                                                                                                                           }               e     9      l     9      (for generator)    9      (for state)    9      (for control)    9      i 	   7      e 	   7      (for generator)    7      (for state)    7      (for control)    7      t    5      i    5      l    5      (for generator) #   5      (for state) #   5      (for control) #   5      i $   3      l $   3      i +   3         h    a    n ³                                                                                                                                                                                                               	                                             !   !   !   &   &   '   (   3   3   3   3   3   )   6   6   6   6   9   9   9   ?   ?   ?   ?   H   H   H   @   L   L   L   I   O   O   M   R   R   P   U   U   S   X   X   X   V   [   [   Y   `   `   `   `   a   a   a   b   b   e   e   e   c   k   l   l   l   l   m   m   m   m   n   n   n   n   n   n   n   o   o   o   o   o   |               }                           )      e    ²      e    ²      _    ²      e    ²      e    ²      t    ²      a !   ²      e $   ²      e '   ²      i *   ²      e -   ²      f 0   ²      h 3   ²      m 6   ²      u 7   ²      n 8   ²      e 9   ²      l :   ²      e ;   ²      d <   ²      q =   ²      o >   ²      o >   ²      s >   ²      o @   ²      p B   ²      g D   ²      r E   ²      y L   ²      p Q   ²      _ S   ²      d V   ²      o X   ²      c Y   ²      r Z   ²      d d   ²      c g   ²      o k   ²      l    ²      l    ²      a ¦   ²       