LuaQ               (      A@   E     \@ J   €   δ@  $         dΑ  €      I€A δ $Β d €B   δ   $Γ              d        €C      I^          require    lfs    libos    populate_installed_apps    able_to_upgrade                	    Ε   Ζ@ΐ  @  άΑ  A@ A  EA  ΑAΑ   \A   FABW@@EA  ΑAΑ   \A @   ΐ \A        string    format    %s/manifest.json    json    load    syslog    LOG    WARNING    R-app without manifest '%s'    package $   R-app path does match manifest '%s'                        #        E   @  \ @ΐ    ΐa  ΐύ        pairs    installed_rapps    pid                     %   .           @ΐ    @A  @ΑΑ     @ Δ  ΖΑ  AB άΑ WΐΑW Β Δ   @ άA ‘@  ΐω  	      dir    string    format    %s/%s    attributes    mode 
   directory    .    ..                     0   6        E   F@ΐ   \    Αΐ  
  EA 	AFΑ 	A@        json    load    /dumaos/dumaos.json    /    package 
   OS_RAPPID    version                     8   <       D      ΐ   \@D   @  ΐ   \@D     \@         /dumaos/apps/system/    /dumaos/apps/usr/                     ?   T      2     Ε   Ζ@ΐ  ά Α  A@A  @  @Β  A@ EΒ  ΖBB ΑΒ CB\ Β  CΐC   @ @ @Β  Cΐ           !A   χ   @         os    get_cmd_output    cat /proc/mtd    string    gmatch 	   ([^
]*)
    split 
   assertion 	   tonumber 	   	      abnormal mtd token '%s'    find    rootfs    kernel                     X   ]            @@ A   Eΐ  F Α    \ @ Ε ΑΑ ά  FΑΑ  Ξ@Bή    
      os    get_cmd_output    du -sk /dumaos/apps/usr/    string    split    assert 	   tonumber 	      Abnormal du token '%s' 	                       _   h     	#   @       E@  Fΐ ΐ  ΐ   \  @Aΐ   Ε  Ζ@ΑΑAά  EA ΑΑ\  ΖΑΑ E A ΖΑΒ Α ΒΒ\ AAC         /    os    get_cmd_output    df -k '%s'    string    split    
 	      assert 	   tonumber    Abnormal df size token '%s' 	      Abnormal df used token '%s' 	                       j   r     	      @@ΐ        @Λΐ@ά  ΐ   άA α@  ώΒ  ή          io    open    r    lines                     t        3   
   J     Α   A  ’@ δ            @  D   ΐ\Β  ΐ @ B !   ύA E   \@    @Β Α   @B   Ζ  ΕΓ   άC ‘  ώAa  ΐϊ   	   #   /lib/upgrade/ramfs-data-files.list &   /lib/upgrade/ramfs-install-files.list    ipairs 
   assertion "   Failed to populate files for '%s' 	       pairs    print    indoe, size        |       2   E   F@ΐ   ΐ   \ΐ   Aΐ  A Ε   ά  Β  A@ EΒ  ΖBB Α CB\ Β Ε ΓBά  FΓB Δ  ΙBΔ ΖΪB   Δ 
  ΙΕ ΖBΓ FCάBα   χ        os    get_cmd_output    stat -Lt '%s' 2>/dev/null    string    split    
    ipairs    assert 	   tonumber 	      Abnormal stat token '%s' 	      table    insert 	                                      °           d          Α@    Ε    AΑ  ά@       	       /etc/sysupgrade.conf 
   assertion $   Unable to read /etc/sysupgrade.conf        ’   «       E   F@ΐ    Α  \Z@  ΐE   F@ΐ    Αΐ  \Z    E  F@Α    \ Z      Ε  Ζ@Α   ά ΐ            string    find    ^#    [^%s]+    os    file_disk_usage                                 ³   ζ    D     Α   Ϋ   ΐB  A  Δ   ά  D \  BΝΓ LC  LLCCΕΓ   DAA ΐάCΕΓ   DAAΔ ΐ άCΕΓ   DAA  ΐάCΑC ΐΐ  AΔ    ΐΐ  A    @Cΐ  A           
   assertion "   Unable to get mtd partition sizes    /tmp    syslog    LOG    INFO    tmpfs free='%u' used='%u'
    rootfs free='%u' used='%u'
    kernel free='%u' used='%u'
 	   
   error_ret    Not enough volatile memory    Not enough flash memory 	     Not enough memory for kernel                     θ      k     @   A   EA    ΐ  ]^  FΑ@ZA   EA   ΐ  ]^  FΑ@A AΑΑ  Δ  ΖΒ  ά ΪA   B  AB     ΒWΐB@B  A Βΐ     B CFΒ@ EΒ  \ ZB   EB   ΐ  ]^  EB FΓ \ Β ΐ B   B  ΑB      @ B  Α       ΑΒ  Μ ΒΔ ά CΝ E@C  AC  ΐ      Ε@C  A ΐ               rappdb_get 
   error_ret    R-App '%s' not installed    path    R-App '%s' has no path    string    format    %s/data    attributes *   Nonexistent data directory for R-App '%s'    mode 
   directory    data is '%s' for R-App '%s'    os    file_disk_usage 	   tonumber -   Cannot calculate R-App memory usage for '%s' 5   Unable to calculate R-App data memory usage for '%s' -   R-App '%s' total memory usage less than data    /tmp 	   #   Not enough RAM(%s) to install '%s' %   Not enough flash(%s) to install '%s'                     "  (   
   E  @ ΐD   ΐ  @ ]^  D   ΐ   @]^       
   OS_RAPPID                             