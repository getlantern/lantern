'use strict';

var app = angular.module('app', [
  'app.constants',
  'app.helpers',
  'app.i18n',
  'app.filters',
  'app.services',
  'app.directives',
  'app.vis',
  'ngSanitize',
  'ui',
  'ui.bootstrap'
  ])
  // app config
  .constant('config', {
    dev: true
  })
  // angular bootstrap config
  .config(function($dialogProvider) {
    $dialogProvider.options({
      backdrop: false,
      dialogFade: true,
      keyboard: false,
      backdropClick: false
    });
  })
  // angular-ui config
  .value('ui.config', {
    jq: {
      tooltip: {
        container: 'body'
      }
    }
  });
