/*! ngclipboard - v1.1.0 - 2015-12-30
* https://github.com/sachinchoolur/ngclipboard
* Copyright (c) 2015 Sachin; Licensed MIT */
(function() {
    'use strict';
    var MODULE_NAME = 'ngclipboard';
    var angular, Clipboard;

    if (typeof module !== 'undefined' && typeof module.exports === 'object') {
      angular = require('angular');
      Clipboard = require('clipboard');
      module.exports = MODULE_NAME;
    } else {
      angular = window.angular;
      Clipboard = window.Clipboard;
    }

    angular.module(MODULE_NAME, []).directive('ngclipboard', function() {
        return {
            restrict: 'A',
            scope: {
                ngclipboardSuccess: '&',
                ngclipboardError: '&'
            },
            link: function(scope, element) {
                var clipboard = new Clipboard(element[0]);

                clipboard.on('success', function(e) {
                    scope.ngclipboardSuccess({
                        e: e
                    });
                });

                clipboard.on('error', function(e) {
                    scope.ngclipboardError({
                        e: e
                    });
                });

            }
        };
    });
}());
