/***************
   voiceService
****************/
angular.module('fw').service('authService',['$q','$log','api', '$rootScope', '$timeout', function($q, $log, api, $rootScope, $timeout) {
	

    /**
     * If it's the first login the user must create a new account
     * @returns boolean
     */
    this.isFirstLogin = function() {
        return api.get('login_confirm', {cmd: 1}).then(function(data) {
            return data.first_login == 1;
        });
    };

    /**
     * Create a new user
     * 
     * @param username
     * @param password
     * @returns boolean
     */
    this.createUser = function(username, password) {
        return api.get('login_confirm', {cmd: 2, username: username, password: password}).then(function(data) {
            return (data.check_user == 1 && data.check_pwd == 1);
        });
    };

    /**
     * Checks if the inserted credentials are valid
     * @param user
     * @param pwd
     * @returns boolean
     */
    this.validateCredential = function(user, pwd, remember) {
        return api.get('login_confirm', {
            cmd: 3,
            username: user,
            password: pwd,
            remember_me: remember ? 1 : 0
        }).then(function(data) {
            return data.check_user == 1 && data.check_pwd == 1;
        });
    };
    
    /**
     * Checks if the user is logged in or not
     * @returns {unresolved}
     */
	this.getLoginStatus = function() {
		return api.get('login_confirm', {cmd: 4}).then(function(data) {
			return data.login_status && (window.sessionStorage && sessionStorage.getItem('login'));
		});
	};

    /**
     * Update user credentials
     * 
     * @param {type} username
     * @param {type} old_password
     * @param {type} new_password
     * @returns boolean
     */
    this.updateUser = function(username, old_password, new_password) {
        return api.get('login_confirm', {cmd: 6, username: username, old_password: old_password, new_password: new_password}).then(function(data) {
            if(data.check_user == 1 && data.check_pwd == 1) {
                api.get('login_confirm', {cmd: 5}).then(function(data) {
                    $rootScope.$broadcast('LOGOUT');
                });
                return true;
            }
            return false;
        });
    };

}]);
