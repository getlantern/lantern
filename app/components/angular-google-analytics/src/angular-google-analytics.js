/* global angular, console */

'use strict';

angular.module('angular-google-analytics', [])
    .provider('Analytics', function() {
        var created = false,
            trackRoutes = true,
            accountId;

          this._logs = [];

          // config methods
          this.setAccount = function(id) {
              accountId = id;
              return true;
          };
          this.trackPages = function(doTrack) {
              trackRoutes = doTrack;
              return true;
          };

        // public service
        this.$get = ['$document', '$rootScope', '$location', '$window', function($document, $rootScope, $location, $window) {
          // private methods
          function _createScriptTag() {
            // inject the google analytics tag
            if (!accountId) return;
            $window._gaq = [];
            $window._gaq.push(['_setAccount', accountId]);
            if (trackRoutes) $window._gaq.push(['_trackPageview']);
            (function() {
              var document = $document[0];
              var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
              ga.src = ('https:' === document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
              var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
            })();
            created = true;
          }
          this._log = function() {
            // for testing
            this._logs.push(arguments);
          };
          this._trackPage = function(url) {
            if (trackRoutes && $window._gaq) {
              $window._gaq.push(['_trackPageview', url]);
              this._log('_trackPageview', arguments);
            }
          };
          this._trackEvent = function(category, action, label, value) {
            if ($window._gaq) {
              $window._gaq.push(['_trackEvent', category, action, label, value]);
              this._log('trackEvent', arguments);
            }
          };

          // creates the ganalytics tracker
          _createScriptTag();

          var me = this;

          // activates page tracking
          if (trackRoutes) $rootScope.$on('$routeChangeSuccess', function(scope, current, previous) {
            me._trackPage($location.path());
          });

          return {
                _logs: me._logs,
                trackPage: function(url) {
                    // add a page event
                    me._trackPage(url);
                },
                trackEvent: function(category, action, label, value) {
                    // add an action event
                    me._trackEvent(category, action, label, value);
                }
            };
        }];

    });

