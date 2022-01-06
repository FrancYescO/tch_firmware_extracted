LuaQ    @persistency.lua           u   
   E   @  Å  Á  E A Å Â BEB FÂB ÂBÀ  Ü   AC  CAÃ  @  \  ÁC  ÆÄÄÄFÅ  ä    $E  d  ¤Å     ä    $F                 
   d   	DdÆ    
Dd    
DdF   	    Dd   	        DdÆ   	Dd        ¤F         ¤ äÆ   	           
           $   $G      d    DdÇ Dd DdG Dd DdÇ        		@    #      require 	   tostring    pairs    ipairs    setmetatable    type    next    string    format    table    concat    sort    transformer.persistency.db    tch.logger    new    DB    transformer.pathfinder    transformer.fault    stripEndNoTrailingDot    isMultiInstance    endsWithPassThroughPlaceholder    getKey    getIreferences    getIreferenceByAlias    getKnownAliases    addKey    delKey    query_keys    sync    addTypePath    close    startTransaction    commitTransaction    revertTransaction    __index        2   8          @D      Á   ] ^   @ A@  ^          .            3   3   4   4   4   4   4   4   6   6   8         ireferences     
         concat     >   G        J    @ A    WÀ  Á@I@¡@   þ^          gmatch 
   ([^.]*).?     	          ?   @   @   @   @   B   B   C   C   C   @   D   F   G         s           ireferences          (for generator)          (for state)          (for control)          f    
           N   S     
          Á@        ^       	       .     
   O   O   O   P   P   P   P   P   R   S         iref     	   	   instance     	           \   y    '   Ë @ @  Ü @À@  FÁ@ Á CAA A   @ @  À  BA@  @ W@À@A   @ ÂÁB     ÆBÂ À  Þ    
   
   getObject     getTypePathChunkByID 	   is_multi 	       parent    insertObject    key        id     '   ]   ]   ]   ]   ^   ^   b   b   b   c   c   c   e   f   f   f   i   i   i   k   k   k   k   k   k   o   o   t   t   t   t   t   t   t   t   t   t   x   y         db     &      tp_id     &      iref     &      obj    &   	   tp_chunk 	   %      parent    %      
   getObject            
   Ë @ @ ÜA  @  AA  FÁÀW Á  BA  B A AÁFÁÁ  À   @  À   Þ        getTypePathChunkByID    assert    typepath id needs to exist 	   is_multi 	      path must be multi instance    typepath_chunk    parent                                                                                            db           tp_id           iref        	   tp_chunk          child       	   ppath_id          parent          
   getObject        Æ    ]   Ä  ËÀAB   À ÜA Ä   Ü Ó @ Ú  @@  @ Â@ À    @   Â@FA    À W@A  Ä Ü ÂÄ  ËÂÁ@ ÜBÄ ÆÂ  ÜB    	À  @    ËBB @ À ÜÂ ÂD Ã À  @ \   ÃA C BÀC Ú   KC À @ \C  BÁB B         debug    addInstance: %s, %d, %d 	   getCount 	   	      string    key is not a string but     error    InternalError    insertObject  5   database: %s, tp_id='%d', ireferences='%s', key='%s' 	   setCount !   Persistency: no instance to add!     ]                                                                              ¡   ¡   ¢   £   £   ¥   ©   ©   ©   ©   ©   ª   ª   ª   ª   ª   «   «   «   «   ¬   ¬   ¬   ¬   ¯   ¯   ±   ±   ±   ±   ±   ±   ³   ³   ´   µ   ¶   ³   ·   ·   ¸   ¸   ¸   ¸   ¸   ¸   ¸   ¹   ¹   ¹   ¹   º   º   º   º   ¼   ¼   À   À   À   À   À   Â   Å   Å   Å   Å   Æ         db     \      cpath     \      iref_parent     \      tp_id     \      key     \      parent_db_id     \      keyIsTable     \      endsWithTransformed    \   	   instance    \      actual_key    \      err_msg )   1      refs 9   X      obj ?   X      msg ?   X      err_msg H   P         logger    endsWithPassThroughPlaceholder 	   tostring    type    fault    string_append_instance    format     Ì   Ò       Ä     Ü @ A@ À   @ F@^         _db 
   getObject    key        Í   Í   Í   Î   Î   Î   Î   Î   Ï   Ï   Ð   Ð   Ò         self           tp_id           ireferences           iref          obj             string_from_ireferences     Ø   Ý       Æ @ Ë@À@  Ü Ú   À   FÀ           _db    getObjectByKey    ireferences        Ù   Ù   Ù   Ù   Ù   Ú   Ú   Û   Û   Û   Û   Ý         self           tp_id           key           obj             ireferences_from_string     ä   ì       Æ @ Ë@À@  Ü Ú   À  FÀ T @@ FA^         _db    getObjectByAlias    ireferences 	    	          å   å   å   å   å   æ   æ   ç   ç   ç   è   è   è   é   é   ì         self           tp_id           alias           obj          irefs 
            ireferences_from_string     ò   ü       Ä     Ü @ D  À  \ A@  FÀ Ê   @ @ FÃ@ÉÁ!  ÀþÞ         _db    getAliases    id    alias        ó   ó   ó   ô   õ   õ   õ   õ   õ   ö   ö   ö   ö   ÷   ø   ø   ø   ø   ù   ù   ø   ù   û   ü         self           tp_id           ireferences_parent           iref          db          parent 	         known_aliases_db          known_aliases          (for generator)          (for state)          (for control)          _          entry             string_from_ireferences    getParentOfMulti    pairs             @ D   \  À   @Á B  @   B @ WÀ@  B   D À @ ÆA  ] ^          _db    assert    a parent does not exist    table    id                                  
  
  
  
  
  
  
                        	      self           tp_id           ireferences_parent           key           db          iref          parent 	         cpath 	         keysTuples             string_from_ireferences    getParentOfMulti    type    addInstance          	   Ä     Ü @ A@ ÀA         _db    deleteObject     	                           self           tp_id           ireferences           iref             string_from_ireferences       e   q   Ê    @  Þ  A@  F@W ÀÀFÁ@W Á KA@ ÆÁ@\  ýFÁ@ Á  Þ  KAA ÆA\Z     À ÀA  Þ   ÀÀÊ  
 FB"C ÉÃ@ÉÉÀ¡  @ý @  B A  ÀÔ  Á  À
