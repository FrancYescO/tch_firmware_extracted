LuaQ    @process.EC           H      A@  @    A  @    AÀ  @    A  @    A@  E    \    ÁÀ  Å    Ü   AA  E   \   ÁÁ   J  G B  GB J  G d  ¤B       ä     ÁäÂ  $        $C     $   $Ã   d ¤C        ä       Á         require 
   libstring    libos    rappdb 	   libtable    lfs    posix    posix.unistd    posix.signal    posix.sys.wait    error 	      g_dying    g_all_dying    g_running_rapps    start_rapps    start    stop    running    cleanup                    
   E   F@À   \ À   AÀ  A           os    get_cmd_output    env    string    split    
                                                  n          n          n 
                 $    
      Ã  AA   Á@AAÆÁÁ ÁABÁ $                      $A                        I Ã@ \B         com.netdumasoftware.autoadmin    /usr/bin/lua 	      /dumaos/api/cli.lua 	      -p 	      path 	      backend 	       running        	        F      A@     @  D   	ÀÀ         D  @     Àÿ     À @ A E  @ À   B D F@Â Z   @ @ ÀB@  Ã    Ã  @        Ã      À Å  Æ@Ä D  @    Ã À Å  ÆÀÄ D  @  @  @E         print 	   rapp_end    g_running_rapps     g_yield_till_all_dead 
   coroutine    resume    load_settings    retry    pid    g_dying     running    g_all_dying    syslog    LOG    ERROR    Giving up restarting '%s'    WARNING    Restarting '%s' for %s time 	       F   	   	   	   	   	   	   	   
   
   
   
   
   
   
   
                                                                                                                                                                              r    E      a    E         n    r    t    o    e    l    i        "           @@ D    À@Ä   Ä Ü       D    @A	  D  @  @            uloop    process    table    clone    g_running_rapps    pid                                                                               "             o    u    s    c    d    n    t    r                                                          "   "   "   "   "   "   "   "   "   #   $   $   $   	      n           e           t          o          i          u          s 	         l 
         d             r    c     %   )    	   E      \ ÀAÀ@ Á  AAAWÀ   À  Aa  @ü        pairs    pid 	    	   g_handle 	   manifest    package        %   %   %   %   &   &   &   &   &   &   &   &   '   '   '   '   %   '   )         n           (for generator)          (for state)          (for control)          n          e             d     *   *        E   F  ^          g_running_rapps        *   *   *   *         n                +   /       D      \ Z   @E     @@Á    \@  EÀ     \ Z@  @   Ä  Æ ÁA Ü  @    À     @        error 
   ERROR_DUP    R-app already running    rappdb_get    ERROR_ILLOGICAL    R-app has not metadata        +   +   +   +   +   ,   ,   ,   ,   ,   ,   -   -   -   -   -   .   .   .   .   .   .   /   /   /   /   /         n           e             e    o    d     0   3       D      \ Z@  @   Ä  Æ@À  Ü  @  À   Á @ AÁÀ   @        error    ERROR_NOENT    R-app is not running    g_dying    os    execute    kill -2 %s        0   0   0   0   0   1   1   1   1   1   1   2   2   3   3   3   3   3   3         n           n             e    o     4   5       D      \ Z    B  Z@    B   ^               4   4   4   4   4   4   4   4   4   4   5         n     
         e     6   ;    #      Å@   ÀÅ  ÆÁÀ   @ÜÚ   EB FÁÂ ÀB @ EB FÁ ÅB   Ü  B  B@  B¡  @ø        pairs    g_running_rapps    table    find    syslog    LOG    ERROR    skipping '%s'    kill %s sent to '%s' 	   tostring    kill     #   6   6   6   6   7   7   7   7   7   7   7   8   8   8   8   8   8   8   9   9   9   9   9   9   9   9   9   9   9   9   9   9   6   9   ;         l     "      e     "      (for generator)    "      (for state)    "      (for control)    "      n           a           l 	             t     <   G        E   F@À ¤       ]  ^        
   coroutine    create        <   G     	       E   @  \    Á@Ä    A  @   @ a   ý@    À E  F@Á \@  ú    À A  @ @ B @         pairs    g_running_rapps    table    find 
   coroutine    yield    g_yield_till_all_dead    print    uloop cancel    uloop    cancel         =   >   >   >   >   ?   ?   ?   ?   ?   ?   ?   @   A   >   B   D   D   D   E   E   E   E   F   F   G   G   G   G   G   G   G         n          (for generator)          (for state)          (for control)          l          a          e 
            e    <   <   G   G   <   G   G         e                H   H          À         À    A@@  À@ä            Å  Æ@ÁÜ@ Å Á Ü@ Ë BÜ@ Å A @ Ü@  
      g_yield_till_all_dead    SIGINT    uloop    timer 	:     run    print    uloop run end    cancel    cancel homie        H   H     	      A@  @    D    @@        print "   timer reached, garbage collecting    SIGKILL     	   H   H   H   H   H   H   H   H   H             l    n    t    H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H   H         n           e           n             a    l    t     I   K     
,      A@    ÁÀ    A A A   J   À   @bA Á AA A A   J  À  bAA AA A A      J   bA Á AA A A          com.netdumasoftware.procmanager    com.netdumasoftware.autoadmin "   com.netdumasoftware.devicemanager    com.netdumasoftware.neighwatch    g_all_dying    print    DIE STAGE 1 	      DIE STAGE 2 	      DIE STAGE 3 	      DIE STAGE 4     ,   I   I   I   I   I   I   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   J   K   K   K   K   K   K   K   K   K   K         n    +      l    +      i    +      a    +         e    r H                                                                                                                           $   $   $   )   )   %   *   /   /   /   /   +   3   3   3   0   5   5   4   ;   ;   G   H   H   H   H   K   K   K   I   L   L         n    G      n    G      n    G      t    G      n    G      o    G      n    G      e     G      r !   G      c (   G      d +   G      e /   G      l =   G      a >   G      e B   G       