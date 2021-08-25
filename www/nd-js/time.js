/*
 * (C) 2020 NETDUMA Software
 * Luke Meppem
*/

//Library to help transition between router time zone and local time zone

var tzPackage = "com.netdumasoftware.config";
var duma = duma || {};
duma.time = duma.time || {
  valid_time_zones: [],
  __routerTimeZone: 18, //18 is uk
  __applyDST: true,
  _currentTimes: [],
  _timeLooperTimeout: null,

  isValidTimeZoneID: function(id){
    for(var i = 0; i < this.valid_time_zones.length; i++){
      var tz = this.valid_time_zones[i];
      if(tz.id === id)
        return true
    }
    return false;
  },
  get router_time_zone(){
    return this.__routerTimeZone;
  },
  set router_time_zone(val){
    if(!this.isValidTimeZoneID(val)) throw new Error("attempted to set router_time_zone to an invalid time zone id: " + val.toString());
    this.__routerTimeZone = val;
    duma.events.fire("router-time-zone-changed",{ value: val });
  },

  get apply_dst(){
    return this.__applyDST;
  },
  set apply_dst(val){
    if(typeof val !== "boolean") throw new Error("apply_dst must be type Boolean.");
    this.__applyDST = val;
    duma.events.fire("router-apply-dst-changed",{ value: val });
  },

  getTimeZone: function(){
    return long_rpc_promise(tzPackage,"get_time_zone",[]).then(function(result){
      if(result && result.length){
        this.router_time_zone = result[0] || 18;
        this.apply_dst = !!result[1];
      }
    }.bind(this));
  },
  setTimeZone: function(timezone,dst){
    if(typeof timezone !== "undefined"){
      this.router_time_zone = timezone; 
    }
    if(typeof dst !== "undefined"){
      this.apply_dst = dst;
    }
    return this.save();
  },
  // Save the current set router_time_zone and apply_dst
  save: function(){
    return long_rpc_promise(tzPackage,"set_time_zone",[this.router_time_zone,this.apply_dst]);
  },
  // A promise to get the current time according to the router
  get current_router_time(){
    return long_rpc_promise(tzPackage, "get_time_data", []);
  },

  get current_router_time_zone(){
    for(var i = 0; i < this.valid_time_zones.length; i++)
      if(this.valid_time_zones[i].id === this.router_time_zone)
        return this.valid_time_zones[i];
  },

  init: function(){
    if(!top.apMode){
      //Get all time zones
      long_rpc_promise(tzPackage,"get_time_zones",[]).then(function(result){
        this.valid_time_zones = result[0] ? JSON.parse(result[0]) : [];
        duma.events.fire("router-time-zones",{value:this.valid_time_zones});
      }.bind(this)).then(function(){
        this.getTimeZone();
      }.bind(this));
    }
    return this;
  },

  // Used to get a user-friendly time with the router's timeZone
  toRouterTime: function(date,locale,options){
    options = options || {};
    options.timeZone = this.current_router_time_zone.iana;
    return (date ? new Date(date) : new Date()).toLocaleString(locale || {},options);
  },

  fromRouterTime: function(dateString){
    // regex grabs the time zone from inside ( ) in string if it exists, such as (GMT+1)
    return new Date(dateString + " " + this.current_router_time_zone.display.match(/\((.*?)\)/)[1]);
  },

  // A loop that will be called every second, and provide the router's current time. The RPC will only fire if at least one of the conditions is true.
  currentTimeLoop: function(callback,condition){
    if(typeof callback !== "function") throw new Error("callback must by type function.");
    this._currentTimes.push({
      func: callback,
      condition: condition || true
    });
    if(!this._timeLooperTimeout)
      this._timeLooperTimeout = setTimeout(this._timeLooper.bind(this),0);
  },
  _timeLooper: function(){
    var _currentTime_ = 0;
    var _refreshTime_ = 30;
    var _nextRefresh_ = 0;
    function __setTime(time){
      _currentTime_ = time;
      _nextRefresh_ = time + _refreshTime_;
    }
    __setTime(Math.round(Date.now() / 1000)); // start of with local time, as it's likely it's the same time zone
    duma.events.cycle(function(){
      var allow = new Array(this._currentTimes.length).fill(false);
      var any = false;
      for(var i = 0; i < this._currentTimes.length; i++){
        var ret = !!this._currentTimes[i].condition.call(this);
        if(ret) any = true;
        allow[i] = ret;
      }
      var __doCallbacks = function(time){
        for(var i = 0; i < this._currentTimes.length; i++){
          if(allow[i]){ // only callback those who's conditions met
            try{
              this._currentTimes[i].func.call(this,_currentTime_);
            }catch(e){
              console.error(e);
            }
          }
        }
      }.bind(this);

      // if any of the conditions are met, and currentTime >= to refresh, then re-get the time from the router.
      // otherwise, just increment by 1 instead of calling the rpc
      var promise;
      if(_currentTime_ >= _nextRefresh_ && any){
        promise = this.current_router_time.then(function(result){
          if(!result[0]) return;
          this.router_time_zone = result[0].timezone;
          __setTime(result[0].time);
        }.bind(this))
      }else{
        promise = new Promise(function(resolve,reject){
          resolve(++_currentTime_); // update time without updating _nextRefresh_
        }.bind(this));
      }
        
      return promise.then(function(){
        if(any) __doCallbacks(_currentTime_);
      });
    }.bind(this),1000);
  },

  // Alter the timezone according to the offset (in hours). Useful when dealing with cron and moment
  date_with_offset: function(date,offset){
    // multiply into unix amount for hours
    var timeOffset = offset * (60 * 60 * 1000);
    return new Date((date || new Date()).getTime() + timeOffset);
  }
}.init();
