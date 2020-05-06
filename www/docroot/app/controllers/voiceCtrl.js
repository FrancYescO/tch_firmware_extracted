angular.module('fw').controller('voiceCtrl', ['$log', '$scope', 'voiceService', '$filter', 'navService',
  function($log, $scope, voiceService, $filter, navService) {
	
	$scope.voice_list_isExpanded = true; 
	$scope.filterHistoryTable = {type:'received'};
	$scope.badge = {received: 0, lost: 0, done: 0, all: 0};	
	$scope.datatime = {};	

	var filter = $filter('filter');

	$scope.init_voice_log = function(){
		voiceService.voice_log().then(function(data){			
			$scope.voice_list = data;
			$scope.voice_list_orig = angular.merge([], $scope.voice_list);			
			setBadge();
			$scope.setLastVisited('received');
		});
	}

	$scope.deleteVoice = function(item){
		var bl = $scope.voice_list,
            idx = bl.indexOf(item);
        if(idx >= 0) bl.splice(idx, 1);
	}

	$scope.deleteAll = function(arrayFilter){
		var bl = $scope.voice_list;
		for (var i = 0; i < arrayFilter.length; i++) {
			idx = bl.indexOf(arrayFilter[i]);
        	if(idx >= 0) bl.splice(idx, 1);
		}            
	}

	$scope.getDurationString = function(duration){
		if(parseInt(duration) == 0) return 0;
		var durationStr = '';
		var durationObj = moment.duration(parseInt(duration), 'seconds');

		durationStr += durationObj['_data'].days != 0 ? durationObj['_data'].days + 'd ' : '';
		durationStr += durationObj['_data'].hours != 0 ? durationObj['_data'].hours + 'h ' : '';
		durationStr += durationObj['_data'].minutes != 0 ? durationObj['_data'].minutes + '\'' : '';
		durationStr += durationObj['_data'].seconds != 0 ? durationObj['_data'].seconds + 's' : '';

		return durationStr;
	}

	$scope.setLastVisited = function(type){	
		var item = filter($scope.voice_list, {type: type})[0];

		if(typeof(item) != 'undefined') {
			$scope.datatime[type] = item.date;	
			window.localStorage && localStorage.setItem("last_visited_voice_page", JSON.stringify($scope.datatime));
			$scope.badge[type] = 0;
		}

		if(type == 'all') $scope.badge['all'] = 0;

			
	}

	$scope.saveVoice = function(){
		var toDelete = [],
            vm = $scope.voice_list,
            old = $scope.voice_list_orig;

		angular.forEach(old, function(oldItem, key){			
            var newItem = filter(vm, {id: oldItem.id})[0];
            if(!newItem) {
            	toDelete.push(oldItem.id.toString());
            }
        });
        if(toDelete.length > 0) {
			voiceService.voice_log_del({
				total_num: toDelete.length,
				id: toDelete.join(',')
			});
		}
        $scope.voice_list_orig = angular.merge([], $scope.voice_list);
	}

	$scope.cancelVoice = function(){
		$scope.voice_list = angular.merge([], $scope.voice_list_orig);
	}

	navService.isDirty(function() {
        return  $scope.voice_list_orig &&
                angular.toJson($scope.voice_list) != angular.toJson($scope.voice_list_orig);
    });

	var setBadge = function(){
		$scope.datatime = {};
		if(window.localStorage)
			$scope.datatime = JSON.parse(localStorage.getItem('last_visited_voice_page') || '{}');
		if($scope.datatime != null){
			angular.forEach($scope.badge, function(value, key){				
				var voice_list_filter = filter($scope.voice_list, {type: key});
				angular.forEach(voice_list_filter, function(voiceValue, voiceKey){
					var a = moment($scope.datatime[key]);
					var b = moment(voiceValue.date);
					if(a.diff(b) < 0 || typeof($scope.datatime[key]) == 'undefined'){ $scope.badge[key]++;  $scope.badge['all']++;}
				});				
			});
		}
	}

	$scope.init_voice_log();

}]);