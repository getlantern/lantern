/*global describe, beforeEach, module, inject, it, spyOn, expect, $ */
describe('uiRoute', function () {
  'use strict';

  var scope, $compile, $location;
  beforeEach(module('ui.route'));
  beforeEach(inject(function (_$rootScope_, _$compile_, _$window_, _$location_) {
    scope = _$rootScope_.$new();
    $compile = _$compile_;
    $location = _$location_;
  }));

  function setPath(path) {
    $location.path(path);
    scope.$broadcast('$routeChangeSuccess');
    scope.$apply();
  }

  describe('model is null', function() {
    runTests();
  });
  describe('model is set', function() {
    runTests('pizza');
  });

  function runTests(routeModel) {
    var modelProp = routeModel || '$uiRoute', elm = angular.noop;
    function compileRoute(template) {
      elm = angular.element(template);
      if (routeModel){ elm.attr('ng-model', routeModel);}
      return $compile(elm[0])(scope);
    }
    
    describe('with uiRoute defined', function(){
      it('should use the uiRoute property', function(){
        compileRoute('<div ui-route="/foo">');
      });
      it('should update model on $observe', function(){
        setPath('/bar');
        scope.$apply('foobar = "foo"');
        compileRoute('<div ui-route="/{{foobar}}">');
        expect(elm.scope()[modelProp]).toBeFalsy();
        scope.$apply('foobar = "bar"');
        expect(elm.scope()[modelProp]).toBe(true);
        scope.$apply('foobar = "foo"');
        expect(elm.scope()[modelProp]).toBe(false);
      });
      it('should support regular expression', function(){
        setPath('/foo/123');
        compileRoute('<div ui-route="/foo/[0-9]*">');
        expect(elm.scope()[modelProp]).toBe(true);
      });
    });

    describe('with ngHref defined', function(){

      it('should use the ngHref property', function(){
        setPath('/foo');
        compileRoute('<a ng-href="/foo" ui-route>');
        expect(elm.scope()[modelProp]).toBe(true);
      });
      it('should update model on $observe', function(){
        setPath('/bar');
        scope.$apply('foobar = "foo"');
        compileRoute('<a ng-href="/{{foobar}}" ui-route>');
        expect(elm.scope()[modelProp]).toBeFalsy();
        scope.$apply('foobar = "bar"');
        expect(elm.scope()[modelProp]).toBe(true);
        scope.$apply('foobar = "foo"');
        expect(elm.scope()[modelProp]).toBe(false);
      });
    });

    describe('with href defined', function(){

      it('should use the href property', function(){
        setPath('/foo');
        compileRoute('<a href="/foo" ui-route>');
        expect(elm.scope()[modelProp]).toBe(true);
      });
    });

    it('should throw an error if no route property available', function(){
      expect(function(){
        compileRoute('<div ui-route>');
      }).toThrow();
    });

    it('should update model on route change', function(){
      setPath('/bar');
      compileRoute('<div ui-route="/foo">');
      expect(elm.scope()[modelProp]).toBeFalsy();
      setPath('/foo');
      expect(elm.scope()[modelProp]).toBe(true);
      setPath('/bar');
      expect(elm.scope()[modelProp]).toBe(false);
    });
  }
});
