LuaQ               0     A@  @    A  @    AÀ  @    A  @    A@  E    \    ÁÀ  Å    Ü   AA  E   \   ÁÁ  Å   Ü   AB  E   \   ÁÂ  Å   Ü   AC  E   \   Â ÇÃ Á D CG CGÄ CG JÄ  IÄFIDGIÄGGD CG AÄ GD AÄ G AD	 G	 AÄ	 G	 AÄ D  Ê  ÉDJÉDDÄÂ  $    	        E  Å
 \   Á  äE       
$  $Æ      d    ¤F   Ê  
Ç  J IGLIGLIGÌG I	GJ IGLIGLIGÌ I	GJ IGLIGLIGÌ	 I	GÉ
Ç  J IGLIGLIGÌG I	GJ IGLIGLIGÌ I	GJ IGLIGLIGÌ	 I	GÉ$ dÇ          Cd           äG    $   AH   äÈ    $	      dI              C	d                    CdÉ    C	EI ¤	    I	J	  GÉ dI        ¤           	 ¤É         ä	               $J   d          
  äÊ       	           Ã Â
  $             ¡$K       d         	                   
C¡dË     ¤   ¢¤K               	         
¢ ËQÁ  W@R     J      require 	   libtable    libos 
   libstring    libmath 
   normalize    error    math.rectset    math.multirectset    math.tableset    math.interval    math.multiinterval    net 	   netrules    multi_service    json    autothrottle    filter    bit    g_qos_applied "   com.netdumasoftware.devicemanager    com.netdumasoftware.autoadmin 
   g_appmark 
   g_devmark    g_devtypemark    g_hypermark    pfield    phyper    cfield    chyper    bits 	   
   g_catmark    local_band    hyper_band 	      forward_band 	      benchmark_band 	      name    auto_hyperlane    table    lartc 	   nopqdisc    set_hardware_acceleration    lan    local    bytes 	       packets    dropped    b    hyper    forward    wan    traffic_stats    ifb0 
   raise_ifb    apply    safe_apply    rpc    application_status    installed_services    resync    install_jump_to_auto_hyperlane    install_auto_wfh    init    reset    cleanup    os    getenv    LUA_UNIT_TEST    qos.lua        <   I    8   D         E   @      Á  Ú@    ÁÀ  
Á  	AA	ÁAD FAÂ Ê  
  EÂ FÃ BC 	DKBÃÁ \	BÉ
  	ÂDD KBÃÁB \	BÉ¢A \ 	A\@    À E À \@  E   \@         
   long_call    com.netdumasoftware.autoadmin 	   add_rule 	   del_rule    hook    postrouting    tab    mangle    rules    encode    match    g_hypermark    cfield    new 	      zoneout    wan    target    field    hw_upstream    value 	      print    installing classify rule    removing classify rule                     Q   \            F@@ Z   ÀE  À   AÁ@ \@D   ^  ÀFA Z    D   ^  @ D  ^          load_settings 	   disabled    syslog    LOG    INFO !   Using disabled(NOP) QoS subclass    use_hardware                     ^   l        W À  @@      	@@@       À@Á  @ À   À@Á@ @          use_hardware    os    execute F   fc disable; fc flush; echo '0' 1>'/proc/sys/net/nss/super'; fc enable /   fc flush; echo '1' 1>'/proc/sys/net/nss/super'                     n   r          @@À    Ä   ÆÀÀ@ FA ÜÀ         table    clone 	   children    normalize_nodes    domain                     u          E   F@À    \ Z    B   ^   F@ ÀÀ @F A @Á  B  ^  ÀF A W@Á  B  ^  @E    ÀAÁ    \@    	      table    empty    share_excess  	   children     error    ERROR_INVALID    Invalid tree root state                        ª    \     B@A    Â@ÎÂ    D   \  Z   ÆA@Á@Å   EÃ FÂCBÁ Ä \ Ü  ÆC   @  ÀWÀ  D   @ ÀÜBZ  ÀÅB CBÜ@
