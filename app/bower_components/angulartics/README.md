angulartics
===========

Vendor-agnostic analytics for AngularJS applications. [luisfarzati.github.io/angulartics](http://luisfarzati.github.io/angulartics "Go to the website")

# Minimal setup

## for Google Analytics ##

    angular.module('myApp', ['angulartics', 'angulartics.google.analytics'])

Delete the automatic pageview tracking line in the snippet code provided by Google Analytics:

      ...
      ga('create', '{YOUR GA CODE}', '{YOUR DOMAIN}');
      ga('send', 'pageview'); // <-- DELETE THIS LINE!
    </script>
    
Done. Open your app, browse across the different routes and check [the realtime GA dashboard](http://google.com/analytics/web) to see the hits. 

## for other providers

[Browse the website for detailed instructions.](http://luisfarzati.github.io/angulartics)

## Supported providers

* Google Analytics
* Kissmetrics
* Mixpanel
* Chartbeat
* Segment.io

If there's no Angulartics plugin for your analytics vendor of choice, please feel free to write yours and PR' it! Here's how to do it.

## Creating your own vendor plugin ##

It's very easy to write your own plugin. First, create your module and inject `$analyticsProvider`:

	angular.module('angulartics.myplugin', ['angulartics'])
	  .config(['$analyticsProvider', function ($analyticsProvider) {

The module name can be anything of course, but it would be convenient to follow the style `angulartics.{vendorname}`.

Next, you register either the page track function, event track function, or both. You do it by calling the `registerPageTrack` and `registerEventTrack` methods. Let's take a look at page tracking first:

    $analyticsProvider.registerPageTrack(function (path) {
		// your implementation here
	}

By calling `registerPageTrack`, you tell Angulartics to invoke your function on `$routeChangeSuccess`. Angulartics will send the new path as an argument.

    $analyticsProvider.registerEventTrack(function (action, properties) {
		// your implementation here

This is very similar to page tracking. Angulartics will invoke your function every time the event (`analytics-on` attribute) is fired, passing the action (`analytics-event` attribute) and an object composed of any `analytics-*` attributes you put in the element.

Check out the bundled plugins as reference. If you still have any questions, feel free to email me or post an issue at GitHub!

# Playing around

## Disabling virtual pageview tracking

If you want to keep pageview tracking for its traditional meaning (whole page visits only), set virtualPageviews to false:

	module.config(function ($analyticsProvider) {
		$analyticsProvider.virtualPageviews(false);     

## Programmatic tracking

Use the `$analytics` service to emit pageview and event tracking:

	module.controller('SampleCtrl', function($analytics) {
		// emit pageview beacon with path /my/url
	    $analytics.pageTrack('/my/url');

		// emit event track (without properties)
	    $analytics.eventTrack('eventName');

		// emit event track (with category and label properties for GA)
	    $analytics.eventTrack('eventName', { 
	      category: 'category', label: 'label'
        }); 

## Declarative tracking

Use `analytics-on` and `analytics-event` attributes for enabling event tracking on a specific HTML element:

	<a href="file.pdf" 
		analytics-on="click" 
		analytics-event="Download">Download</a>

`analytics-on` lets you specify the DOM event that triggers the event tracking; `analytics-event` is the event name to be sent. 

Additional properties (for example, category as required by GA) may be specified by adding `analytics-*` attributes:

	<a href="file.pdf" 
		analytics-on="click" 
		analytics-event="Download"
		analytics-category="Content Actions">Download</a>

# What else?

See full docs and more samples at [http://luisfarzati.github.io/angulartics](http://luisfarzati.github.io/angulartics "http://luisfarzati.github.io/angulartics").

# License

Angulartics is freely distributable under the terms of the MIT license.

Copyright (c) 2013 Luis Farzati

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.