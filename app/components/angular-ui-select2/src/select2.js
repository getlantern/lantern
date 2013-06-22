/**
 * Enhanced Select2 Dropmenus
 *
 * @AJAX Mode - When in this mode, your value will be an object (or array of objects) of the data used by Select2
 *     This change is so that you do not have to do an additional query yourself on top of Select2's own query
 * @params [options] {object} The configuration options passed to $.fn.select2(). Refer to the documentation
 */
angular.module('ui.select2', []).value('uiSelect2Config', {}).directive('uiSelect2', ['uiSelect2Config', '$timeout', function (uiSelect2Config, $timeout) {
  var options = {};
  if (uiSelect2Config) {
    angular.extend(options, uiSelect2Config);
  }
  return {
    require: '?ngModel',
    compile: function (tElm, tAttrs) {
      var watch,
        repeatOption,
        repeatAttr,
        isSelect = tElm.is('select'),
        isMultiple = (tAttrs.multiple !== undefined);

      // Enable watching of the options dataset if in use
      if (tElm.is('select')) {
        repeatOption = tElm.find('option[ng-repeat], option[data-ng-repeat]');

        if (repeatOption.length) {
          repeatAttr = repeatOption.attr('ng-repeat') || repeatOption.attr('data-ng-repeat');
          watch = jQuery.trim(repeatAttr.split('|')[0]).split(' ').pop();
        }
      }

      return function (scope, elm, attrs, controller) {
        // instance-specific options
        var opts = angular.extend({}, options, scope.$eval(attrs.uiSelect2));

        if (isSelect) {
          // Use <select multiple> instead
          delete opts.multiple;
          delete opts.initSelection;
        } else if (isMultiple) {
          opts.multiple = true;
        }

        if (controller) {
          // Watch the model for programmatic changes
          controller.$render = function () {
            if (isSelect) {
              elm.select2('val', controller.$viewValue);
            } else {
              if (isMultiple) {
                if (!controller.$viewValue) {
                  elm.select2('data', []);
                } else if (angular.isArray(controller.$viewValue)) {
                  elm.select2('data', controller.$viewValue);
                } else {
                  elm.select2('val', controller.$viewValue);
                }
              } else {
                if (angular.isObject(controller.$viewValue)) {
                  elm.select2('data', controller.$viewValue);
                } else if (!controller.$viewValue) {
                  elm.select2('data', null);
                } else {
                  elm.select2('val', controller.$viewValue);
                }
              }
            }
          };

          // Watch the options dataset for changes
          if (watch) {
            scope.$watch(watch, function (newVal, oldVal, scope) {
              if (!newVal) return;
              // Delayed so that the options have time to be rendered
              $timeout(function () {
                elm.select2('val', controller.$viewValue);
                // Refresh angular to remove the superfluous option
                elm.trigger('change');
              });
            });
          }

          // Update valid and dirty statuses
          controller.$parsers.push(function (value) {
            var div = elm.prev()
            div
              .toggleClass('ng-invalid', !controller.$valid)
              .toggleClass('ng-valid', controller.$valid)
              .toggleClass('ng-invalid-required', !controller.$valid)
              .toggleClass('ng-valid-required', controller.$valid)
              .toggleClass('ng-dirty', controller.$dirty)
              .toggleClass('ng-pristine', controller.$pristine);
            return value;
          });

          if (!isSelect) {
            // Set the view and model value and update the angular template manually for the ajax/multiple select2.
            elm.bind("change", function () {
              if (scope.$$phase) return;
              scope.$apply(function () {
                controller.$setViewValue(elm.select2('data'));
              });
            });

            if (opts.initSelection) {
              var initSelection = opts.initSelection;
              opts.initSelection = function (element, callback) {
                initSelection(element, function (value) {
                  controller.$setViewValue(value);
                  callback(value);
                });
              };
            }
          }
        }

        attrs.$observe('disabled', function (value) {
          elm.select2('enable', !value);
        });

        attrs.$observe('readonly', function (value) {
          elm.select2('readonly', !!value);
        });

        if (attrs.ngMultiple) {
          scope.$watch(attrs.ngMultiple, function(newVal) {
            elm.select2(opts);
          });
        }

        // Initialize the plugin late so that the injected DOM does not disrupt the template compiler
        $timeout(function () {
          elm.select2(opts);

          // Set initial value - I'm not sure about this but it seems to need to be there
          elm.val(controller.$viewValue);
          // important!
          controller.$render();

          // Not sure if I should just check for !isSelect OR if I should check for 'tags' key
          if (!opts.initSelection && !isSelect)
            controller.$setViewValue(elm.select2('data'));
        });
      };
    }
  };
}]);