ÃFÄCZ  @ [D   @  Å  ÆDÀ	  	E  FÅÀ
\ Ü  @	Å  ÆDÀ	  	E  FÅÀ
 \ Ü   	ÆDD   @  À  FÆÂÆAW  G   @ÜDá  Àô^         math    max 	      floor    domain    appcat    select    table    find 	   children 	       id    apply_tri_lane    ipairs 	   normprop    share_excess 	 
     add_devid_sub_lane                     º   À     	"      Å@  ÆÀ   @ Ü ÁÀ Å  Ü ÚA    ÁA ÁIÁ Å   Ü ÚA    ÁA ÁIÁÁ Å  Ü ÚA    ÁA ÁI     +   Sent (%d+) bytes (%d+) pkt %(dropped (%d+)    string    match    bytes 	   tonumber 	       packets    dropped                     Â   æ    Q   Z    Ä    Å   Æ@À   B Ü Ä  Ü  FÀZ   FÀ  \  D FÀÁ  AÀ  \ A  EA  ÁAÁ    \A   EA FÂÁ À \ ACÀ Ô Â @Â  ÂÃE  \  DD	Á ÅÄÅ ÆÅ	  @ 	ÜÚ   ÄÅÃ@ÜDa   ûù          table    clone    zone_to_interface 	   g_handle    conn    syslog    LOG    INFO (   Cannot acquire stats as zone %s is down    os    get_cmd_output    tc -s qdisc show dev %s    string    split    
 	      pairs    format    parent 2:%u    b    find                     ê   
   3   @  @ 
    Z@  À  EB  FÀÂ  À  B   @  EB  FÀ À  B   @      @ B B J ¤                          Å 
 dC            "C Ü bB  B         syslog    LOG    INFO +   not applying as interface down for zone %s    applying qos for zone %s    try    catch        ÿ     	  	      D    Ä  D Ä @                               	   D   F À   Ä  \@E@     \@         reset_interface    error                                   +      JÃ   I CÃ CÃIIICIIÃIÃ CÀ  H           up    band    tree 	   throttle    halgo    down 	   disabled    use_ifb    top_throttle    use_hw    throttle_upstream_hw    table    equal                     -  /      D   F À @  @À   ] ^           zone_to_interface 	   g_handle    conn                     5  =       
À  	@@	À@D   F@Á   Ê  
  É 
A  	ABÉ ¢@ \ 	@     
      hook    input    tab    mangle    rules    encode    match    target    field    skiplog                     @  L    _   
À  	@@	À@D   F@Á   Ê  
  D KÂÁA \	AD KÂÁÁ \	AÉ 
  	ÃD KÂÁA \	AÉ 
  J   BB I B I	AJ  IÃ BB I	AJ    Ä ËÂAB ÜÁÄ ËÂAÂ ÜÁI  ÃÄ ËÂAB ÜÁI  Ê   BB É B ÉÁÊ  ÉÃ BB ÉÁ¢@ \ 	@           hook    output    tab    mangle    rules    encode    match    proto    new 	   
   icmp_type 	      target    field    hw_upstream    value 	*   	:      icmpv6_type 	   	                        N  s   I   @  À Ä   À         Á       A  @AÁ   À  W À@ EA FÁÁ A  Z@  @ D A ÄÜ A   D A Ä Ü A    EA FÂÁ AA  @A  À  W À@ EA FÁA A  Z@  À D  ÄÜ A   D  Ä Ü A       	       os    execute    ip link set %s up    syslog    LOG    ERR    failed to raise IFB 
   long_call 	   add_rule    INFO    taking down IFB    ip link set %s down    failed to take down IFB 	   del_rule                     u  ×   	             Å@  
 d                           Ê $B      âA  "A  Ü@ À            load_settings    try    catch    g_qos_applied        y  È  
         W@@   @    D   FÀ   À   \ÀÄ  ÆÀÀÏ Á AAAD FÁZ  @ ÏÀÁÁAE FAÂ\ À E FAÂ \  J  IÁI A   À  D FÂ ÂBÀ   D FÃ CCÄ ÆÃ ÄCD FÄ DD	Ä ÆÄ	         Ä 
  ÉÅÁ   @ÜÚA      Å ÆAÅ D Â \ ÜA  Ä D  \  ÂBÀ   D FCÃ Ä ÆÄÜAÄ ÆAÆ ÂCÜA Ä ÆÁÃÚ   ÆF AÂ  DÜAÄÂ D ÂBÀ   D FCÃ ÜA ÆGB E  ÜA Â È         telstra_wan_pre    ptm    decide_throttle    upband 	   	   downband    is_goodput ùñãÇï?   math    round    utree    dtree    uhalgo    dhalgo 	   disabled    use_ifb    top_throttle    use_hardware    throttle_upstream_hw    telstra_upstream_hw_throttle    os    execute 5   tc qdisc del dev %s handle ffff: ingress 2>/dev/null    wan    lan 
   raise_ifb    add_ingress_mirror    wan-ingress    qdisc_complete 
   interface    zone                     Ê  Ñ      E      \ @À  K@ Ä   ÆÀÀ\@ B@  B  Z@  À   À   @  @ Å ÆÀÁ @       	      type    table    isa    ERROR_CALLFAIL    error    syslog    LOG    WARNING '   Backend calls failed when applying Qos                                 Ý  í   	   Å   
 d               A  Ê $B     âA  "A  Ü@           try    catch        à  â          @ D              apply                     ä  é      E   F@À   ÅÀ     Ü  \    À  @ @ Å ÆÀÁ  @              string    format    QoS application exception: %s 	   tostring    print    syslog    LOG    INFO                                 ó  õ           @ E@               encode    g_qos_applied                     ý     h   Å   Æ@À   À   @A  @   Á@C ÆA B FA  B    Â FB WÀA@  ÂÄ ËÃD FCÃ Á \Ü  Â@   ÂCÀ    DÀ C DEC  \ B    DÀ Ã A B  ÅB   A Ã BZ     DÀ Ã A  B ÅB   A Ã B  BFÅ ÆÂÆ @   ÂCÀ    DÀ C DEC  \ B   ÅB   A Ã B     	   g_handle    conn 
   uninstall    install    service 	   tonumber    wmm 	       apply_wan_dscp    field    dscp    value    new    lshift 	      service_to_birules 
   add_match 
   g_devmark 	   subfield    zoneout    lan 
   long_call    forward    mangle    wan    target_mark    g_hypermark    pfield 	                       !  I   R      Å@    Ü WÀ  Â@  Â  @ ¤      ä@     $    D KÁÀÅ   Ü \  A  A    Á@ ËA@ÜÂ Á    BÂ ÁB Â B  Â ÁÂ B B  Â Á Â B   À   @ B  À   @B B B Â XÀB XÀ Â À  ÆCÜB Â DB         assert    type    table    new    unpack    installed_services    join    print    resync    Enter    cardinality    Update    Exit 	       hyperlane_change    os 
   hal_flush        $  &         À     B  @                           (  *         À     B @                           ,  1     À @  @FBÀ É  @  å  B  !A  Àü     	   iterator    service    service_instantiate                                 O  g   C   E   \ @  ÆÀ  @ÅÁ    Ü@	@  À
  A CÁ Á `CE FÄÁ ÊÄ  ÉAÉDEÁ
É\D_ýD  FÂ ÃBÀÃÀ \CD  FCÃ ÃBÀÃÆÃÓ\Cá  ÀõÄ ÆÁÃ  Ü  D@      B    B¡  Àð        load_settings    pairs    hyper    ipairs 	      multi_service    table    insert    devid    service    translate_and_install    handle    id    pause    enabled    merge_multi_services    resync                     i     @   E  A@\   @À Ä  ÆÂÀ CAA Ü  ÃA@ D FÂ  ÁC\    Ã Ä  @  Ä  ÆCÃ  A  ÜC Ä ÆCÃ AÄ  ÜC  CDÀ C ÄÄ JÄ  ID I ÄE	À  IC a   ñ        ipairs 	   services    service_instantiate    target_mark    g_hypermark    pfield 	      service_to_birules    translate_match    hyper    service 	   rpc_call    type_to_id 
   add_match 	   cdevtype    devtype    table    insert 
   long_call    add_custom_rule    name    tab    rules    encode                             @  @A  F@D    À   @ \B !  ý@  @   À  A        hyperlane_types    ipairs                          2      Ê     A@@  A  @E  Á  AÁA \A  E  \ÀÂÁB      Å ÆBÂ  A ÜÚ   Å ÆBÂ  AÃ ÜÚ  @Ä    @ ÀÜBa  @ùD FÃA À\A        /www/json/_services_.json    load    syslog    LOG    WARNING    Unable to load services file.    ipairs    tags    table    find 
   hyperlane    gaming    install    auto_hyperlane                     ¢  ¸   ,   D   @      D    F   Ê   À Ê  ÉÀ@AAÁ É À    ÁÀ Ú@    Á  A D ÊÁ  ÉÁBBÃ ÉÂCJ  bB  ÉA     ADA         match    target    field    goto    value    new    name 	   add_rule 	   del_rule 
   long_call    hook    forward    tab    table    rules    encode    os 
   hal_flush                     ½  Í   ?   D   @      E         Á@  Ú@    Á  
Á  	Á	ÁD FÂ Ê  
B  DKÂÂÁ \	BÉ
  	ÂCDKÂÂÁB \	BÉ
  JB  ÂB I	BJ  IDÂB ÃDA C   I	B¢A \ 	A\@    E FÀÅ \@      
   long_call 	   add_rule 	   del_rule    hook    forward    tab    mangle    rules    encode    match    pappcat    new 	      target    field    phyper    value 	      dscp    lshift 	   	      os 
   hal_flush                     Ð  Ù   	   J  I@@   À@ AAI   AÊ        À Ä  ÆÀÁÚ@  @ Ä  Æ Â EA  Á Â A        field    save    value    new    g_hypermark    mask    service_to_unirule    install 
   uninstall 
   long_call    postrouting    mangle                     Û    
 
x   E   F@À   ÁÀ  $     \@ E  F@Á  ÅÀ \@E   F@À   ÁÀ  $A    \@ E   F@À   ÁÀ  $    \@ E   F@À   ÁÀ  $Á    \@ E   F@À   ÁÀ  $   \@ E    \ @ Ä  Â @ Ia  ÀýD F Ã @ Ê  
A  	ÁCâ@ \@D F Ã   Ê  
A  	Á@â@ \@D F Ã @ Ê  
  	Á@	ÁDâ@ \@D    F  Æ Á Å @@  Ä ÆÅÁ FÁESÜ@Ä ÆÅA FADSÜ@Ä  Æ ÆÁE Ü@ Ä  Æ@ÆAD Ü@ Ä Ü@ Ä   Ü@ Ä  Ü@ Ä  ÆÆ   CÜ@        os    attempt 	
   	      table    merge    g_hypermark    g_hypermark_tmp    pairs 
   installed 
   long_call    create_chain    translate_and_install    background    hyper 	    
   hyperlane 	   auto_wfh    appcat 	      name    load_settings    pause    auto_hyperlane    install_jump_to_auto_hyperlane    install_auto_wfh    set_hardware_acceleration        Þ  Þ       @  D     ÅÀ              g_hypermark_tmp 
   long_call    dualreserve    g_hypermark                     á  á       @  D     Ê            
   g_appmark 
   long_call    get_appmark                     â  â       @  D     Ê            
   g_devmark 
   long_call    get_devmark                     ã  ã       @  D     Ê               g_devtypemark 
   long_call    get_devtypemark                     ä  ä       @  D     Ê            
   g_catmark 
   long_call    get_catmark                                              D  F À @  @ÁÀ  \   @Å@  ÆÀ Z   À Æ@A   AÁ  Ü@   À Æ@A   A Ü@        zone_to_interface 	   g_handle    conn    wan    lan    reset_interface                                 @                             ;    	9      B   @   @   B  @   @ B   @  @@ B   @   D   ÀFÁ@Z   E ÁA   \A !  @ý A B   @   ÀA @  B   @   D   Ê@   ÁBÉ @   D   Ê@   CÉ @         install_jump_to_auto_hyperlane    install_auto_wfh    pairs 
   installed 
   long_call    destroy_chain 
   raise_ifb    cleanup 
   unreserve 	   subfield    g_hypermark    pfield    cfield                             