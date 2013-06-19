describe('uiJq', function () {
  var scope, compile, timeout;
  scope = null;
  beforeEach(module('ui.jq'));
  beforeEach(function () {
    jQuery.fn.foo = function () {};
    module(function ($provide) {
      $provide.value('ui.config', {
        jq: {foo: {}}
      });
    });
  });
  beforeEach(inject(function ($rootScope, $compile, $timeout) {
    scope = $rootScope.$new();
    compile = $compile;
    timeout = $timeout;
  }));
  describe('function or plugin isn\'t found', function () {
    it('should throw an error', function () {
      expect(function () {
        compile("<div ui-jq='failure'></div>")(scope);
      }).toThrow();
    });
  });
  describe('calling a jQuery element function', function () {
    it('should just like, sort of work and junk', function () {
      spyOn(jQuery.fn, 'foo');
      compile("<div ui-jq='foo'></div>")(scope);
      timeout.flush();
      expect(jQuery.fn.foo).toHaveBeenCalled();
    });
    it('should fire after the view has rendered', function() {
      var length;
      jQuery.fn.bar = function() {
        length = angular.element(this).children().length;
        console.log(length);
      };
      scope.$apply('items=[1, 2]');
      compile("<ul ui-jq='bar'><li ng-repeat='item in items'></li></ul>")(scope);
      scope.$apply();
      timeout.flush();
      expect(length).toBe(2);
    });
  });
  describe('calling a jQuery element function with options', function() {
    it('should not copy options.pizza to global', function() {
      spyOn(jQuery.fn, 'foo');
      compile('<div ui-jq="foo" ui-options="{pizza:true}"></div><div ui-jq="foo" ui-options="{}"></div>')(scope);
      timeout.flush();
      expect(jQuery.fn.foo.calls[0].args).toEqual([{pizza: true}]);
      expect(jQuery.fn.foo.calls[1].args).toEqual([{}]);
    });
  });
  describe('using ui-refresh', function() {
    it('should execute exactly once if the expression is never set', function() {
      spyOn(jQuery.fn, 'foo');
      compile('<div ui-jq="foo" ui-refresh="bar"></div>')(scope);
      timeout.flush();
      expect(jQuery.fn.foo.callCount).toBe(1);
    });
    it('should execute exactly once if the expression is set at initialization', function() {
      spyOn(jQuery.fn, 'foo');
      scope.$apply('bar = true');
      compile('<div ui-jq="foo" ui-refresh="bar"></div>')(scope);
      timeout.flush();
      expect(jQuery.fn.foo.callCount).toBe(1);
    });
    it('should execute once for each time the expression changes', function() {
      spyOn(jQuery.fn, 'foo');
      scope.$apply('bar = 1');
      compile('<div ui-jq="foo" ui-refresh="bar"></div>')(scope);
      timeout.flush();
      expect(jQuery.fn.foo.callCount).toBe(1);
      scope.$apply('bar = bar+1');
      timeout.flush();
      expect(jQuery.fn.foo.callCount).toBe(2);
      scope.$apply('bar = bar+1');
      timeout.flush();
      expect(jQuery.fn.foo.callCount).toBe(3);
    });
  });
  describe('change events', function() {
    it('should trigger an `input` event', function() {
      var bar = false;
      var element = compile('<input ui-jq="foo" ng-model="foobar">')(scope);
      element.bind('input', function(){
        bar = true;
      });
      element.trigger('change');
      expect(bar).toBe(true);
    });
    it('should ignore controls without ngModel attribute', function() {
      var bar = false;
      var element = compile('<input ui-jq="foo">')(scope);
      element.bind('input', function(){
        bar = true;
      });
      element.trigger('change');
      expect(bar).toBe(false);
    });
    it('should ignore non-form controls', function() {
      var bar = false;
      var element = compile('<div ui-jq="foo"></div  ng-model="foobar">')(scope);
      element.bind('input', function(){
        bar = true;
      });
      element.trigger('change');
      expect(bar).toBe(false);
    });
  });
});
