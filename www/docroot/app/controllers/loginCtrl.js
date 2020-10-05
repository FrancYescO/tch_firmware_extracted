angular.module('fw')

    .controller('loginCtrl', ['$log', '$scope', '$rootScope', 'authService', '$state', 'fwHelpers', function($log, $scope, $rootScope, authService, $state, fwHelpers) {
        if($rootScope.currentUser.isAuthenticated) {
            $state.go('home');
        }
        else {
            authService.isFirstLogin().then(function(res){
                $scope.isFirstLogin = res;
                $scope.isDataReady = true;
            });
        }

        $scope.user = {
            username: '',
            password:'',
            newPassword: '',
            confirmPassword: '',
            remember_me: true
        };        
        
        $scope.passwordStrength = function(){
            return fwHelpers.scorePassword($scope.user.newPassword);
        };

        $scope.validatePassword = function(form){
            form.messages = {};
            var usr = $scope.user;
            
            authService.validateCredential(usr.username, usr.password, usr.remember_me).then(function(success){
                if(success) {
                    $rootScope.$broadcast('LOGIN_SUCCESS');
                }
                else {
                    form.messages.wrongCredentials = true;
                }
            });
        };
        
        $scope.validateNewUser = function(form){
            form.messages = {};
            
            if($scope.user.confirmPassword !== $scope.user.newPassword){
                form.messages.passwordMissmatch = true;
                return false;
            } else {
                form.messages.passwordMissmatch = false;
                authService.createUser($scope.user.username, $scope.user.newPassword).then(function(success){
                    $scope.isFirstLogin = false;
                });
            }
            
        };
    }])
;