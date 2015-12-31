(function() {
"use strict";

var MODULE_NAME = "stripe.checkout";
var STRIPE_CHECKOUT_URL = "https://checkout.stripe.com/checkout.js";

var COPIED_OPTION_ATTRIBUTES = {
  amount:      "data-amount",
  currency:    "data-currency",
  description: "data-description",
  email:       "data-email",
  image:       "data-image",
  key:         "data-key",
  label:       "data-label",
  locale:      "data-locale",
  name:        "data-name",
  panelLabel:  "data-panel-label",
  zipCode:     "data-zip-code"
};

var BOOLEAN_OPTION_ATTRIBUTES = {
  address:         "data-address",
  alipay:          "data-alipay",
  alipayReusable:  "data-alipay-reusable",
  allowRememberMe: "data-allow-remember-me",
  billingAddress:  "data-billing-address",
  bitcoin:         "data-bitcoin",
  shippingAddress: "data-shipping-address"
};


var angular;

if (typeof module !== "undefined" && typeof module.exports === "object") {
  angular = require("angular");
  module.exports = MODULE_NAME;
} else {
  angular = window.angular;
}

var extend = angular.extend;

angular.module(MODULE_NAME,[])
  .directive("stripeCheckout",StripeCheckoutDirective)
  .provider("StripeCheckout",StripeCheckoutProvider);


StripeCheckoutDirective.$inject = ["$parse", "StripeCheckout"];

function StripeCheckoutDirective($parse, StripeCheckout) {
  return { link: link };

  function link(scope, el, attrs) {
    var handler;

    StripeCheckout.load()
      .then(function() {
        handler = StripeCheckout.configure(getOptions(el));
      });

    el.on("click",function() {
      if (handler)
        handler.open(getOptions(el)).then(function(result) {
          var callback = $parse(attrs.stripeCheckout)(scope);
          if (typeof callback === 'function')
            callback.apply(null,result);
        });
    });
  }

  function getOptions(el) {
    var opt, val, options = {};

    for (opt in COPIED_OPTION_ATTRIBUTES) {
      val = el.attr(COPIED_OPTION_ATTRIBUTES[opt]);

      if (typeof val !== "undefined")
        options[opt] = val;
    }

    for (opt in BOOLEAN_OPTION_ATTRIBUTES) {
      val = el.attr(BOOLEAN_OPTION_ATTRIBUTES[opt]);

      if (typeof val === "string")
        options[opt] = val.toLowerCase() === "true";
    }

    return options;
  }
}


function StripeCheckoutProvider() {
  var defaults = {};

  this.defaults = function(options) {
    extend(defaults,options);
  };


  this.load = function(StripeCheckout) {
    return StripeCheckout.load();
  };

  this.load.$inject = ["StripeCheckout"];


  this.$get = function($document, $q) {
    return new StripeCheckoutService($document,$q,defaults);
  };

  this.$get.$inject = ["$document", "$q"];
}


function StripeCheckoutService($document, $q, providerDefaults) {
  var defaults = {},
      promise;

  this.configure = function(options) {
    return new StripeHandlerWrapper($q,extend({},
      providerDefaults,
      defaults,
      options
    ));
  };

  this.load = function() {
    if (!promise)
      promise = loadLibrary($document,$q);

    return promise;
  };

  this.defaults = function(options) {
    extend(defaults,options);
  };
}


function StripeHandlerWrapper($q, options) {
  var deferred, success;

  var handler = StripeCheckout.configure(extend({},options,{
    token: function(token, args) {
      if (options.token) options.token(token,args);

      success = true;
      deferred.resolve([token, args]);
    },

    closed: function() {
      if (options.closed) options.closed();
      if (!success) deferred.reject();
    }
  }));

  this.open = function(openOptions) {
    deferred = $q.defer();
    success = false;

    handler.open(openOptions);

    return deferred.promise;
  };

  this.close = function() {
    success = false;

    handler.close();

    if (options.closed) options.closed();
    if (deferred) deferred.reject();
  }
}


function loadLibrary($document, $q) {
  var deferred = $q.defer();

  var doc = $document[0],
      script = doc.createElement("script");
  script.src = STRIPE_CHECKOUT_URL;

  script.onload = function () {
    deferred.resolve();
  };

  script.onreadystatechange = function () {
    var rs = this.readyState;
    if (rs === "loaded" || rs === "complete")
      deferred.resolve();
  };

  script.onerror = function () {
    deferred.reject(new Error("Unable to load checkout.js"));
  };

  var container = doc.getElementsByTagName("head")[0];
  container.appendChild(script);

  return deferred.promise;
}

})();
