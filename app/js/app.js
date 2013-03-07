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
  .config(function(modalConfig) {
    modalConfig.backdrop = false;
    modalConfig.escape = false;
  })
  // angular-ui config
  .value('ui.config', {
    jq: {
      tooltip: {
        container: 'body'
      }
    }
  });
