angulartics
===========

Vendor-agnostic analytics for AngularJS applications.

[http://luisfarzati.github.io/angulartics](http://luisfarzati.github.io/angulartics "http://luisfarzati.github.io/angulartics")

# Minimal setup

## Setup with Google Analytics ##

    angular.module('myApp', ['angulartics', 'angulartics.ga'])

You also need to embed the JS code provided by Google Analytics:

    <script>
      (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
      (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
      m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
      })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
    
      ga('create', 'UA-10255892-8', 'luisfarzati.github.io');
      ga('send', 'pageview'); // <-- DELETE THIS LINE!
    </script>
    
Done. All navigation done across your application pages (ng-views) will be automatically tracked as pageviews.

## Setup with Kissmetrics ##

    angular.module('myApp', ['angulartics', 'angulartics.km'])

You also need to embed the JS code provided by Kissmetrics:

	<script type="text/javascript">
	  var _kmq = _kmq || [];
	  var _kmk = _kmk || 'a41242214c6f8c693b4c8a59fa8f981e13549deb';
	  function _kms(u){
	    setTimeout(function(){
	      var d = document, f = d.getElementsByTagName('script')[0],
	      s = d.createElement('script');
	      s.type = 'text/javascript'; s.async = true; s.src = u;
	      f.parentNode.insertBefore(s, f);
	    }, 1);
	  }
	  _kms('//i.kissmetrics.com/i.js');
	  _kms('//doug1izaerwt3.cloudfront.net/' + _kmk + '.1.js');
	</script>

Done. All navigation done across your application pages (ng-views) will be automatically tracked as pageviews (actually, as events named "Pageview"; their API doesn't seem to support pageview tracking programatically).

## Are there any additional providers?

Not yet. I'll be adding support for more providers in short-term, and your contribution is most welcomed :) If there's no Angulartics plugin for your analytics vendor of choice, please feel free to write yours and PR' it!  

# Playing around 

## Disabling virtual pageview tracking

If you want to keep pageview tracking for its traditional meaning (whole page visits only), set virtualPageviews to false:

	angular.module('myApp', ['angulartics', 'angulartics.ga'])
	.config(function($analyticsProvider) {
		$analyticsProvider.virtualPageviews(false);     

## Programmatic tracking

Use the $analytics service to emit pageview and event tracking:

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