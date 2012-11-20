'use strict';

angular.module('app.filters', [])
  // see i18n.js for i18n filter
  .filter('truncateAfter', function() {
    return function(str, index, replaceStr) {
      if (!str || str.length <= index) return str;
      replaceStr = replaceStr || '...';
      return str.substring(0, index) + replaceStr;
    };
  })
  ;
