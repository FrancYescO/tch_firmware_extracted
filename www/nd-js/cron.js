/*
 * (C) 2017 NETDUMA Software
 * Luke Meppem <luke.meppem@netduma.com>
*/

class Cron {
  constructor(cronString=null) {
    this.minutes = new Array(60).fill(true);
    this.hours = new Array(24).fill(true);
    this.days = new Array(31).fill(true);
    this.months = new Array(12).fill(true);
    this.weekdays = new Array(7).fill(true);
    if(cronString) this._cronToBools(cronString);
  }
  _overrideArray(to,from){
    if(from.length > to.length){
      console.error("Cron Error! Input is longer than target array");
      return;
    }else{
      for(var i = 0; i < from.length; i ++){
        to[i] = !!from[i];
      }
    }
  }
  setMinutes(arr){
    if(arr.hasOwnProperty("length"))
      this._overrideArray(this.minutes,arr);
  }
  setHours(arr){
    if(arr.hasOwnProperty("length"))
      this._overrideArray(this.hours,arr);
  }
  setDays(arr){
    if(arr.hasOwnProperty("length"))
      this._overrideArray(this.days,arr);
  }
  setMonths(arr){
    if(arr.hasOwnProperty("length"))
      this._overrideArray(this.months,arr);
  }
  setWeekdays(arr){
    if(arr.hasOwnProperty("length"))
      this._overrideArray(this.weekdays,arr);
  }
  am(){
    return this.hours.slice(0,12);
  }
  pm(){
    return this.hours.slice(12);
  }
  
  _boolsToCron(boolList,error,offset=0){
    if (!boolList.includes(true)) {
      console.log("CRON list '" + error + "' has no true values. CRON is invalid.");
      return null;
    }
    if (!boolList.includes(false)) {
      return "*";
    }
    var inters = [];
    var start = -1;
    for (var i = 0; i < boolList.length; ++i) {
      if (start == -1 && boolList[i]) {
        start = i;
      } else if (start != -1 && !boolList[i]) {
        inters.push([start + offset, (i - 1) + offset]);
        start = -1;
      }
    }
    if (start != -1) {
      inters.push([start + offset, (boolList.length - 1) + offset]);
    }
    var out = [];
    for (var i = 0; i < inters.length; ++i) {
      if (inters[i][0] == inters[i][1]) {
        out.push(inters[i][0].toString());
      } else {
        out.push(inters[i][0] + "-" + inters[i][1]);
      }
    }
    return out.join(',');
  }

  _cronToIntervals(cron,offset=0){
    var inters = []
    for(var i = 0;i < cron.length;++i){
      if(cron[i].indexOf('-') == -1){
        inters.push([parseInt(cron[i]) - offset,parseInt(cron[i]) - offset]);
      }else{
        var s = cron[i].split('-');
        inters.push([parseInt(s[0]) - offset,parseInt(s[1]) - offset]);
      }
    }
    return inters;
  }
  
  _intervalsToBools(inters,length){
    var out = [];
    for(var i = 0;i<length;++i){
      var push = false;
      for(var a = 0;a<inters.length;a++){
        if(inters[a][0] <= i && i <= inters[a][1]){
          push = true;
        }
      }
      out.push(push);
    }
    return out;
  }
  
  _cronToBools(cronString){
    if(cronString.match(/[^0-9,\- *]/gm)) {
      console.error("Only simple cron is currently supported. Please use only numbers, commas, asterisks and dashes.")
    }
    var crons = cronString.split(' ');
    var _min = crons[0].split(',');
    var _hours = crons[1].split(',');
    var _days = crons[2].split(',');
    var _months = crons[3].split(',');
    var _weekdays = crons[4].split(',');
    
    this.setMinutes(_min == '*' ? new Array(60).fill(true) : this._intervalsToBools(this._cronToIntervals(_min),60));
    this.setHours(_hours == '*' ? new Array(24).fill(true) : this._intervalsToBools(this._cronToIntervals(_hours),24));
    this.setDays(_days == '*' ? new Array(31).fill(true) : this._intervalsToBools(this._cronToIntervals(_days,1),31));
    this.setMonths(_months == '*' ? new Array(12).fill(true) : this._intervalsToBools(this._cronToIntervals(_months,1),12));
    this.setWeekdays(_weekdays == '*' ? new Array(7).fill(true) : this._intervalsToBools(this._cronToIntervals(_weekdays),7));
  }

  /**
   * Turn into a cron string
   */
  toString(){
    var minutesCron = this._boolsToCron(this.minutes,'minutes');
    var hoursCron = this._boolsToCron(this.hours,'hours');
    var daysCron = this._boolsToCron(this.days,'days',1);
    var monthsCron = this._boolsToCron(this.months,'months',1);
    var weekdaysCron = this._boolsToCron(this.weekdays,'weekdays');
    return [minutesCron,hoursCron,daysCron,monthsCron,weekdaysCron].join(" ");
  }

  _arrsMatch(arr1,arr2){
    if(arr1.length !== arr2.length) return false;
    for(var i = 0; i < arr1.length; i ++){
      if(arr1[i] !== arr2[i]) return false;
    }
    return true;
  }

  /**
   * How well this cron matches a given cron
   * @param {*} cron A Cron object or cron string
   */
  matches(cron){
    if(typeof(cron) === "string") cron = new Cron(cron);
    return {
      minutes: this._arrsMatch(this.minutes, cron.minutes),
      hours: this._arrsMatch(this.hours, cron.hours),
      days: this._arrsMatch(this.days, cron.days),
      months: this._arrsMatch(this.months, cron.months),
      weekdays: this._arrsMatch(this.weekdays, cron.weekdays)
    };
  }

  /**
   * Is the given date active on this cron.
   * @param {*} date The date to check the cron against. Defaults to now.
   * @param {*} returnAll If true, returns a bool value for each section (minute, hour, day, month, weekday). Defaults to false.
   */
  is(date=false,returnAll=false){
    var now = date ? date : new Date();
    var minute = now.getMinutes();
    var hour = now.getHours();
    var day = now.getDate();
    var month = now.getMonth();
    var weekday = now.getDay();

    var all = {
      minute: this.minutes[minute],
      hour: this.hours[hour],
      day: this.days[day-1],
      month: this.months[month],
      weekday: this.weekdays[weekday]
    }
    if(returnAll){
      return all;
    }else{
      return all.minute && all.hour && all.day && all.month && all.weekday;
    }
  }

  /**
   * Returns date of the next time the cron runs.
   * @param {*} max An integer representing the maximum time in the future to check. Default is 1 year (31,536,000,000).
   * @param {*} interval An integer representing the gaps between checks. Default is 1 minute (60,000).
   */
  next(max=31536000000,interval=60000){
    var count = 0;
    var start = Math.ceil(Date.now()/interval)*interval;
    while(count < max){
      var date = new Date(start + count);
      if(this.is(date)){
        return date;
      }
      count += interval;
    }
    return null;
  }
}

/**
 * var cron = new Cron("2,3,10-11 * * * *")
 * cron.setMinutes([true,false,true,true,false,true,false,...])
 * cron._cronToBools("9-23,32-40 20 * * *")
 * cron.toString()
 */
