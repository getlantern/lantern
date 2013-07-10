/* global module, angular, console, describe, expect, it, before, beforeEach, inject, spyOn, AnalyticsProvider */

'use strict';

describe('angular-google-analytics', function(){

    beforeEach(module('angular-google-analytics'));
    beforeEach(module(function(AnalyticsProvider) {
      AnalyticsProvider.setAccount('UA-XXXXXX-xx');
    }));

   describe('automatic trackPages', function() {

      it('should inject the GA script', function() {
        inject(function(Analytics) {
          expect(document.querySelectorAll("script[src='http://www.google-analytics.com/ga.js']").length).toBe(1);
        });
      });

      it('should generate pageTracks', function() {
        inject(function(Analytics) {
          expect(Analytics._logs.length).toBe(0);
          Analytics.trackPage('test');
          expect(Analytics._logs.length).toBe(1);
          Analytics.trackEvent('test');
          expect(Analytics._logs.length).toBe(2);
        });
      });

      it('should generate an trackpage to routeChangeSuccess', function() {
        inject(function(Analytics, $rootScope) {
          $rootScope.$broadcast('$routeChangeSuccess');
          expect(Analytics._logs.length).toBe(1);
        });
      });
  });

  describe('e-commerce transactions', function() {
  
      it('should add transcation', function() {
        inject(function(Analytics) {
          expect(Analytics._logs.length).toBe(0);
          Analytics.addTrans('1', '', '2.42', '0.42', '0', 'Amsterdam', '', 'Netherlands');
          expect(Analytics._logs.length).toBe(1);
        });
      });
  
      it('should add an item to transaction', function() {
        inject(function(Analytics) {
          expect(Analytics._logs.length).toBe(0);
          Analytics.addItem('1', 'sku-1', 'Test product 1', 'Testing', '1', '1');
          expect(Analytics._logs.length).toBe(1);
          Analytics.addItem('1', 'sku-2', 'Test product 2', 'Testing', '1', '1');
          expect(Analytics._logs.length).toBe(2);
        });
      });
  
      it('should track the transaction', function() {
        inject(function(Analytics) {
          expect(Analytics._logs.length).toBe(0);
          Analytics.trackTrans();
          expect(Analytics._logs.length).toBe(1);
        });
      });
  });

  describe('NOT automatic trackPages', function() {
    beforeEach(module(function(AnalyticsProvider) {
      AnalyticsProvider.trackPages(false);
    }));

    it('should NOT generate an trackpage to routeChangeSuccess', function() {
      inject(function(Analytics, $rootScope) {
        $rootScope.$broadcast('$routeChangeSuccess');
        expect(Analytics._logs.length).toBe(0);
      });
    });
  });

});

