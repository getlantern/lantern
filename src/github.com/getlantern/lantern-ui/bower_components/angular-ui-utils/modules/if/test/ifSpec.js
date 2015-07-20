describe('ui-if', function () {
  var scope, $compile, elm;

  beforeEach(module('ui.if'));
  beforeEach(inject(function ($rootScope, _$compile_) {
    scope = $rootScope.$new();
    $compile = _$compile_;
    elm = angular.element('<div>');
  }));

  function makeIf(expr) {
    elm.append($compile('<div ui-if="' + expr + '"><div>Hi</div></div>')(scope));
    scope.$apply();
  }

  it('should immediately remove element if condition is false', function () {
    makeIf('false');
    expect(elm.children().length).toBe(0);
  });

  it('should leave the element if condition is true', function () {
    makeIf('true');
    expect(elm.children().length).toBe(1);
  });

  it('should create then remove the element if condition changes', function () {
    scope.hello = true;
    makeIf('hello');
    expect(elm.children().length).toBe(1);
    scope.$apply('hello = false');
    expect(elm.children().length).toBe(0);
  });

  it('should create a new scope', function () {
    scope.$apply('value = true');
    elm.append($compile(
      '<div ui-if="value"><span ng-init="value=false"></span></div>'
    )(scope));
    scope.$apply();
    expect(elm.children('div').length).toBe(1);
  });

  it('should play nice with other elements beside it', function () {
    scope.values = [1, 2, 3, 4];
    elm.append($compile(
      '<div ng-repeat="i in values"></div>' +
        '<div ui-if="values.length==4"></div>' +
        '<div ng-repeat="i in values"></div>'
    )(scope));
    scope.$apply();
    expect(elm.children().length).toBe(9);
    scope.$apply('values.splice(0,1)');
    expect(elm.children().length).toBe(6);
    scope.$apply('values.push(1)');
    expect(elm.children().length).toBe(9);
  });
});