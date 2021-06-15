/*
* (c) 2016 netduma software
* iain fraser <iainf@netduma.com>
*
* DumaOS cyclic promise API
* TODO: Devicedb should work with this, one lookup per cycle
*/

/*
* Wait for timeout with ability to start/stop
*/

function _wait_do_finish( polling ){
    polling.timeout_id = null;
    polling.remain = 0;
    polling.defer.resolve( polling );
}

function _wait_finish( polling ){
  if( wait_is_playing( polling ) ){
    clearTimeout( polling.timeout_id );
    _wait_do_finish( polling );
  }
}

function wait_create( period ){
  return {
    remain : 0,
    period : period,
    timeout_id : null
  }
}

function wait_pause( polling ){
  if( wait_is_playing( polling ) ){
    clearTimeout( polling.timeout_id );
    polling.remain = Math.max( 
        polling.remain - ( timeGetTime() - polling.started ) , 0 );    
    polling.timeout_id = null;
    return polling.defer.promise;
  }

  throw new Error("Cannot pause because it is not playing.");
}

function wait_play( polling ){
  if( wait_is_paused( polling ) ){
    polling.started = timeGetTime();
    polling.timeout_id = setTimeout( _wait_finish, polling.remain, polling );
    return polling.defer.promise;
  } else if ( wait_is_stopped( polling ) ){
    polling.defer = Q.defer();
    polling.remain = polling.period;
    polling.started = timeGetTime();
    polling.timeout_id = setTimeout( _wait_finish, polling.remain, polling );
    return polling.defer.promise;
  }
  
  throw new Error("Cannot resume because it is not paused.");
}

function wait_update_period( polling, period ){
  polling.period = period;
}

function wait_is_playing( polling ){
  return polling.timeout_id != null;
}

function wait_is_paused( polling ){
  return polling.timeout_id == null && polling.remain > 0; 
}

function wait_is_stopped( polling ){
  return polling.timeout_id == null && polling.remain == 0;
}


/*
* Engine processing
*/
//TODO fix setTimeout recursive stack overflow. Make it an actual proper useful scheduler
function start_cycle( gen_input_promise, process, wait, inductive_case ){
  var start;

  // on non base-case wait time period
  if( inductive_case ){
    if( Number.isInteger( wait ) )
      wait = wait_create( wait )
    start = wait_play( wait );
  } else {
    start = Q(); 
  }

  start
  .then( gen_input_promise )
  .spread( process )
  .done( 
    function(){
      start_cycle( gen_input_promise, process, wait, true )
    },
    function(e) {
      console.log("cycle failed");
      throw e;
    });

  return wait;
}
