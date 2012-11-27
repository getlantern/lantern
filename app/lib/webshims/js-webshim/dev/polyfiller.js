(function (factory) {
	
	if(window.jQuery){
		factory(jQuery);
		factory = jQuery.noop;
	}
	if (typeof define === 'function' && define.amd && define.amd.jQuery) {
		define('polyfiller', ['jquery'], factory);
	}
}(function($){
	"use strict";
	var DOMSUPPORT = 'dom-support';
	var jScripts = $(document.scripts || 'script');
	var special = $.event.special;
	var emptyJ = $([]);
	var Modernizr = window.Modernizr;
	var asyncWebshims = window.asyncWebshims;
	var addTest = Modernizr.addTest;
	var browserVersion = parseFloat($.browser.version, 10);
	var Object = window.Object;
	var html5 = window.html5 || {};
	var needModernizr = function(tests, fn){
		var run = true;
		$.each(tests.split(' '), function(i, name){
			if(!(name in Modernizr)){
				webshims.error('webshims needs Modernizr.'+name + ' to implement feature.');
				run = false;
			}
		});
		if(run && fn){
			fn();
		}
	};
	
	Modernizr.advancedObjectProperties = Modernizr.objectAccessor = Modernizr.ES5 = !!('create' in Object && 'seal' in Object);

	
	var webshims = {
		version: '1.9.4',
		cfg: {
			useImportantStyles: true,
			//addCacheBuster: false,
			waitReady: true,
			extendNative: true,
			loadStyles: true,
			disableShivMethods: true,
			basePath: (function(){
				var script = jScripts.filter('[src*="polyfiller.js"]');
				var path;
				script = script[0] || script.end()[script.end().length - 1];
				path = ( ($.support.hrefNormalized) ? script.src : script.getAttribute("src", 4) ).split('?')[0];
				path = path.slice(0, path.lastIndexOf("/") + 1) + 'shims/';
				return path;
			})()
		},
		bugs: {},
		browserVersion: browserVersion,
		/*
		 * some data
		 */
		modules: {},
		features: {},
		featureList: [],
		setOptions: function(name, opts){
			if (typeof name == 'string' && opts !== undefined) {
				webCFG[name] = (!$.isPlainObject(opts)) ? opts : $.extend(true, webCFG[name] || {}, opts);
			} else if (typeof name == 'object') {
				$.extend(true, webCFG, name);
			}
		},
		addPolyfill: function(name, cfg){
			cfg = cfg || {};
			var feature = cfg.f || name;
			if (!webshimsFeatures[feature]) {
				webshimsFeatures[feature] = [];
				webshimsFeatures[feature].delayReady = 0;
				webshims.featureList.push(feature);
				webCFG[feature] = {};
			}
			webshimsFeatures[feature].push(name);
			cfg.options = $.extend(webCFG[feature], cfg.options);
			
			addModule(name, cfg);
			if (cfg.methodNames) {
				$.each(cfg.methodNames, function(i, methodName){
					webshims.addMethodName(methodName);
				});
			}
		},
		
		polyfill: (function(){
			var firstPolyfillCall = function(features){
				var addClass = [];
				var onReadyEvts = features;
				var timer;
				
				if(webCFG.disableShivMethods){
					html5.shivMethods = false;
				}
				
				var removeLoader = function(){
					$('html').removeClass('loading-polyfills long-loading-polyfills');
					$(window).unbind('.lP');
					clearTimeout(timer);
				};
				
				$(window).on('load.lP error.lP', removeLoader);
				
				addClass.push('loading-polyfills');
				timer = setTimeout(function(){
					$('html').addClass('long-loading-polyfills');
				}, 600);
				
				if (webCFG.waitReady && $.isReady) {
					webshims.warn('Call webshims.polyfill before DOM-Ready or set waitReady to false.');
				}
				onReady(features, removeLoader);
				if (webCFG.useImportantStyles) {
					addClass.push('polyfill-important');
				}
				if (addClass[0]) {
					$('html').addClass(addClass.join(' '));
				}
				if(webCFG.loadStyles){
					loader.loadCSS('styles/shim.css');
				}
				//remove function
				firstPolyfillCall = $.noop;
			};
			var loadedFormBase;
			return function(features){
				
				var toLoadFeatures = [];
				
				features = features || webshims.featureList;
				
				if (typeof features == 'string') {
					features = features.split(' ');
				}
				if(!loadedFormBase){
					loadedFormBase = $.inArray('forms', features) !== -1;
					if(!loadedFormBase && $.inArray('forms-ext', features) !== -1){
						features.push('forms');
						loadedFormBase = true;
					}
				}
				
				if (webCFG.waitReady) {
					$.readyWait++;
					onReady(features, function(){
						$.ready(true);
					});
				}
				
				$.each(features, function(i, feature){
					if(!webshimsFeatures[feature]){
						webshims.error("could not find webshims-feature (aborted): "+ feature);
						isReady(feature, true);
						return;
					}
					if (feature !== webshimsFeatures[feature][0]) {
						onReady(webshimsFeatures[feature], function(){
							isReady(feature, true);
						});
					}
					toLoadFeatures = toLoadFeatures.concat(webshimsFeatures[feature]);
				});
				
				firstPolyfillCall(features);
				loadList(toLoadFeatures);
				
			};
		})(),
		
		/*
		 * handle ready modules
		 */
		reTest: (function(){
			var resList;
			var noDelayReady;
			var reTest = function(i, name){
				var module = modules[name];
				var readyName = name+'Ready';
				var feature;
				if(module && !module.loaded && !( (module.test && $.isFunction(module.test) ) ? module.test([]) : module.test )){
					if(special[readyName]){
						delete special[readyName];
					}
					feature = webshimsFeatures[module.f];
					if(feature && !noDelayReady){
						feature.delayReady++;
						onReady(name, function(){
							feature.delayReady--;
							isReady(module.f, feature.callReady);
						});
					}
					resList.push(name);
				}
			};
			return function(moduleNames, _noDelay){
				noDelayReady = _noDelay;
				if(typeof moduleNames == 'string'){
					moduleNames = moduleNames.split(' ');
				}
				resList = [];
				$.each(moduleNames, reTest);
				loadList(resList);
			};
		})(),
		isReady: function(name, _set){
			if(webshimsFeatures[name] && webshimsFeatures[name].delayReady > 0){
				if(_set){
					webshimsFeatures[name].callReady = true;
				}
				return false;
			}
			name = name + 'Ready';
			if (_set) {
				if (special[name] && special[name].add) {
					return true;
				}
				
				special[name] = $.extend(special[name] || {}, {
					add: function(details){
						details.handler.call(this, name);
					}
				});
				$.event.trigger(name);
			}
			return !!(special[name] && special[name].add) || false;
		},
		ready: function(events, fn /*, _created*/){
			var _created = arguments[2];
			var evt = events;
			if (typeof events == 'string') {
				events = events.split(' ');
			}
			
			if (!_created) {
				events = $.map($.grep(events, function(evt){
					return !isReady(evt);
				}), function(evt){
					return evt + 'Ready';
				});
			}
			if (!events.length) {
				fn($, webshims, window, document);
				return;
			}
			var readyEv = events.shift(), readyFn = function(){
				onReady(events, fn, true);
			};
			
			$(document).one(readyEv, readyFn);
		},
		
		/*
		 * basic DOM-/jQuery-Helpers
		 */
		
		
		capturingEvents: function(names, _maybePrevented){
			if (!document.addEventListener) {
				return;
			}
			if (typeof names == 'string') {
				names = [names];
			}
			$.each(names, function(i, name){
				var handler = function(e){
					e = $.event.fix(e);
					if (_maybePrevented && webshims.capturingEventPrevented) {
						webshims.capturingEventPrevented(e);
					}
					return $.event.handle.call(this, e);
				};
				special[name] = special[name] || {};
				if (special[name].setup || special[name].teardown) {
					return;
				}
				$.extend(special[name], {
					setup: function(){
						this.addEventListener(name, handler, true);
					},
					teardown: function(){
						this.removeEventListener(name, handler, true);
					}
				});
			});
		},
		register: function(name, fn){
			var module = modules[name];
			if (!module) {
				webshims.error("can't find module: " + name);
				return;
			}
			if (module.noAutoCallback) {
				var ready = function(){
					fn($, webshims, window, document, undefined, module.options);
					isReady(name, true);
				};
				if (module.d) {
					onReady(module.d, ready);
				}
				else {
					ready();
				}
			}
		},
		c: {},
		/*
		 * loader
		 */
		loader: {
		
			addModule: function(name, ext){
				modules[name] = ext;
				ext.name = ext.name || name;
				if(!ext.c){
					ext.c = [];
				}
				$.each(ext.c, function(i, comboname){
					if(!webshims.c[comboname]){
						webshims.c[comboname] = [];
					}
					webshims.c[comboname].push(name);
				});
			},
			loadList: (function(){
			
				var loadedModules = [];
				var loadScript = function(src, names){
					if (typeof names == 'string') {
						names = [names];
					}
					$.merge(loadedModules, names);
					loader.loadScript(src, false, names);
				};
				
				var noNeedToLoad = function(name, list){
					if (isReady(name) || $.inArray(name, loadedModules) != -1) {
						return true;
					}
					var module = modules[name];
					var cfg = webCFG[module.f || name] || {};
					var supported;
					if (module) {
						supported = (module.test && $.isFunction(module.test)) ? module.test(list) : module.test;
						if (supported) {
							isReady(name, true);
							return true;
						} else {
							return false;
						}
					}
					return true;
				};
				
				var setDependencies = function(module, list){
					if (module.d && module.d.length) {
						var addDependency = function(i, dependency){
							if (!noNeedToLoad(dependency, list) && $.inArray(dependency, list) == -1) {
								list.push(dependency);
							}
						};
						$.each(module.d, function(i, dependency){
							if (modules[dependency]) {
								addDependency(i, dependency);
							}
							else 
								if (webshimsFeatures[dependency]) {
									$.each(webshimsFeatures[dependency], addDependency);
									onReady(webshimsFeatures[dependency], function(){
										isReady(dependency, true);
									});
								}
						});
						if (!module.noAutoCallback) {
							module.noAutoCallback = true;
						}
					}
				};
				
				return function(list, combo){
					var module;
					var loadCombos = [];
					var i;
					var len;
					var foundCombo;
					var loadCombo = function(j, combo){
						foundCombo = combo;
						$.each(webshims.c[combo], function(i, moduleName){
							if($.inArray(moduleName, loadCombos) == -1 || $.inArray(moduleName, loadedModules) != -1){
								foundCombo = false;
								return false;
							}
						});
						if(foundCombo){
							loadScript('combos/'+foundCombo, webshims.c[foundCombo]);
							return false;
						}
					};
					
					//length of list is dynamically
					for (i = 0; i < list.length; i++) {
						module = modules[list[i]];
						if (!module || noNeedToLoad(module.name, list)) {
							if (!module) {
								webshims.warn('could not find: ' + list[i]);
							}
							continue;
						}
						if (module.css) {
							loader.loadCSS(module.css);
						}
						
						if (module.loadInit) {
							module.loadInit();
						}
						
						module.loaded = true;
						setDependencies(module, list);
						loadCombos.push(module.name);
					}
					
					for(i = 0, len = loadCombos.length; i < len; i++){
						foundCombo = false;
						
						module = loadCombos[i];
						
						if($.inArray(module, loadedModules) == -1){
							if(webshims.debug != 'noCombo'){
								$.each(modules[module].c, loadCombo);
							}
							if(!foundCombo){
								loadScript(modules[module].src || module, module);
							}
						}
					}
				};
			})(),
			
			makePath: function(src){
				if (src.indexOf('//') != -1 || src.indexOf('/') === 0) {
					return src;
				}
				
				if (src.indexOf('.') == -1) {
					src += '.js';
				}
				if (webCFG.addCacheBuster) {
					src += webCFG.addCacheBuster;
				}
				return webCFG.basePath + src;
			},
			
			loadCSS: (function(){
				var parent, loadedSrcs = [];
				return function(src){
					src = this.makePath(src);
					if ($.inArray(src, loadedSrcs) != -1) {
						return;
					}
					parent = parent || $('link, style')[0] || $('script')[0];
					loadedSrcs.push(src);
					$('<link rel="stylesheet" />').insertBefore(parent).attr({
						href: src
					});
				};
			})(),
			
			loadScript: (function(){
				var loadedSrcs = [];
				var scriptLoader;
				return function(src, callback, name){
				
					src = loader.makePath(src);
					if ($.inArray(src, loadedSrcs) != -1) {return;}
					var complete = function(){
						
						complete = null;
						if (callback) {
							callback();
						}
						
						if (name) {
							if (typeof name == 'string') {
								name = name.split(' ');
							}
							$.each(name, function(i, name){
								if (!modules[name]) {
									return;
								}
								if (modules[name].afterLoad) {
									modules[name].afterLoad();
								}
								isReady(!modules[name].noAutoCallback ? name : name + 'FileLoaded', true);
							});
							
						}
					};
					
					loadedSrcs.push(src);
					if(window.require){
						require([src], complete);
					} else if (window.sssl) {
						sssl(src, complete);
					} else if (window.yepnope) {
						yepnope.injectJs(src, complete);
					} else if (window.steal) {
						steal(src).then(complete);
					} 
				};
			})()
		}
	};
	
	/*
	 * shortcuts
	 */
	$.webshims = webshims;
	var protocol = (location.protocol == 'https:') ? 'https://' : 'http://';
	var googleAPIs = protocol + 'ajax.googleapis.com/ajax/libs/';
	var uiLib = googleAPIs + 'jqueryui/1.8.24/';
	var webCFG = webshims.cfg;
	var webshimsFeatures = webshims.features;
	var isReady = webshims.isReady;
	var onReady = webshims.ready;
	var addPolyfill = webshims.addPolyfill;
	var modules = webshims.modules;
	var loader = webshims.loader;
	var loadList = loader.loadList;
	var addModule = loader.addModule;
	var bugs = webshims.bugs;
	var removeCombos = [];
	var importantLogs = {
		warn: 1,
		error: 1
	};
	
	webshims.addMethodName = function(name){
		name = name.split(':');
		var prop = name[1];
		if (name.length == 1) {
			prop = name[0];
			name = name[0];
		} else {
			name = name[0];
		}
		
		$.fn[name] = function(){
			return this.callProp(prop, arguments);
		};
	};
	$.fn.callProp = function(prop, args){
		var ret;
		if(!args){
			args = []; 
		}
		this.each(function(){
			var fn = $.prop(this, prop);
			
			if (fn && fn.apply) {
				ret = fn.apply(this, args);
				if (ret !== undefined) {
					return false;
				}
			} else {
				webshims.warn(prop+ " is not a method of "+ this);
			}
		});
		return (ret !== undefined) ? ret : this;
	};
	
	//activeLang will be overridden

	
	//	set current Lang:
	//		- webshims.activeLang(lang:string);
	//	get current lang
	//		- webshims.activeLang();
	//		- webshims.activeLang({
	//			module: moduleName:string,
	//			callback: callback:function,
	//			langObj: languageObj:array/object
	//		});

	webshims.activeLang = (function(){
		var curLang = navigator.browserLanguage || navigator.language || '';
		onReady('webshimLocalization', function(){
			webshims.activeLang(curLang);
			
		});
		return function(lang){
			if(lang){
				if (typeof lang == 'string' ) {
					curLang = lang;
				} else if(typeof lang == 'object'){
					var args = arguments;
					var that = this;
					onReady('webshimLocalization', function(){
						webshims.activeLang.apply(that, args);
					});
				}
			}
			return curLang;
		};
	})();
	
	$.each(['log', 'error', 'warn', 'info'], function(i, fn){
		webshims[fn] = function(message){
			if(( (importantLogs[fn] && webshims.debug !== false) || webshims.debug) && window.console && console.log){
				return console[(console[fn]) ? fn : 'log'](message);
			}
		};
	});
		
	
	//Overwrite DOM-Ready and implement a new ready-method
	(function(){
		$.isDOMReady = $.isReady;
		if(!$.isDOMReady){
			var $Ready = $.ready;
			$.ready = function(unwait){
				if(unwait !== true && !$.isDOMReady){
					if(document.body){
						$.isDOMReady = true;
						isReady('DOM', true);
						$.ready = $Ready;
					} else {
						setTimeout(function(){
							$.ready(unwait);
						}, 13);
					}
				}
				return $Ready.apply(this, arguments);
			};
			$.ready.promise = $Ready.promise;
		} else {
			isReady('DOM', true);
		}
		$(function(){
			$.isDOMReady = true;
			isReady('DOM', true);
			setTimeout(function(){
				isReady('WINDOWLOAD', true);
			}, 9999);
		});
		$(window).load(function(){
			$.isDOMReady = true;
			isReady('DOM', true);
			isReady('WINDOWLOAD', true);
		});
	})();
	
	/*
	 * jQuery-plugins for triggering dom updates can be also very usefull in conjunction with non-HTML5 DOM-Changes (AJAX)
	 * Example:
	 * $.webshims.addReady(function(context, insertedElement){
	 * 		$('div.tabs', context).add(insertedElement.filter('div.tabs')).tabs();
	 * });
	 * 
	 * $.ajax({
	 * 		success: function(html){
	 * 			$('#main').htmlPolyfill(html);
	 * 		}
	 * });
	 */
	
	(function(){
		var readyFns = [];
		$.extend(webshims, {
			addReady: function(fn){
				var readyFn = function(context, elem){
					webshims.ready('DOM', function(){fn(context, elem);});
				};
				readyFns.push(readyFn);
				readyFn(document, emptyJ);
			},
			triggerDomUpdate: function(context){
				if(!context || !context.nodeType){
					if(context && context.jquery){
						context.each(function(){
							webshims.triggerDomUpdate(this);
						});
					}
					return;
				}
				var type = context.nodeType;
				if(type != 1 && type != 9){return;}
				var elem = (context !== document) ? $(context) : emptyJ;
				$.each(readyFns, function(i, fn){
					fn(context, elem);
				});
			}
		});
		
		$.fn.htmlPolyfill = function(a){
			var ret = $.fn.html.call(this,  a);
			if(ret === this && $.isDOMReady){
				this.each(function(){
					if(this.nodeType == 1){
						webshims.triggerDomUpdate(this);
					}
				});
			}
			return ret;
		};
		
		
		$.each(['after', 'before', 'append', 'prepend', 'replaceWith'], function(i, name){
			$.fn[name+'Polyfill'] = function(a){
				a = $(a);
				$.fn[name].call(this, a);
				if($.isDOMReady){
					a.each(function(){
						if (this.nodeType == 1) {
							webshims.triggerDomUpdate(this);
						}
					});
				}
				return this;
			};
			
		});
		
		$.each(['insertAfter', 'insertBefore', 'appendTo', 'prependTo', 'replaceAll'], function(i, name){
			$.fn[name.replace(/[A-Z]/, function(c){return "Polyfill"+c;})] = function(){
				$.fn[name].apply(this, arguments);
				if($.isDOMReady){
					webshims.triggerDomUpdate(this);
				}
				return this;
			};
		});
		
		$.fn.updatePolyfill = function(){
			if($.isDOMReady){
				webshims.triggerDomUpdate(this);
			}
			return this;
		};
		
		$.each(['getNativeElement', 'getShadowElement', 'getShadowFocusElement'], function(i, name){
			$.fn[name] = function(){
				return this;
			};
		});
		
	})();
	
	//this might be extended by ES5 shim feature
	(function(){
		var defineProperty = 'defineProperty';
		var has = Object.prototype.hasOwnProperty;
		var descProps = ['configurable', 'enumerable', 'writable'];
		var extendUndefined = function(prop){
			for(var i = 0; i < 3; i++){
				if(prop[descProps[i]] === undefined && (descProps[i] !== 'writable' || prop.value !== undefined)){
					prop[descProps[i]] = true;
				}
			}
		};
		var extendProps = function(props){
			if(props){
				for(var i in props){
					if(has.call(props, i)){
						extendUndefined(props[i]);
					}
				}
			}
		};
		if(Object.create){
			webshims.objectCreate = function(proto, props, opts){
				extendProps(props);
				var o = Object.create(proto, props);
				if(opts){
					o.options = $.extend(true, {}, o.options  || {}, opts);
					opts = o.options;
				}
				if(o._create && $.isFunction(o._create)){
					o._create(opts);
				}
				return o;
			};
		}
		if(Object[defineProperty]){
			webshims[defineProperty] = function(obj, prop, desc){
				extendUndefined(desc);
				return Object[defineProperty](obj, prop, desc);
			};
		}
		if(Object.defineProperties){
			webshims.defineProperties = function(obj, props){
				extendProps(props);
				return Object.defineProperties(obj, props);
			};
		}
		webshims.getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
		
		webshims.getPrototypeOf = Object.getPrototypeOf;
	})();
	
	

	
	/*
	 * Start Features 
	 */
	
	/* general modules */
	/* change path $.webshims.modules[moduleName].src */
	
	addModule('jquery-ui', {
		src: uiLib+'jquery-ui.min.js',
		test: function(){return !!($.widget && $.Widget);}
	});
	
	addModule('input-widgets', {
		src: '',
		test: function(){
			return !this.src || !($.widget && !($.fn.datepicker && $.fn.slider));
		}
	});
	
	addModule('swfobject', {
		src: googleAPIs+'swfobject/2.2/swfobject.js',
		test: function(){return ('swfobject' in window);}
	});
	
		
	/* 
	 * polyfill-Modules 
	 */
	
	// webshims lib uses a of http://github.com/kriskowal/es5-shim/ to implement
	addPolyfill('es5', {
		test: !!(Modernizr.ES5 && Function.prototype.bind),
		c: [27, 10, 1, 22]
	});
	
	addPolyfill('dom-extend', {
		f: DOMSUPPORT,
		noAutoCallback: true,
		d: ['es5'],
		c: [27, 10, 9, 12, 17, 26, 16, 25, 8, 1, 24, 19, 11, 13]
	});
		
	
	//<localstorage
	needModernizr('localstorage');
	addPolyfill('json-storage', {
		test: Modernizr.localstorage && 'sessionStorage' in window && 'JSON' in window,
		loadInit: function(){
			loadList(['swfobject']);
		},
		noAutoCallback: true,
		c: [14]
	});
	//>localstorage
	
	
	//<geolocation
	needModernizr('geolocation');
	addPolyfill('geolocation', {
		test: Modernizr.geolocation,
		options: {
			destroyWrite: true
//			,confirmText: ''
		},
		d: ['json-storage'],
		c: [14, 15]
	});
	//>
	
	//<canvas
	needModernizr('canvas', function(){
		var flashCanvas;
		addPolyfill('canvas', {
			src: 'excanvas',
			test: Modernizr.canvas,
			options: {type: 'flash'}, //excanvas | flash | flashpro
			noAutoCallback: true,
			loadInit: function(){
				var type = this.options.type;
				var src;
				if(type && type.indexOf('flash') !== -1 && (!window.swfobject || swfobject.hasFlashPlayerVersion('9.0.0'))){
					window.FlashCanvasOptions = window.FlashCanvasOptions || {};
					flashCanvas = FlashCanvasOptions;
					if(type == 'flash'){
						$.extend(flashCanvas, {
							swfPath: webCFG.basePath + 'FlashCanvas/'
						});
						this.src = 'FlashCanvas/flashcanvas';
						src = flashCanvas.swfPath + 'flashcanvas.swf';
					} else {
						$.extend(flashCanvas, {swfPath: webCFG.basePath + 'FlashCanvasPro/'});
						this.src = 'FlashCanvasPro/flashcanvas';
						//assume, that the user has flash10+
						src = flashCanvas.swfPath + 'flash10canvas.swf';
					}
					//todo: implement cachbuster for flashcanvas
//					if(webCFG.addCacheBuster){
//						src += webCFG.addCacheBuster;
//					}
				}
			},
			afterLoad: function(){
				webshims.addReady(function(context, elem){
					if(context == document){
						if(window.G_vmlCanvasManager && G_vmlCanvasManager.init_ ){
							G_vmlCanvasManager.init_(document);
						}
					}
					$('canvas', context).add(elem.filter('canvas')).each(function(){
						var hasContext = this.getContext;
						if(!hasContext && window.G_vmlCanvasManager){
							G_vmlCanvasManager.initElement(this);
						}
					});
					if(context == document){
						isReady('canvas', true);
					}
				});
			},
			methodNames: ['getContext'],
			d: [DOMSUPPORT]
		});
	});
	//>
	
	
	//<forms
	needModernizr('input inputtypes', function(){
		var modernizrInputAttrs = Modernizr.input;
		var modernizrInputTypes = Modernizr.inputtypes;
		var formvalidation = 'formvalidation';
		var select = $('<select required="" name="a"><option disabled="" /></select>')[0];
		var bustedValidity = false;
		var formExtend, formOptions;
		
		
		addTest(formvalidation, function(){
			return !!(modernizrInputAttrs.required && modernizrInputAttrs.pattern);
		});
		addTest('fieldsetdisabled', function(){
			var fieldset = $('<fieldset />')[0];
			return 'elements' in fieldset && 'disabled' in fieldset;
		});
		
		if(Modernizr[formvalidation]){
			bugs.bustedValidity = bustedValidity = Modernizr.formattribute === false || !Modernizr.fieldsetdisabled || !('value' in document.createElement('output')) || !($('<input type="date" value="1488-12-11" />')[0].validity || {valid: true}).valid || !('required' in select) || (select.validity || {}).valid;
		}
		
		formExtend = Modernizr[formvalidation] && !bustedValidity ? 'form-native-extend' : 'form-extend';
		
		addTest('styleableinputrange', function(){
			if(!modernizrInputTypes.range){
				return false;
			}
			var input = document.createElement('input');
			input.setAttribute('type', 'range');
			return input.style.WebkitAppearance !== undefined;
		});
		
		
		webshims.validationMessages = webshims.validityMessages = [];
		webshims.inputTypes = {};
				
		addPolyfill('form-core', {
			f: 'forms',
			d: ['es5'],
			test: function(toLoad){
				if(formOptions.lightweightDatalist && !this.datalistLoaded){
					this.datalistLoaded = true;
					modules['form-datalist'].f = 'forms';
					webshims.reTest(['form-datalist']);
				}
				return false;
			},
			options: {
				placeholderType: 'value',
				langSrc: 'i18n/errormessages-',
				lightweightDatalist: true,
				availabeLangs: ['ar', 'ch-ZN', 'el', 'es', 'fr', 'he', 'hi', 'hu', 'it', 'ja', 'nl', 'pt-PT', 'ru', 'sv'] //en and de are directly implemented in core
	//			,customMessages: false,
	//			overrideMessages: false,
	//			replaceValidationUI: false
			},
			methodNames: ['setCustomValidity','checkValidity'],
			c: [3, 2, 59, 17, 26, 16, 5, 4, 24, 19]
		});
		
		formOptions = webCFG.forms;
				
		addPolyfill('form-native-extend', {
			f: 'forms',
			test: function(toLoad){
				return (!Modernizr[formvalidation] || bustedValidity) || ((modules['form-number-date-api'].test() || $.inArray('form-number-date-api', toLoad  || []) == -1) && !formOptions.overrideMessages );
			},
			d: ['form-core', DOMSUPPORT, 'form-message'],
			c: [18, 7, 59, 5]
		});
		
		addPolyfill('form-shim-extend', {
			f: 'forms',
			test: function(){
				return Modernizr[formvalidation] && !bustedValidity;
			},
			d: ['form-core', DOMSUPPORT],
			c: [3, 2, 23, 21]
		});
		
		addPolyfill('form-message', {
			f: 'forms',
			test: function(toLoad){
				return !( formOptions.customMessages || !Modernizr[formvalidation] || bugs.validationMessage || bustedValidity || !modules[formExtend].test(toLoad) );
			},
			d: [DOMSUPPORT],
			c: [3, 2, 23, 21, 59, 17, 5, 4]
		});
		
		addPolyfill('form-number-date-api', {
			f: 'forms-ext',
			uiTest: function(){return (modernizrInputTypes.range && modernizrInputTypes.date && modernizrInputTypes.time && modernizrInputTypes.number);},
			test: function(toLoad){
				return this.uiTest();
			},
			d: ['forms', DOMSUPPORT],
			c: [18, 7, 6]
		});
		
		addPolyfill('form-number-date-ui', {
			f: 'forms-ext',
			test: function(){return modules['form-number-date-api'].test() && !this.options.replaceUI;},
			d: ['forms', DOMSUPPORT, 'form-number-date-api'],
			loadInit: function(){
				loadList(['jquery-ui']);
				if(modules['input-widgets'].src){
					loadList(['input-widgets']);
				}
			},
			options: {
				stepArrows: {number: 1, time: 1}, 
				calculateWidth: true,
				slider: {},
				datepicker: {},
				langSrc: uiLib+'i18n/jquery.ui.datepicker-',
				lazyDate: true
	//			,replaceUI: false
			},
			c: [18, 7, 6]
		});
		
		addPolyfill('form-datalist', {
			f: 'forms-ext',
			test: function(){
				return modernizrInputAttrs.list && !formOptions.customDatalist;
			},
			d: ['form-core', DOMSUPPORT],
			c: [3, 59, 18, 24, 19, 11]
		});
	});
	//>
	
	//<details
	if(!('details' in Modernizr)){
		addTest('details', function(){
			return ('open' in document.createElement('details'));
		});
	}
	addPolyfill('details', {
		test: Modernizr.details,
		d: [DOMSUPPORT],
		options: {
//			animate: false,
			text: 'Details'
		},
		c: [12, 13, 15]
	});
	//>
	
	//<mediaelement
	needModernizr('audio video texttrackapi', function(){
		webshims.mediaelement = {};
		var swfTest = function(){
			if(!Modernizr.audio || !Modernizr.video){
				return false;
			}
			if(webshims.mediaelement.loadSwf){
				return false;
			}
			var options = this.options;
			var hasToPlay = options.hasToPlay;
			return !( (!window.swfobject || window.swfobject.hasFlashPlayerVersion('9.0.115')) && (options.preferFlash || (hasToPlay != 'any' && !Modernizr.video[hasToPlay] && !Modernizr.audio[hasToPlay])));
		};
		var deps = ['swfobject', DOMSUPPORT];
		
		addPolyfill('mediaelement-core', {
			f: 'mediaelement',
			noAutoCallback: true,
			options: {
				hasToPlay: 'any',
				preferFlash: false,
				player: 'jwplayer',
				vars: {},
				params: {},
				attrs: {},
				changeSWF: $.noop
			},
			methodNames: ['play', 'pause', 'canPlayType', 'mediaLoad:load'],
			d: deps,
			c: [27, 10, 9, 12, 17, 26, 16, 25, 8, 22, 23, 24, 20]
		});
		addPolyfill('mediaelement-swf', {
			f: 'mediaelement',
			d: deps,
			test: function(){
				return this.options.player != 'jwplayer' ? true : swfTest.apply(this, arguments);
			},
			c: [27, 10, 9, 22, 20]
		});
		
		addPolyfill('mediaelement-jaris', {
			f: 'mediaelement',
			d: deps,
			test: function(){
				return this.options.player == 'jwplayer' ? true : swfTest.apply(this, arguments);
			}
		});
		
		bugs.track = (Modernizr.track && (!Modernizr.texttrackapi || typeof (document.createElement('track').track || {}).mode != 'string'));
		
		addPolyfill('track', {
			options: {
				positionDisplay: true,
				override: bugs.track
			},
			test: function(){
				return Modernizr.track && !this.options.override && !bugs.track;
			},
			d: ['mediaelement', DOMSUPPORT],
			methodNames: ['addTextTrack'],
			c: [27, 26, 25]
		});
		
		addModule('track-ui', {
			d: ['track']
		});
	});
	//>
	
	
	//>removeCombos<
	addPolyfill('feature-dummy', {
		test: true,
		loaded: true,
		c: removeCombos
	});
	
	
	jScripts
		.filter('[data-polyfill-cfg]')
		.each(function(){
			try {
				webshims.setOptions( $(this).data('polyfillCfg') );
			} catch(e){
				webshims.warn('error parsing polyfill cfg: '+e);
			}
		})
		.end()
		.filter('[data-polyfill]')
		.each(function(){
			webshims.polyfill( $.trim( $(this).data('polyfill') || '' ) );
		})
	;
	if(asyncWebshims){
		if(asyncWebshims.cfg){
			webshims.setOptions(asyncWebshims.cfg);
		}
		if(asyncWebshims.lang){
			webshims.activeLang(asyncWebshims.lang);
		}
		if('polyfill' in asyncWebshims){
			webshims.polyfill(asyncWebshims.polyfill);
		}
	}
}));
