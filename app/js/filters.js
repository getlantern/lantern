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
      return obj.email || obj.peerid;
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
      _.forEach(['/roster', '/settings/proxiedSites', '/friends/current', '/friends/pending'], function(path) {
        var obj = getByPath(state, path);
        setByPath(state, path, obj.length);
      });

      // strip identifying info from peers
      _.forEach(['/connectivity/peers/current', '/connectivity/peers/lifetime'], function(path) {
        var peers = getByPath(state, path);
        if (peers) {
          peers = _.map(peers, function(peer) {
            return _.omit(peer, 'email', 'peerid', 'ip', 'lat', 'lon');
          });
          setByPath(state, path, peers);
        }
      });

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
