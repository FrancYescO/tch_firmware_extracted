angular.module('fw')
    .filter('labelForKey', function() {
        return function (items, key, fallback) {
            if(items && items.length) {
                for (var i = 0; i < items.length; i++) {
                  if(items[i][0] == key)
                    return items[i][1];
                }
            }
            return fallback||'------';
          };
    })
    .filter('fwDate', function() {
        return function (date, format) {            
            if(typeof(date) != 'string' || date.split('T').length <= 1){ return ''; }            
            else{ return typeof(format) == 'undefined' ? moment(date).format('DD/MM/YYYY HH:mm') : moment(date).format(format); }
        };
    })
    .filter('fwTime', function() {
        return function (time) {
            if(time == 9999)
                return '00:00';
            if(time && time.length == 4)
                return time[0]+time[1]+':'+time[2]+time[3]
            return '----';
        };
    })
    
;