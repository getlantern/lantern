/* http://docs.angularjs.org/#!angular.service */

/**
 * App service which is responsible for the main configuration of the app.
 */
angular.service('myAngularApp', function($route, $window) {

  $route.when('/view1', {template: 'partials/partial1.html', controller: MyCtrl1});
  $route.when('/view2', {template: 'partials/partial2.html', controller: MyCtrl2});
  $route.otherwise({redirectTo: '/view1'});

  var self = this;

  self.$on('$afterRouteChange', function(){
    $window.scrollTo(0,0);
  });

}, {$inject:['$route', '$window'], $eager: true});
