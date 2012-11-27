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
  .filter('version', function() {
    return function(versionObj, full) {
      if (!versionObj) return versionObj;
      var components = [versionObj.major, versionObj.minor, versionObj.patch],
          versionStr = components.join('.');
      if (!full) return versionStr;
      if (versionObj.tag) versionStr += '-'+versionObj.tag;
      if (versionObj.git) versionStr += ' ('+versionObj.git+')';
      return versionStr;
    };
  })
  ;
