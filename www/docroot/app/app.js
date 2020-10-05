angular.module('fw', [
  'ui.router', //see https://github.com/angular-ui/ui-router/wiki
  'ui.bootstrap', //see http://angular-ui.github.io/bootstrap/
  'ngTouch',
  'as.sortable', //see https://github.com/a5hik/ng-sortable/
  'pascalprecht.translate', //see https://angular-translate.github.io/docs/#/guide
  'duScroll', //see https://github.com/oblador/angular-scroll/
  'timer', // see https://github.com/siddii/angular-timer
  'monospaced.qrcode', // see https://github.com/monospaced/angular-qrcode
  'ngMessages', // https://docs.angularjs.org/api/ngMessages/directive/ngMessages
  'ng.shims.placeholder' // https://github.com/cvn/angular-shims-placeholder
])

.value('apiServiceUrl', '/status.cgi')
.value('appSoftwareVersion', '1.0.1b')

.run(['$rootScope', '$state', '$stateParams', 'authService', 'navService',
    function ($rootScope,  $state, $stateParams, authService, navService) {

      $rootScope.$state = $state;
      var usr = $rootScope.currentUser = {isAuthenticated: false};
      
      $rootScope.$on('$stateChangeStart', function (e, toState, toParams, fromState, fromParams) {

        if(!usr.isAuthenticated && toState.name != 'login') {
          e.preventDefault();

          authService.getLoginStatus().then(function(loginStatus) {
            if(loginStatus == 1) {
              usr.isAuthenticated = true;
              $state.go(toState.name, toParams);
            }
            else {
              $state.go('login');
            }
          });
          return;
        }
        
        if(navService.hasPendingChanges()) {
          e.preventDefault();
          navService.warnUserAboutPendingChanges(toState, toParams);
        }
      });

      $rootScope.$on('$stateChangeSuccess', function (e, toState, toParams, fromState, fromParams) {
        navService.isDirty(null);
      });

      $rootScope.$on('LOGIN_SUCCESS', function() {
        usr.isAuthenticated = true;
        window.sessionStorage && sessionStorage.setItem('login', '1');
        $state.go('home');
      });
      
      $rootScope.$on('LOGOUT', function() {
        usr.isAuthenticated = false;
        window.sessionStorage && sessionStorage.removeItem('login');
        $state.go('login');
      });

      $rootScope.switchTab = function(v) {
          window.scrollTo(0,0);
          return v;
      };

      $rootScope.validatorPatterns = {
        IP : /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$/,
        MAC: /^([0-9a-fA-F][0-9a-fA-F]:){5}([0-9a-fA-F][0-9a-fA-F])$/
      };
    }
])

.config(['$stateProvider', '$urlRouterProvider', '$translateProvider', '$logProvider', 'INTL_IT', 'INTL_EN',
    function ($stateProvider,  $urlRouterProvider, $translateProvider, $logProvider, INTL_IT, INTL_EN) {
      $urlRouterProvider.otherwise(function($injector, $location) {
        $injector.invoke(['$state', function($state) {
          $state.go('home');
        }]);
      });

      //////////////////////////
      // State Configurations //
      //////////////////////////
      var states = {
          home: {},
          wifi: {},
          line: {},
          devices: {},
          advanced: {},
          modem: {},
          info: {},
          voice: {},
          login: {},
          changepassword: {}
      };

      angular.forEach(states, function (value, key) {
        $stateProvider.state(key, angular.extend({
            url:'/'+key,
            controller: key+'Ctrl',
            templateUrl:'views/'+key+'.html?_t='+new Date().getTime()
          }, value)
        );
      });

      ////////////////////////////////
      // Translation Configurations //
      ////////////////////////////////
      
      //translations are located in /app/intl/{lang}.js
      $translateProvider
        .useSanitizeValueStrategy(null)
        .translations('en', INTL_EN)
        .translations('it', INTL_IT)
        //.fallbackLanguage('it')
        .preferredLanguage((window.localStorage && localStorage.getItem('user_language')) || 'it');

      // set $logProvider.debugEnabled(false) in production environment!
      $logProvider.debugEnabled(true);
    }
  ]
)

.factory('fwHelpers', function() {
  var MB = (1024*1024);
  return {
    byteToMB : function(byte) {return Math.round(byte/MB);},
    propHelper : function(object, prefix) {
      return (function() {
        var obj = object,
            pref = prefix;
        return {
          get: function(idx, propName){ return obj[pref+'_'+idx+'_'+propName];}
        }
      })();
    },

    objectToArray : function(object, prefix, qty, props) {
      var res = [];
      for(var i = 0; i < qty; i++) {
        var item = {};
        for(var k=0; k < props.length; k++) {
          item[props[k]] = object[prefix+'_'+i+'_'+props[k]];
        }
        res.push(item);
      }
      return res;
    },

    scorePassword : function(pass) {
        var score = 0;
        if (!pass)
            return score;
        if(pass.length >= 15)
          return 5;

        var variations = {
            digits: /\d/.test(pass),
            lower: /[a-z]/.test(pass),
            upper: /[A-Z]/.test(pass),
            nonWords: /\W/.test(pass)
        };

        variationCount = 0;
        for (var check in variations) {
            variationCount += (variations[check] === true) ? 1 : 0;
        }
        score += variationCount;
        if(pass.length >= 8) score++;

        return parseInt(score);
    }
  }
})
//////////////////////////////////////////
// angular-scroll default configuration //
//////////////////////////////////////////
.value('duScrollOffset', 102)
.value('duScrollBottomSpy', false)
;
