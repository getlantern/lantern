ui-select2   [![Build Status](https://travis-ci.org/angular-ui/ui-select2.png)](https://travis-ci.org/angular-ui/ui-select2)
==========
This directive allows you to enhance your select elements with behaviour from the [select2](http://ivaynberg.github.io/select2/) library.

# Requirements

- [AngularJS](http://angularjs.org/)
- [JQuery](http://jquery.com/)
- [Select2](http://ivaynberg.github.io/select2/)

## Setup

1. Install **karma**
  `$ npm install -g karma`
2. Install **bower**
  `$ npm install -g bower`
4. Install components
  `$ bower install`
4. ???
5. Profit!

## Testing

`$ karma start test/test.conf.js --browsers=Chrome`

# Usage

We use [bower](http://twitter.github.com/bower/) for dependency management.  Add

```javascript
dependencies: {
    "angular-ui-select2": "latest"
}
```

To your `components.json` file. Then run

    bower install

This will copy the ui-select2 files into your `components` folder, along with its dependencies. Load the script files in your application:
```html
<script type="text/javascript" src="components/jquery/jquery.js"></script>
<script type="text/javascript" src="components/angular/angular.js"></script>
<script type="text/javascript" src="components/angular-ui-select2/src/select2.js"></script>
```

Add the select2 module as a dependency to your application module:

```javascript
var myAppModule = angular.module('MyApp', ['ui.select2']);
```

Apply the directive to your form elements:

```html
<select ui-select2 ng-model="select2" data-placeholder="Pick a number">
    <option value=""></option>
    <option value="one">First</option>
    <option value="two">Second</option>
    <option value="three">Third</option>
</select>
```

## Options

All the select2 options can be passed through the directive. You can read more about the supported list of options and what they do on the [Select2 Documentation Page](http://ivaynberg.github.com/select2/)

```javascript
myAppModule.controller('MyController', function($scope) {
    $scope.select2Options = {
        allowClear:true
    };
});
```

```html
<select ui-select2="select2Options" ng-model="select2">
    <option value="one">First</option>
    <option value="two">Second</option>
    <option value="three">Third</option>
</select>
```

Some time it may make sense to specify the options in the template file.

```html
<select ui-select2="{ allowClear: true}" ng-model="select2">
    <option value="one">First</option>
    <option value="two">Second</option>
    <option value="three">Third</option>
</select>
```

## Working with ng-model

The ui-select2 directive plays nicely with ng-model and validation directives such as ng-required.

If you add the ng-model directive to same the element as ui-select2 then the picked option is automatically synchronized with the model value.

## Working with dynamic options
`ui-select2` is incompatible with `<select ng-options>`. For the best results use `<option ng-repeat>` instead.
```html
<select ui-select2 ng-model="select2" data-placeholder="Pick a number">
    <option value=""></option>
    <option ng-repeat="{{number in range}}" value="{{number.value}}">{{number.text}}</option>
</select>
```

## Working with placeholder text
In order to properly support the Select2 placeholder, create an empty `<option>` tag at the top of the `<select>` and either set a `data-placeholder` on the select element or pass a `placeholder` option to Select2.
```html
<select ui-select2 ng-model="number" data-placeholder="Pick a number">
    <option value=""></option>
    <option value="one">First</option>
    <option value="two">Second</option>
    <option value="three">Third</option>
</select>
```

## ng-required directive

If you apply the required directive to element then the form element is invalid until an option is selected.

Note: Remember that the ng-required directive must be explicitly set, i.e. to "true".  This is especially true on divs:

```html
<select ui-select2 ng-model="number" data-placeholder="Pick a number" ng-required="true">
    <option value=""></option>
    <option value="one">First</option>
    <option value="two">Second</option>
    <option value="three">Third</option>
</select>
```
