angular.module('fw')
.controller('homeCtrl', ['$translate','$scope','settingsService', function($translate, $scope, settingsService) {
    $scope.widgets = [];
    $scope.isWOReady = false;
   
    var widget_data = [
        {key: 'p', id: 'widget_parental_control',         title: 'WIDGETS.PARENTAL_CONTROL.TITLE_SHORT',  mobileOnly: false},
        {key: 'p', id: 'widget_parental_control_mini',    title: 'WIDGETS.PARENTAL_CONTROL.TITLE_SHORT',  mobileOnly: true},
        {key: 'f', id: 'widget_family_devices_mini',      title: 'WIDGETS.FAMILY_DEVICES.TITLE',          mobileOnly: true},
        {key: 'f', id: 'widget_family_devices',           title: 'WIDGETS.FAMILY_DEVICES.TITLE',          mobileOnly: false},
        {key: 'o', id: 'widget_online_devices',           title: 'WIDGETS.DEVICES.TITLE_SHORT',           mobileOnly: false},
        {key: 'e', id: 'widget_led_status',               title: 'WIDGETS.LED_STATUS.TITLE_SHORT',        mobileOnly: false},
        {key: 'i', id: 'widget_line_status',              title: 'WIDGETS.LINE_STATUS.TITLE_SHORT',       mobileOnly: false}
    ];
    
    var save_widget_order = function(){
        var newOrder = [];
        for(var i in $scope.widgets){
            if(!$scope.widgets[i].mobileOnly){
                newOrder.push($scope.widgets[i].key);
            }
        }
        settingsService.set('widget_order', JSON.stringify(newOrder));
    };
    
    $scope.init_widgets = function(){
        settingsService.get('widget_order').then(function(data){
            $scope.widgets = [];
            try{
                data = JSON.parse(data);
            } catch(e){ data = false; }
            
            if(!data || typeof data !== 'object'){
                $scope.widgets = widget_data;
            } else {
                for(var i in data){
                    for(var j in widget_data){
                        if(widget_data[j].key == data[i]){
                            $scope.widgets.push(widget_data[j]);
                        }
                    }
                }
            }
            $scope.isWOReady = true;
        });
    };
    $scope.init_widgets();
    
    $scope.enableSortableWidgets = !Modernizr.touch;
    
    $scope.dragControlListeners = {
        orderChanged: function(event) {
            save_widget_order();
        }
    };
}]);


