(function(undefined) {
    angular.module('fw')
    .directive('fwQrcode', function(){
        /*
         * Directive alternativa per generare il qrcode
         * <div fw-qrcode fw-string="" data="{{'WIFI:S:'+guest_network.SSID+';T:'+(guest_network.security === 'WEP'? 'WEP' : 'WPA')+';P:'+guest_network.auth_key+';'+(guest_network.broadcast? 'H:true;' : '')}}"></div>
         * funziona ma meglio pulirla
         */
        
        var draw = function(context, qr, modules, tile) {
          for (var row = 0; row < modules; row++) {
            for (var col = 0; col < modules; col++) {
              var w = (Math.ceil((col + 1) * tile) - Math.floor(col * tile)),
                  h = (Math.ceil((row + 1) * tile) - Math.floor(row * tile));

              context.fillStyle = qr.isDark(row, col) ? '#000' : '#fff';
              context.fillRect(Math.round(col * tile),
                               Math.round(row * tile), w, h);
            }
          }
        };
        return {
            restrict: 'A',
            scope: {
              fwString: '='
            },
            template: '<div class="qrcode"></div>',
            link: function(scope, element, attrs){
                
                var domElement = element[0],
                error,
                modules,
                tile,
                size,
                qr,
                errorCorrectionLevel = 'M',
                version = 4,
                setData = function(value) {
                    if (!value) {
                      return;
                    }
                    qr = qrcode(version, errorCorrectionLevel);
                    qr.addData(value);

                    try {
                      qr.make();
                    } catch(e) {
                      error = e.message;
                      return;
                    }

                    error = false;
                    modules = qr.getModuleCount();
                },
                setSize = function(value) {
                    size = parseInt(value, 10) || modules * 2;
                    tile = size / modules;
                },
                render = function() {
                  if (!qr) {
                    return;
                  }

                  if (error) {                    
                    scope.$emit('qrcode:error', error);
                    return;
                  }

                  domElement.innerHTML = qr.createImgTag(15, 0);
                  element.find('img')[0].width = size;
                  element.find('img')[0].height = size;
                };
                
                
                attrs.$observe('data', function(value) {
                  if (!value) {
                    return;
                  }

                  setData(value);
                  render();
                });
                
                setSize(250);
                setData(attrs.fwString);
                render();
            }
        };
    })
    .directive('fwHistogramBar', function() {
        
        return {
            restrict: 'A',
            scope: {
              fwUp: '=',
              fwDown: '=',
              fwMax: '=',
              fwIsmax: '=',
              fwIsmin: '='
            },
            template: '<div class="histogram-bar">'+
                    '<div ng-class="{upload: true, disab: upload <= 0}" ng-style="{width: upload + \'%\'};"></div>'+
                    '<div ng-class="{download: true, disab: upload <= 0}" ng-style="{width: download + \'%\'};"><span class="icon icon-alert" ng-if="isMax || isMin"></span></div>'+
                    '</div>',
            controller: ['$scope', function($scope){
                $scope.upload = ($scope.fwUp * 100) / $scope.fwMax;
                $scope.download = ($scope.fwDown * 100) / $scope.fwMax;
                $scope.isMax = $scope.fwIsmax;
                $scope.isMin = $scope.fwIsmin;
            }]
        };
    })
    .directive('fwHistogramScale', function() {
        
        return {
            restrict: 'A',
            scope: {
              fwUpAvg: '=',
              fwDownAvg: '=',
              fwMax: '='
            },
            template:   '<div class="scale_wrap">'+
                            '<div class="scale">'+
                                '<div ng-if="fwUpAvg > 0" class="average upload" ng-style="{width: upload + \'%\'};">'+
                                    '<span translate>WIDGETS.LINE_STATUS.AVERAGE_UP</span>'+
                                    '<var>{{fwUpAvg}} Mb/s</var>'+
                                '</div>'+
                                '<div ng-if="fwDownAvg > 0" class="average download" ng-style="{width: download + \'%\'};">'+
                                    '<span translate>WIDGETS.LINE_STATUS.AVERAGE_DOWN</span>'+
                                    '<var>{{fwDownAvg}} Mb/s</var>'+
                                '</div>'+
                                '<span class="bottom">0 Mb/s</span>'+
                                '<span class="top">{{fwMax}} Mb/s</span>'+
                            '</div>'+
                        '</div>',
            controller: ['$scope', function($scope){
                $scope.$watch('fwUpAvg', function(newValue){
                    $scope.upload = (newValue * 100) / $scope.fwMax;
                });
                $scope.$watch('fwDownAvg', function(newValue){
                    $scope.download = (newValue * 100) / $scope.fwMax;
                });
                
            }]
        };
    })
    .directive('fwHistogramBarWifi', function() {
        
        return {
            restrict: 'A',
            scope: {
              fwNum: '=',
              fwMax: '=',
              fwCurrent: '='
            },
            template: '<div class="histogram-bar-v" ng-class="{empty: num == 0}">'+
                    '<div class="networks" ng-style="{height: num + \'%\'};"><span ng-if="fwCurrent"></span></div>'+
                    '</div>',
            controller: ['$scope', function($scope){
                $scope.num = ($scope.fwNum * 100) / $scope.fwMax;
            }]
        };
    })

    .directive('fwLoader', function($compile) {
        var loader =   '<div class="loader-wrapper">'+
                        '<div class="loader"><span class="scroller"></span></div>'+
                        '<p ng-if="!hidelabel" translate>LOADER</p>'+
                        '</div>';      
        return {
            restrict: 'A',
            scope: false,
            compile: function(tElement, tAttrs) {  
                var initialContents = tElement.html();  
                return function (scope, element, attrs) {
                    var innerScope = null;
                    
                    scope.$watch(attrs.fwLoader, function (val) {
                        if (innerScope) innerScope.$destroy();
                        innerScope = scope.$new();
                        innerScope.hidelabel = attrs.hidelabel == 'true';
                        if (!val) {
                            element.html(loader);
                        } else {
                            element.html(initialContents);                      
                        }
                        $compile(element.contents())(innerScope);
                    });
                };
            }
        };
        
    })

    .directive('fwActionBottons', function($compile) {
        var bottons =   '<div class="row">'+
                        '<div class="col-sm-10" id="title"></div>'+
                        '<div class="col-sm-1 actions-botton"><span class="icon-actions-sorting"></span></div>'+
                        '<div class="col-sm-1 actions-botton"><span class="icon-actions-link" ui-sref="{{link}}"></span></div>'+
                        '</div>';   
        return {
            restrict: 'A',
            scope: true,
            compile: function(tElement, tAttrs) {  
                 
                return function (scope, element, attrs) {
                    
                    
                    if(typeof attrs.fwActionBottons != 'undefined'){
                       
                        scope.link = attrs.fwActionBottons;                       
                        
                        var belement = angular.element(bottons);
                        var title = belement.find('div')[0];
                        
                        title.innerHTML  = element.html();                        
                       
                        element.html('<div class="row">'+belement.html()+'</div>');
                        
                        $compile(element.contents())(scope);
                    }
                    
                };
            }
        };  
    })

    .directive("validateWifiPassword", ['$parse', function($parse){
        function isASCII(str){
          for(var i=0;i<str.length;i++) {
              if(str.charCodeAt(i)>127) {
                  return false;
              }
          }
          return true;
        }

        function isHEX(str){ return /^[0-9A-Fa-f]+$/.test(str); }

        function validateWifiPassword(value, auth){
          if(auth == 'WEP'){
              // The password should be 13 ASCII characters or 26 hexadecimal characters. (WEP-128)
              // The password should be  5 ASCII characters or 10 hexadecimal characters.  (WEP-64)
              switch (value.length) {
                  case  5:
                  case 13:
                    return isASCII(value);

                  case 10:
                  case 26:
                    return isHEX(value);

                  default:
                    return false;
              }
          }

          else if(auth.indexOf('WPA') === 0){
              // The password should be 8-63 ASCII characters or 64 hexadecimal characters.
              switch (value.length) {
                  case 64:
                    return isHEX(value);

                  default:
                    return value.length >= 8 && value.length <= 63 && isASCII(value);
              }
          }

          return true;
      }

        // requires an isloated model
        return {
            // restrict to an attribute type.
            restrict: 'A',
            // element must have ng-model attribute.
            require: 'ngModel',
            scope: {
               validateWifiPassword: '='
           },
            link: function(scope, ele, attrs, ctrl){
              scope.$watch('validateWifiPassword', function(newValue){
                ctrl.$validate();
              });

              ctrl.$validators.wifiPassword = function(value) {

                if(!attrs.required)
                  return true; // don't performs validation when not required

                if(typeof(value) !=='string' || value.length == 0)
                  return false;

                return validateWifiPassword(value, scope.validateWifiPassword);
              }

            }
        }
    }]);
})();