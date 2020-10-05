/***************
   voiceService
****************/
angular.module('fw').service('voiceService',['$q','$log','$filter','api','fwHelpers', function($q, $log, $filter, api, fwHelpers) {
	var voice_log_props = ['id', 'date', 'duration', 'phone', 'type'];
	
	this.voice_log = function() {
		return api.get('voice_log').then(function(data) {
			return fwHelpers.objectToArray(data, 'log', data.total_num, voice_log_props);
		});
	};

	this.get_voice_log_available = function(){
		return api.get('voice_log').then(function(data) {
			return data.voice_log_available;
		});
	}

	this.voice_log_del = function(item){
		return api.set('voice_log_del', item);		
	}
}]);