Æ@ÆÁB@ FÂ@ Á  B @W @@ B     @ À ÀÄ  Ü@EÂ	FÅB@
@Z  @Â	FÂ	T
LÀ
B	
Å@Éá  Àû¡  @ú   ò À@ ÆBÉÀ¡  ÀþÞ       	      getTypePathChunkByID 	   is_multi    parent 	       getSiblings    tp_id     key    nextparent    getParents    id     q                                            "  "  "  $  (  (  (  )  )  )  )  )  )  )  +  .  .  .  .  /  /  /  /  /  /  /  /  .  /  2  4  4  6  6  6  7  7  7  7  7  9  >  >  ?  ?  ?  @  @  @  B  E  F  F  F  I  I  L  O  O  O  O  Q  Q  Q  Q  R  R  R  R  S  S  T  T  T  T  T  T  W  W  Q  X  O  Y  ]  ]  a  a  a  a  b  b  a  b  d  e        db     p      tp_id     p      level     p      keys    p   	   tp_chunk    p      level_keys    p      (for generator) $   /      (for state) $   /      (for control) $   /      i %   -      row %   -      parent_keys 5   f      parent_tp_id =   f      parent_tp_chunk @   f      append_keys E   f      (for generator) N   e      (for state) N   e      (for control) N   e      _ O   c      row O   c      (for generator) R   c      (for state) R   c      (for control) R   c      _ S   a      found S   a      (for generator) j   o      (for state) j   o      (for control) j   o      i k   m      entry k   m         next    ipairs    pairs     m  x      Ä     Ü W À  @  Å   FÁ@  À ÜÀÚ@  @D KÁÀ \AJ  ^          number 	      pcall    _db    error        n  n  n  n  n  o  q  q  q  q  q  q  r  r  t  t  t  t  u  u  w  x        self           tp_id           level           ok          result             type    query_keys_impl    logger                 Ô  À  @ X@    Â@  Â  Þ  X @  Â@  Â  Þ       	                                                 iref1           iref2           diff                 Ç  	 Y   
  J    À Ä    @  ÜÁ E  ÁB  \BK@ ÆÂÀ  \      @Ä AÜ @Á   Ä  Ü      ÁF 	Z  ÀÆDIÂÁIÂA FÂ	 A
