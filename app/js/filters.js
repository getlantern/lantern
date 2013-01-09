'use strict';

angular.module('app.filters', [])
  // see i18n.js for i18n filter
  .filter('badgeCount', function() {
    return function(str, max) {
      var count = parseInt(str), max = max || 9;
      return count > max ? max + '+' : count;
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
      for (var path in {roster:0, 'settings.proxiedSites':0, 'friends.current':0, 'friends.pending':0}) {
        var val = getByPath(state, path);
        if (val && 'length' in val) {
          merge(state, val.length, path);
        }
      }

      // strip identifying info from peers
      for (var path in {'connectivity.peers.current':0, 'connectivity.peers.lifetime':0}) {
        var peers = getByPath(state, path);
        if (!peers) continue;
        peers = _.map(peers, function(peer) {
          return _.omit(peer, 'email', 'peerid', 'ip', 'lat', 'lon');
        });
        merge(state, peers, path);
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
