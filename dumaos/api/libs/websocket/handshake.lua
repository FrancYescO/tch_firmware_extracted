LuaQ               	       A@  @    A   ΐ@ E     \ F Α @ AΑΐ $           dA  €     δΑ          
 		B	Β	         require    pack    websocket.tools    sha1    base64    table    insert %   258EAFA5-E914-47DA-95CA-C5AB0DC85B11    sec_websocket_accept    http_headers    accept_upgrade    upgrade_request        
          @      U   ΐ   Ε    A@W@  A   ά@ Δ  Ζΐΐ  έ  ή           assert 	   	       encode                        +     A   J    @ A  @    ^   @        Λΐ@ A ά  
Λ@AB άΑΪ  ΐ  @KΑ\ ΐKΐΑΒ \ZB   KA\  FΒ ZB  @ I @FΒ  ΐ UΒI@ΐ@B@   ΐE   ΐ Γ T  Υ\Bα@   υΐ  @ A ή           match    .*HTTP/1%.1    [^
]+
(.*)    gmatch 	   [^
]*
    ([^%s]+)%s*:%s*([^
]+)    lower    sec%-websocket    ,    
    assert    (    ) 	   

(.*)                     -   @    @   E   F@ΐ  ΐ    FΑ@ ZA    A ά  AA A AΑ  ΐ B FB ά  AΒ  BCΖC Γ   A ’@Ζ@D Ϊ   ΐΔ     E  FAΐ ΖAD \ά@  ΖΐD Ϊ    ΖΐD W Ε@ΐ   FA ΑD ά ΐΔ     AΑ ά@Ε  Ζ@Γ  AΑ έ ή           string    format    GET %s HTTP/1.1    uri     	   Host: %s    host    Upgrade: websocket    Connection: Upgrade    Sec-WebSocket-Key: %s    key    Sec-WebSocket-Protocol: %s    table    concat 
   protocols    ,     Sec-WebSocket-Version: 13    origin    Origin: %s    port 	P   	      Host: %s:%d    
                     B   d    T      ΐ    Ζ @@ΐΖ@Ϊ   ΐΖ@ΛΐΐA  άΪ   @Ζ AW@Α ΖAWΐΑ Γ  ή Γ AB  ΐABBΑ   @ ΐ ΐ@ ΐ @ !  @ώΪ     @ !A   ό
AA  ΑΑ @Υ BDA  ΖA   "A  Ϊ   ΐD  Ε ΖAΔΒ @ά\A  D  Α \AEA FΕ Α \^        upgrade 
   websocket    connection    match    sec-websocket-key     sec-websocket-version    13    HTTP/1.1 400 Bad Request

    sec-websocket-protocol    gmatch    ([^,%s]+)%s?,?    ipairs !   HTTP/1.1 101 Switching Protocols    Upgrade: websocket    Connection:     string    format    Sec-Websocket-Accept: %s    Sec-Websocket-Protocol: %s    
    table    concat                             