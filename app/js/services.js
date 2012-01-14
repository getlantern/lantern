'use strict';
/* http://docs.angularjs.org/#!angular.service */

// Demonstrate how to register services
// In this case it is a simple constant service.
angular.module('myApp.services', []).
  value('version', '0.1');
