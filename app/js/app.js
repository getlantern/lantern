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
  .config(function(modalConfig) {
    modalConfig.backdrop = false;
    modalConfig.escape = false;
  })
  .value('ui.config', {
    jq: {
      tooltip: {
        container: 'body'
      }
    }
  });
