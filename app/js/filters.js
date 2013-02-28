'use strict';

angular.module('app.filters', [])
  // see i18n.js for i18n filter
  .filter('badgeCount', function() {
    return function(str, max) {
      var count = parseInt(str), max = max || 9;
      return count > max ? max + '+' : count;
    };
  })
  .filter('prettyUser', function() {
    return function(obj) {
      if (!obj) return obj;
      if (obj.email && obj.name)
        return obj.name + ' (' + obj.email + ')'; // XXX i18n?
      return obj.email;
    };
  })
  .filter('prettyBytes', function($filter) {
    return function(nbytes, dimensionInput, showUnits) {
      if (_.isNaN(nbytes)) return nbytes;
      if (_.isUndefined(dimensionInput)) dimensionInput = nbytes;
      if (_.isUndefined(showUnits)) showUnits = true;
      var dimBase = byteDimension(dimensionInput),
          dim = dimBase.dim,
          base = dimBase.base,
          quotient = $filter('number')(nbytes / base, 1);
      return showUnits ? quotient+' '+dim // XXX i18n?
                       : quotient;
    };
  })
  .filter('prettyBps', function($filter) {
    return function(nbytes, dimensionInput, showUnits) {
      if (_.isNaN(nbytes)) return nbytes;
      if (_.isUndefined(showUnits)) showUnits = true;
      var bytes = $filter('prettyBytes')(nbytes, dimensionInput, showUnits);
      return showUnits ? bytes+'/'+'s' // XXX i18n?
                       : bytes;
    };
  })
  .filter('reportedState', function() {
    return function(model) {
      var state = _.cloneDeep(model);

      // omit these fields
      state = _.omit(state, 'mock', 'countries', 'global');

      // only include these fields from the user's profile
      if (state.profile) {
        state.profile = {email: state.profile.email, name: state.profile.name};
      }

      // replace these array fields with their lengths
      _.each(['/roster', '/settings/proxiedSites', '/friends/current', '/friends/pending'], function(path) {
        var len = getByPath(state, path).length;
        applyPatch(state, [{op: 'replace', path: path, value: len}]);
      });

      var peers = getByPath(state, '/peers');
      if (peers) {
        peers = _.map(peers, function(peer) {
          return _.omit(peer, 'email', 'peerid', 'ip', 'lat', 'lon');
        });
        applyPatch(state, [{op: 'replace', path: '/peers', value: peers}]);
      }

      return state;
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
  });
