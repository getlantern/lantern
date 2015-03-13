/*global describe, beforeEach, module, inject, it, spyOn, expect, $ */
describe('uiScrollfix', function () {
  'use strict';

  var scope, $compile, $window;
  beforeEach(module('ui.scrollfix'));
  beforeEach(inject(function (_$rootScope_, _$compile_, _$window_) {
    scope = _$rootScope_.$new();
    $compile = _$compile_;
    $window = _$window_;
  }));

  describe('compiling this directive', function () {
    it('should bind to window "scroll" event with a ui-scrollfix namespace', function () {
      spyOn($.fn, 'bind');
      $compile('<div ui-scrollfix="100"></div>')(scope);
      expect($.fn.bind).toHaveBeenCalled();
      expect($.fn.bind.mostRecentCall.args[0]).toBe('scroll.ui-scrollfix');
    });
  });
  describe('scrolling the window', function () {
    it('should add the ui-scrollfix class if the offset is greater than specified', function () {
      var element = $compile('<div ui-scrollfix="-100"></div>')(scope);
      angular.element($window).trigger('scroll.ui-scrollfix');
      expect(element.hasClass('ui-scrollfix')).toBe(true);
    });
    it('should remove the ui-scrollfix class if the offset is less than specified (using absolute coord)', function () {
      var element = $compile('<div ui-scrollfix="100" class="ui-scrollfix"></div>')(scope);
      angular.element($window).trigger('scroll.ui-scrollfix');
      expect(element.hasClass('ui-scrollfix')).toBe(false);

    });
    it('should remove the ui-scrollfix class if the offset is less than specified (using relative coord)', function () {
      var element = $compile('<div ui-scrollfix="+100" class="ui-scrollfix"></div>')(scope);
      angular.element($window).trigger('scroll.ui-scrollfix');
      expect(element.hasClass('ui-scrollfix')).toBe(false);
    });
  });
});