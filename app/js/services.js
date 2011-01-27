/* http://docs.angularjs.org/#!angular.service */

/**
 * App service which is responsible for the main configuration of the app.
 */
angular.service('myAngularApp', function($route, $location, $window) {

  $route.when('/view1', {template: 'partials/partial1.html', controller: MyCtrl1});
  $route.when('/view2', {template: 'partials/partial2.html', controller: MyCtrl2});

  var self = this;

  $route.onChange(function() {
    if ($location.hash === '') {
      $location.updateHash('/view1');
      self.$eval();
    } else {
      $route.current.scope.params = $route.current.params;
      $window.scrollTo(0,0);
    }
  });

}, {$inject:['$route', '$location', '$window'], $eager: true});
