/*!
 * angular-translate - v2.5.2 - 2014-12-10
 * http://github.com/angular-translate/angular-translate
 * Copyright (c) 2014 ; Licensed MIT
 */
angular.module("pascalprecht.translate").factory("$translateStaticFilesLoader",["$q","$http",function(a,b){return function(c){if(!c||!angular.isString(c.prefix)||!angular.isString(c.suffix))throw new Error("Couldn't load static files, no prefix or suffix specified!");var d=a.defer();return b(angular.extend({url:[c.prefix,c.key,c.suffix].join(""),method:"GET",params:""},c.$http)).success(function(a){d.resolve(a)}).error(function(){d.reject(c.key)}),d.promise}}]);