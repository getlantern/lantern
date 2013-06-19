# angular-google-analytics

A simple service that let you integrate google analytics tracker in your AngularJS applications.

Proudly brought to you by the [@revolunet](http://twitter.com/revolunet) team.

## features

 - configurable
 - automatic page tracking
 - events tracking

## example

```js
var app = angular.module('app', ['angular-google-analytics'])
    .config(function(AnalyticsProvider, function() {
        // initial configuration
        AnalyticsProvider.setAccount('UA-XXXXX-xx');

        // track all routes (or not)
        AnalyticsProvider.trackPages(true);
    }))
    .controller('SampleController', function(Analytic) {
        // create a new pageview event
        Analytic.trackPage('/video/detail/XXX');

        // create a new tracking event
        Analytic.trackEvent('video', 'play', 'django.mp4');
    });
```

## configuration

```js
// setup your account
AnalyticsProvider.setAccount('UA-XXXXX-xx');
// automatic route tracking (default=true)
AnalyticsProvider.trackPages(false);
```

## Licence
As AngularJS itself, this module is released under the permissive [MIT license](http://revolunet.mit-license.org). Your contributions are always welcome.
