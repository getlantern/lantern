# uiJq :: jQuery Passthru Directive

This directive is designed to reduce the need for you to create new directives for fairly simple jQuery plugins or behaviors. Instead of listing plugin compatibility, this document attempts to break down what **uiJq** (jQuery Passthru Directive) is doing so that you can figure out how to circumvent problems you encounter and at the same time understand how the AngularJS template engine works.

## Injecting, Compiling, and Linking functions

When you create a directive, there are up to 3 function layers for you to define[[1]](#footnotes):

```js
myApp.directive('uiJq', function uiJqInjectingFunction(){

  // === InjectingFunction === //
  // Logic is executed 0 or 1 times per app (depending on if directive is used).
  // Useful for bootstrap and global configuration

  return {
    compile: function uiJqCompilingFunction($templateElement, $templateAttributes) {

      // === CompilingFunction === //
      // Logic is executed once (1) for every instance of ui-jq in your original UNRENDERED template.
      // Scope is UNAVAILABLE as the templates are only being cached.
      // You CAN examine the DOM and cache information about what variables
      //   or expressions will be used, but you cannot yet figure out their values.
      // Angular is caching the templates, now is a good time to inject new angular templates 
      //   as children or future siblings to automatically run..

      return function uiJqLinkingFunction($scope, $linkElement, $linkAttributes) {

        // === LinkingFunction === //
        // Logic is executed once (1) for every RENDERED instance.
        // Once for each row in an ng-repeat when the row is created.
        // If ui-if or ng-switch may also affect if this is executed.
        // Scope IS available because controller logic has finished executing.
        // All variables and expression values can finally be determined.
        // Angular is rendering cached templates. It's too late to add templates for angular
        //  to automatically run. If you MUST inject new templates, you must $compile them manually.

      };
    }
  };
})
```

You can _only_ access data in `$scope` inside the **LinkingFunction**. Since the template logic may remove or duplicate elements, you can _only_ rely on the final DOM configuration in the **LinkingFunction**. You still _cannot_ rely upon **children** or **following-siblings** since they have not been linked yet.

## Deferred Execution
Even though you can evaluate variables and expressions by the time we hit our `LinkingFunction`, children DOM elements haven't been rendered yet. Sometimes jQuery plugins need to know the number and size of the DOM element's children (such as slideshows or layout managers like Isotope). To add support for these plugins, we decided to delay the plugin's execution using [$timeout](http://docs.angularjs.org/api/ng.$timeout) so that AngularJS can finish rendering the rest of the page.

**This does _NOT_ accomodate for async changes such as loading `$scope` data via AJAX**

If you need to wait till your `$scope` data finishes loading before calling **uiJq** try using [ui-if](http://angular-ui.github.com/#directives-if).

## $element === angular.element() === jQuery()

To make working with the DOM easier, AngularJS contains a miniaturized version of jQuery called jqlite. This emulates some of the core features of jQuery using an _almost_ identical API as jQuery. Any time you see an AngularJS DOM element, it will be the equivalent to a `jQuery()` wrapped DOM element.

**You do _NOT_ have to wrap AngularJS elements in `jQuery()`**

If you are noticing that the full array of jQuery methods (or plugins) aren't available on an AngularJS element, it's because you either forgot to load the jQuery lib, or you forgot to load it **BEFORE** loading AngularJS. If AngularJS doesn't see jQuery already loaded by the time AngularJS loads, it will use it's own jqlite library instead.

**If jQuery plugins complain about missing jQuery methods, you should probably double check this**

Since an AngularJS element is the same as a jQuery() wrapped element, you can essentially call any jQuery method or plugin the same exact way you would have done outside of angular. This is how uiJq works.

uiJq simply takes the string passed and uses it to call a method on the AngularJS element for you:

```js
$('input[type=date]').datepicker() === $('input[type=date]')["datepicker"]() === $linkElement["datepicker"]()
```

## uiOptions and ui.config

Since all jQuery methods take arguments (such as the options for datepicker or the class name for `addClass()`) we provided an easy way for you to pass these options. These options are evaluated from angular so that you can define them in your app:

```js
$('input').datepicker(options) === $linkElement.datepicker(uiOptions)
```

Since there's a good chance you'll use the same options for a plugin across your entire app as defaults, we allow you to declare them inside [ui.config](http://angular-ui.github.com/#defaults). Just remember to use the `jq` key and the `pluginName` subkey:

```js
myApp.value('ui.config', {
  jq: {
    datepicker: {
      // default datepicker options go here
    }
  }
})
```

Because we're awesome, if your `ui.config` options is an object and your `ui-options` is also an object, we'll merge them together for you with `ui-options` taking priority! If `ui-options` is a primitive the defaults will be ignored.

## uiRefresh

Sometimes you need to call the same jQuery method / plugin multiple times on the same element during an app lifecycle:

```js
// every time the login modal is shown, focus on the username field
$('.modal').on('show', function(){
  $('.login-username').focus()
})
```

To make this easy, we added a `ui-refresh` property. This is the equivalent to a `$scope.$watch()` and you can pretend that whatever expression you pass to `ui-refresh` will be just like any expression you pass to `$watch()`. Every time this expression changes (by reference, not by value) uiJq will re-fire:

```html
<input ui-jq="focus" ui-refresh="isLoginFormVisible">
```

## Footnotes

1. A [transcluding function](http://docs.angularjs.org/guide/directive) is actually a 4th layer, but this is not used by uiJq
