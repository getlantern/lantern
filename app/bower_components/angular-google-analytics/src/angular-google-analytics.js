/* global angular, console */

'use strict';

angular.module('angular-google-analytics', [])
    .provider('Analytics', function() {
        var created = false,
            trackRoutes = true,
            accountId,
            trackPrefix = '',
            domainName;

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
          this.trackPrefix = function(prefix) {
              trackPrefix = prefix;
              return true;
          };

          this.setDomainName = function(domain) {
            domainName = domain;
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
            if(domainName) $window._gaq.push(['_setDomainName', domainName]);
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
              $window._gaq.push(['_trackPageview', trackPrefix + url]);
              this._log('_trackPageview', arguments);
            }
          };
          this._trackEvent = function(category, action, label, value) {
            if ($window._gaq) {
              $window._gaq.push(['_trackEvent', category, action, label, value]);
              this._log('trackEvent', arguments);
            }
          };

          /**
           * Add transaction
           * https://developers.google.com/analytics/devguides/collection/gajs/methods/gaJSApiEcommerce#_gat.GA_Tracker_._addTrans
           * @param transactionId
           * @param affiliation
           * @param total
           * @param tax
           * @param shipping
           * @param city
           * @param state
           * @param country
           * @private
           */
          this._addTrans = function (transactionId, affiliation, total, tax, shipping, city, state, country) {
            if ($window._gaq) {
              $window._gaq.push(['_addTrans', transactionId, affiliation, total, tax, shipping, city, state, country]);
              this._log('_addTrans', arguments);
            }
          };

          /**
           * Add item to transaction
           * https://developers.google.com/analytics/devguides/collection/gajs/methods/gaJSApiEcommerce#_gat.GA_Tracker_._addItem
           * @param transactionId
           * @param sku
           * @param name
           * @param category
           * @param price
           * @param quantity
           * @private
           */
          this._addItem = function (transactionId, sku, name, category, price, quantity) {
            if ($window._gaq) {
              $window._gaq.push(['_addItem', transactionId, sku, name, category, price, quantity]);
              this._log('_addItem', arguments);
            }
          };

          /**
           * Track transaction
           * https://developers.google.com/analytics/devguides/collection/gajs/methods/gaJSApiEcommerce#_gat.GA_Tracker_._trackTrans
           * @private
           */
          this._trackTrans = function () {
            if ($window._gaq) {
              $window._gaq.push(['_trackTrans']);
            }
            this._log('_trackTrans', arguments);
          };

            // creates the ganalytics tracker
            _createScriptTag();

            var me = this;

            // activates page tracking
            if (trackRoutes) $rootScope.$on('$routeChangeSuccess', function() {
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
                },
                addTrans: function (transactionId, affiliation, total, tax, shipping, city, state, country) {
                    me._addTrans(transactionId, affiliation, total, tax, shipping, city, state, country);
                },
                addItem: function (transactionId, sku, name, category, price, quantity) {
                    me._addItem(transactionId, sku, name, category, price, quantity);
                },
                trackTrans: function () {
                    me._trackTrans();
                }
            };
        }];

    });
