/* global window */
/* global angular */
/* global module */

(function (module, window, angular) {
    "use strict";

    function test(string, regex) {
        if (typeof regex === 'string' || regex instanceof String) {
            regex=new RegExp(regex);
        }

        if (regex instanceof RegExp) {
            return regex.test(string);
        }
        else if (regex && Array.isArray(regex.and)) {
            return regex.and.every(function (item) {
                return test(string, item);
            });
        }
        else if (regex && Array.isArray(regex.or)) {
            return regex.or.some(function (item) {
                return test(string, item);
            });
        }
        else if (regex && regex.not) {
            return !test(string, regex.not);
        }
        else {
            return false;
        }
    }

    function exec(string, regex) {
        if (typeof regex === 'string' || regex instanceof String) {
            regex=new RegExp(regex);
        }

        if (regex instanceof RegExp) {
            return regex.exec(string);
        }
        else if (regex && Array.isArray(regex)) {
            return regex.reduce(function (res, item) {
                return (!!res) ? res : exec(string, item);
            }, null);
        }
        else {
            return null;
        }
    }

    if (!!angular) {
        angular.module("reTree", []).factory("reTree", [function () {
            return {
                test: test,
                exec: exec
            };
        }]);
    }

    if (!!window) {
        window.reTree = {
            test: test,
            exec: exec
        };
    }

    if (!!module) {
        module.exports = {
            test: test,
            exec: exec
        };
    }
})(typeof module === 'undefined' ? null : module, typeof window === 'undefined' ? null : window, typeof angular === 'undefined' ? null : angular);
