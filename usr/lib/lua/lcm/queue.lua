LuaQ    @queue.lua            x      E@     Á   À   Á  Ü Æ ÁA Ü    A  @  Á \  ABÅ ÆÂÂ @   \   ÁB  Ê  ÉÂ$       dC       ÉBd  ¤Ã    ä ÉÂäC    ÉÂä ÉÂäÃ   $ dD      ¤      äÄ         	$ dE ¤         
   
äÅ   	   ÉÂä   
ÉÂÊ  ÉÅ$F      d ÉEdÆ   ¤   äF             $   É
  	dÇ    	Gd 	GdG 	Gd         äÇ    Çä    ÇäG         Ç         require    setmetatable    lcm.db    tch.logger    new    queue 	   lcm.ubus    dkjson    table    remove    sort    ipairs    lcm.execute    lcm.errorcodes    __index    loadInitialActions    head 
   drop_head    operation_complete    add    add_notification    trigger_processing    process    addNotification    ActionQueue    ActionProcessor    init        &   *           J@     I               items        '   '   (   (   )   '   )   *             setmetatable    ActionQueue     ,   3    	      Ä     Ü   @Àá  þÄ    d  Ü@	     	      items        1   1         @ Æ À XÀ   @           	   sequence        1   1   1   1   1   1   1   1         lhs           rhs               -   .   .   .   .   /   /   /   .   /   1   1   1   1   2   3         self           initial_actions           actions          (for generator)    
      (for state)    
      (for control)    
      _          action             ipairs    sort     5   ;     
   F @ Z   À @@   @  A  ^          _last_seqnr    items 	        
   6   7   7   7   7   7   7   8   :   ;         queue     	      seq    	           =   A       D      \ L À 	@^       	      _last_seqnr        >   >   >   >   ?   @   A         queue           seq             queue_last_seqnr     C   E        F @ F@À ^          items 	          D   D   D   E         self                G   L       D    @ Á@  \Z   À À À@Á @        items 	      package    remove_pending_action 	   sequence        H   H   H   H   I   I   J   J   J   J   L         self     
      action    
         remove     N   V         @     @Æ@@À   Â@  Â  Þ  Â  Þ          head    operation_ID        Q   Q   R   R   S   S   S   S   S   S   U   U   V         self           operation_ID           next               X   ^    	       @A  F@ Á@ A  À A A    A ÆA   @        notice 0   adding %s:%s (current state: %s, operation: %s)    execenv    URL    name    (no identification)    state        Y   Y   Y   Z   [   [   [   [   [   [   [   \   ]   Y   ^         pkg           desired_end_state              logger     `   b         @               can_have_end_state        a   a   a   a   b         pkg           desired_end_state                d   n       Ä      @ Ü@Ä     @ ÜÚ   @Ê  É  ÉÉ@ É ÁÞ          package    operation_ID    desired_end_state    unprocessed        e   e   e   e   f   f   f   f   f   f   g   h   i   j   k   l   n         pkg           desired_end_state           operation_ID              log_action_creation    is_valid_action     p   s       D   K À Á@     \@ C    @ÁÀ  ^          error    unsupported operation %s    INTERNAL_ERROR    unsupported operation        q   q   q   q   q   r   r   r   r   r   s         desired_end_state     
         logger    s_errorcodes     u          Ê     @  @D  À   \ ZB  À  À    @É@!  ÀûÞ       	          v   w   w   w   w   x   x   x   x   x   y   y   z   z   z   z   |   |   |   w   |   ~      
      pkgs           desired_end_state           operation_ID           actions          (for generator)          (for state)          (for control)          _          pkg          action 
            ipairs    create_action    unsupported_action             	   F @ @À @ À Á@ FA AA @        package    clear_error    add_pending_action 	   sequence    operation_ID    desired_end_state     	                                    action           pkg                           @ Ô  Ì@À@        items 	                               queue           action           items                      
      À   Ä    Ü ÁÄ    @ ÜAÄ  ÜA ¡  ü     	   sequence                                                                    queue           actions           (for generator)          (for state)          (for control)          _          action             ipairs    queue_next_sequence    append_action_to_queue    update_action_package            
     @  ÀA  À Ã @ Þ Ä    @ ÜAÂ Þ                                                                          self           pkgs           desired_end_state           operation_ID           actions          errcode          errmsg             generate_actions    add_actions_to_queue        ¥    
     @ ÀÄ      @ Ü@Â  Þ          package    notification     
          ¡   £   £   £   £   ¤   ¤   ¥         self     	      pkg     	      action    	         append_action_to_queue     ª   ®       D   @    Ä  ] ^           queue        «   «   ¬   ­   «   ­   ®         queue              setmetatable    ActionProcessor     °   ²        K @ \@         process        ±   ±   ²         self                ´   ¸    	   F @ Z    D   K@À Á  @ \@         data    debug    next action data: %s     	   µ   µ   µ   ¶   ¶   ¶   ¶   ¶   ¸         result              logger     º   Á        À Ä      Ü@ Ë@@Ü @ A    Á@ É I@AÁ A         queue    head    data    error    external_operation     trigger_processing        »   ¼   ¼   ¼   ½   ½   ¾   ¾   ¾   ¾   ¾   ¿   À   À   Á         result        
   processor           queue          next_action             log_external_operation_result     Ã         F @ @@        @Á  @   Á  @   Ä   ËÀAA Ü@  ÆAÚ   ÁA  À  @ AAÂ A   BFÁBZ    ÃKACÆC\Z   KÁCÆD\AÚ@  @KACÆC\Z   D  KÀÁA D   Â B     FBEEÆÂE\AKAÂ \A KÆ ÆD\Z  ÀD FAÆ ÊA  DÉ\AÀÚ@  @KG\ Z  @FÁAZ  KAGÆDCFÂA\A ÃÀÚ@  À KG\ Z  @ ÃD FÇÁ \ 	@ÈB AÈ@  A 	Á IÀ  	ÃËAÉJ  bB ÜA  À KAGÆDC\A B ^   &      queue    external_operation    debug %   process_queue: operation in progress    head     process_queue: nothing in queue    notification    data !   process_queue: notification done 
   drop_head    package    unprocessed     action_complete    desired_end_state    send_noop_state_change    operation_ID %   operation %s on %s:%s (cur_state:%s) 	   errormsg    failed 	   complete    execenv    URL    state    operation_complete    send_event    operation.complete    operationID    is_in_transient_state    advance_state    ExternalOperation    /usr/sbin/ee_action.lua    timeout 	      onCompletion    notify    encode    invoke        Ä   Æ   Æ   Æ   Ç   Ç   Ç   Ç   È   Ë   Ë   Ì   Ì   Í   Í   Í   Í   Î   Ð   Ñ   Ñ   Ñ   Ñ   Ñ   Õ   Õ   Õ   Õ   Ö   Ö   ×   ×   Ù   Û   Û   Û   Ü   Ý   Ý   Ý   Ý   Ý   á   á   á   å   å   å   å   å   å   å   ç   ç   ç   è   è   è   è   è   è   è   é   é   ë   ç   ì   ì   í   í   í   í   í   ï   ï   ï   ï   ï   ï   ï   ð   ñ   ñ   ñ   ñ   ñ   ñ   ñ   ñ   ñ   ô   ô   ô   ô   ô   õ   õ   ö   ö   ö   ö   ö   ö   ÷   ø   ø   ø   ø   ù   ú   ú   ú   û   û   û   û   ü   ý   ý   ý   ý   þ   ÿ   ÿ   ÿ   ÿ   ÿ                             self           queue          next_action          is_notification          package !         exop l         encoded_package y            logger    ubus    execute    external_operation_done    json       
      D      \ Z     @þ                         
        self              process_step          
   Ä   Æ ÀÜ A@ @ À  A  À Ã @ Þ ÆÁ@ ËÁÜA Þ          generateID    queue    add 
   processor    trigger_processing                                                      self           pkgs           desired_end_state           operation_ID          queued 	         errcode 	         errmsg 	            db                @ @@   @  À CÀ ^ F@ KÁÀ\A           queue    add_notification 
   processor    trigger_processing                                             self           pkg           queued          errcode          errmsg               "  %        @ @@  @@ À@@         queue    loadInitialActions 
   processor    trigger_processing        #  #  #  #  $  $  $  %        self           actions                '  ,         Ê  É  É@             queue 
   processor        (  (  )  *  +  (  +  ,        queue        
   processor              setmetatable    ActionHandler     0  2                            1  1  1  2            newActionQueue     4  6      D      ]  ^                5  5  5  5  6        queue              newActionProcessor     8  <      @          Z@  À   À    @    À                      9  9  9  9  9  :  :  :  :  :  :  ;  ;  ;  ;  ;  <        queue        
   processor              newActionQueue    newActionProcessor    newActionHandler x                                                                              !   !   !   #   $   *   *   *   3   3   3   ,   ;   A   A   E   C   L   L   G   V   N   ^   ^   b   n   n   n   s   s   s                                                ¥   ¥      §   ¨   ®   ®   ®   ²   °   ¸   ¸   Á   Á               
  
                   %  "  ,  ,  ,  .  2  2  0  6  6  4  <  <  <  <  8  >  >        require    w      setmetatable    w      db    w      logger    w      ubus    w      json    w      remove    w      sort    w      ipairs    w      execute    w      s_errorcodes    w      ActionQueue    w      newActionQueue !   w      queue_last_seqnr &   w      queue_next_sequence (   w      log_action_creation 1   w      is_valid_action 2   w      create_action 5   w      unsupported_action 8   w      generate_actions <   w      update_action_package =   w      append_action_to_queue >   w      add_actions_to_queue C   w      ActionProcessor K   w      newActionProcessor O   w      log_external_operation_result S   w      external_operation_done U   w      process_step [   w      ActionHandler _   w      newActionHandler j   w      M k   w       