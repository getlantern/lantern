/*
 AngularJS v0.10.6
 (c) 2010-2012 AngularJS http://angularjs.org
 License: MIT
*/
'use strict';(function(i){function d(a,b,c){return a[b]||(a[b]=c())}return d(d(i,"angular",Object),"module",function(){var a={};return function(b,c,e){c&&a.hasOwnProperty(b)&&(a[b]=null);return d(a,b,function(){function a(b,c){return function(){d.push([b,c,arguments]);return f}}if(!c)throw Error("No module: "+b);var d=[],g=[],h=a("$injector","invoke"),f={_invokeQueue:d,_runBlocks:g,requires:c,name:b,service:a("$provide","service"),factory:a("$provide","factory"),value:a("$provide","value"),filter:a("$filterProvider",
"register"),config:h,run:function(a){g.push(a);return this}};e&&h(e);return f})}})})(window);