Ä   @  À  FÆÀ Ü 	I	  À Ô ÌÁ					á   ÷Ä  Ü  @ @AÀ DB ÂÆÂD á   ýÄ  D ÜBÀ  Þ        assert    a parent does not exist    getChildren    id 	      table 	       ireferences    deleteObject    tp_id     Y                                                                    ¡  ¡  ¢  ¤  ¥  ¦  ¦  §  «  ¬  ¯  ¯  ¯  °  °  ³  ³  ³  ³  ³  ³  ³  ³  ³  ³  ´  ¶  ¶  ·  ·  ·  ¸    ¹  ¿  ¿  ¿  ¿  À  À  À  À  À  Á  Á  Á  Á  ¿  Â  Å  Å  Å  Å  Æ  Æ  Æ  Ç        db     X      tp_id     X      keys     X      ireferences_parent     X      keymap    X      new_entries    X      iref    X      parent 
   X      child 
   X      db_objects    X      keysTuples    X      (for generator)    B      (for state)    B      (for control)    B      _    @      key    @      actual_key     @      index $   @   	   instance %   @      obj (   .      inst -   .      (for generator) E   Q      (for state) E   Q      (for control) E   Q      _ F   O      obj F   O   	      string_from_ireferences    getParentOfMulti    type    ipairs    ireferences_from_string    addInstance    pairs    sort 
   iref_sort     Ø  í   %   @ C ËA@B  Ü E    À   @ \@  [   @Z  À Â@ B A BB   B ÀB À         _db    startTransaction    pcall    commitTransaction    rollbackTransaction    error     %   Ù  Ú  ß  ß  ß  à  á  á  á  á  á  á  á  á  á  á  â  â  â  ã  ã  ä  ä  ä  ä  æ  æ  æ  è  è  ê  ê  ê  ì  ì  ì  í  
      self     $      tp_id     $      keys     $      ireferences_parent     $      db    $      keymap    $   	   new_keys    $   
   savepoint    $      ok    $      commit    $      
   sync_impl     ó     .   J      À   À  Ú    	W À   D \ Z  À @A  @A  Õ   @ ÕT LÀ  Á@A  ÂA  Â ÁI D    \Á À    ö^              . 	      chunk    multi      .   ô  õ  õ  õ  ö  ÷  ÷  ÷  ÷  ø  ù  ù  ù  ù  ù  ú  ú  ú  ú  ü  ü  ü  ý  ý  þ  þ  þ                                                     	   typepath     -   
   tp_chunks    -      first    -      chunk    -      multi    -         stripEndNoTrailingDot    isMultiInstance              @ @@  @                _db    insertTypePath                              self        	   typepath              create_tp_chunks              F @ K@À \@ 	@        _db    close                         self                         F @ K@À Â  \@        _db    startTransaction                        self                   "       F @ K@À \@         _db    commitTransaction        !  !  !  "        self                (  *       F @ K@À \@         _db    rollbackTransaction        )  )  )  *        self                -  3      @  Ä   Æ@À   @ ÜÀ Ä    D Ý Þ           _db    new        .  /  /  /  /  /  /  2  2  2  2  2  3        dbpath           dbname           p             db    setmetatable    Persistency u                                             !   !   !   "   "   "   "   "   "   #   #   #   $   $   $   '   )   )   +   8   8   G   S   y   y         Æ   Æ   Æ   Æ   Æ   Æ   Æ   Æ   Ò   Ò   Ì   Ý   Ý   Ø   ì   ì   ä   ü   ü   ü   ü   ò                     e  e  e  e  x  x  x  x  m    Ç  Ç  Ç  Ç  Ç  Ç  Ç  Ç  Ç  Ç  í  í  Ø                      "     *  (  ,  3  3  3  3  -  5  5        M    t      require    t   	   tostring    t      pairs    t      ipairs    t      setmetatable    t      type    t      next    t      format 
   t      concat    t      sort    t      db    t      logger    t      pathFinder    t      fault    t      stripEndNoTrailingDot    t      isMultiInstance     t      endsWithPassThroughPlaceholder     t      Persistency !   t      string_from_ireferences #   t      ireferences_from_string $   t      string_append_instance %   t   
   getObject '   t      getParentOfMulti )   t      addInstance 1   t      query_keys_impl L   t   
   iref_sort R   t   
   sync_impl \   t      create_tp_chunks b   t       