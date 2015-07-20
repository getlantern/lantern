/*global beforeEach, describe, it, inject, expect, module, spyOn*/

(function () {
    'use strict';

    describe('uiShow', function () {

        var scope, $compile;
        beforeEach(module('ui.showhide'));
        beforeEach(inject(function (_$rootScope_, _$compile_) {
            scope = _$rootScope_.$new();
            $compile = _$compile_;
        }));

        describe('linking the directive', function () {
            it('should call scope.$watch', function () {
                spyOn(scope, '$watch');
                $compile('<div ui-show="foo"></div>')(scope);
                expect(scope.$watch).toHaveBeenCalled();
            });
        });

        describe('executing the watcher', function () {
            it('should add the ui-show class if true', function () {
                var element = $compile('<div ui-show="foo"></div>')(scope);
                scope.foo = true;
                scope.$apply();
                expect(element.hasClass('ui-show')).toBe(true);
            });
            it('should remove the ui-show class if false', function () {
                var element = $compile('<div ui-show="foo"></div>')(scope);
                scope.foo = false;
                scope.$apply();
                expect(element.hasClass('ui-show')).toBe(false);
            });
        });
    });

    describe('uiHide', function () {

        var scope, $compile;
        beforeEach(module('ui.showhide'));
        beforeEach(inject(function (_$rootScope_, _$compile_) {
            scope = _$rootScope_.$new();
            $compile = _$compile_;
        }));

        describe('when the directive is linked', function () {
            it('should call scope.$watch', function () {
                spyOn(scope, '$watch');
                $compile('<div ui-hide="foo"></div>')(scope);
                expect(scope.$watch).toHaveBeenCalled();
            });
        });

        describe('executing the watcher', function () {
            it('should add the ui-hide class if true', function () {
                var element = $compile('<div ui-hide="foo"></div>')(scope);
                scope.foo = true;
                scope.$apply();
                expect(element.hasClass('ui-hide')).toBe(true);
            });
            it('should remove the ui-hide class if false', function () {
                var element = $compile('<div ui-hide="foo"></div>')(scope);
                scope.foo = false;
                scope.$apply();
                expect(element.hasClass('ui-hide')).toBe(false);
            });
        });
    });

    describe('uiToggle', function () {

        var scope, $compile;
        beforeEach(module('ui.showhide'));
        beforeEach(inject(function (_$rootScope_, _$compile_) {
            scope = _$rootScope_.$new();
            $compile = _$compile_;
        }));

        describe('when the directive is linked', function () {
            it('should call scope.$watch', function () {
                spyOn(scope, '$watch');
                $compile('<div ui-toggle="foo"></div>')(scope);
                expect(scope.$watch).toHaveBeenCalled();
            });
        });

        describe('executing the watcher', function () {
            it('should remove the ui-hide class and add the ui-show class if true', function () {
                var element = $compile('<div ui-toggle="foo"></div>')(scope);
                scope.foo = true;
                scope.$apply();
                expect(element.hasClass('ui-show') && !element.hasClass('ui-hide')).toBe(true);
            });
            it('should remove the ui-hide class and add the ui-show class if false', function () {
                var element = $compile('<div ui-toggle="foo"></div>')(scope);
                scope.foo = false;
                scope.$apply();
                expect(!element.hasClass('ui-show') && element.hasClass('ui-hide')).toBe(true);
            });
        });
    });
})();
