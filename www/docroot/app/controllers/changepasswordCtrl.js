angular.module('fw')

    .controller('changepasswordCtrl', ['$log', '$scope', '$rootScope', 'authService', '$state', 'fwHelpers', function($log, $scope, $rootScope, authService, $state, fwHelpers) {
        
        $scope.user = {
            username: '',
            oldPassword: '',
            newPassword: '',
            confirmPassword: ''
        };
        $scope.passwordStrength = function(){
            return fwHelpers.scorePassword($scope.user.newPassword);
        };
        
        $scope.updateUser = function(form){
            form.messages = {};
            
            if($scope.user.confirmPassword !== $scope.user.newPassword){
                form.messages.passwordMissmatch = true;
            } else { 
                form.messages.passwordMissmatch = false;
            
                authService.updateUser($scope.user.username, $scope.user.oldPassword, $scope.user.newPassword).then(function(success){
                    if(!success) {
                        form.messages.genericError = true;
                    } else {
                        form.messages.genericError = false;
                    }
                });
            }
        }
    }])
;