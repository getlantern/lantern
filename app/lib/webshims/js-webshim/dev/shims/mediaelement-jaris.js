jQuery.webshims.register('mediaelement-jaris', function($, webshims, window, document, undefined, options){
	"use strict";
	
	var mediaelement = webshims.mediaelement;
	var swfobject = window.swfobject;
	var hasNative = Modernizr.audio && Modernizr.video;
	var hasFlash = swfobject.hasFlashPlayerVersion('9.0.115');
	var loadedSwf = 0;
	var getProps = {
		paused: true,
		ended: false,
		currentSrc: '',
		duration: window.NaN,
		readyState: 0,
		networkState: 0,
		videoHeight: 0,
		videoWidth: 0,
		error: null,
		buffered: {
			start: function(index){
				if(index){
					webshims.error('buffered index size error');
					return;
				}
				return 0;
			},
			end: function(index){
				if(index){
					webshims.error('buffered index size error');
					return;
				}
				return 0;
			},
			length: 0
		}
	};
	var getPropKeys = Object.keys(getProps);
	
	var getSetProps = {
		currentTime: 0,
		volume: 1,
		muted: false
	};
	var getSetPropKeys = Object.keys(getSetProps);
	
	var playerStateObj = $.extend({
		isActive: 'html5',
		activating: 'html5',	
		wasSwfReady: false,
		_bufferedEnd: 0,
		_bufferedStart: 0,
		currentTime: 0,
		_ppFlag: undefined,
		_calledMeta: false,
		lastDuration: 0
	}, getProps, getSetProps);
	
	var idRep = /^jarisplayer-/;
	var getSwfDataFromID = function(id){
		
		var elem = document.getElementById(id.replace(idRep, ''));
		if(!elem){return;}
		var data = webshims.data(elem, 'mediaelement');
		return data.isActive == 'third' ? data : null;
	};
	
	
	var getSwfDataFromElem = function(elem){
		try {
			(elem.nodeName);
		} catch(er){
			return null;
		}
		var data = webshims.data(elem, 'mediaelement');
		return (data && data.isActive== 'third') ? data : null;
	};
	
	var trigger = function(elem, evt){
		evt = $.Event(evt);
		evt.preventDefault();
		$.event.trigger(evt, undefined, elem);
	};
	
	var playerSwfPath = options.playerPath || webshims.cfg.basePath + "swf/" + (options.playerName || 'JarisFLVPlayer.swf');
	
	webshims.extendUNDEFProp(options.params, {
		allowscriptaccess: 'always',
		allowfullscreen: 'true',
		wmode: 'transparent',
		allowNetworking: 'all'
	});
	webshims.extendUNDEFProp(options.vars, {
		controltype: '1',
		jsapi: '1'
	});
	webshims.extendUNDEFProp(options.attrs, {
		bgcolor: '#000000'
	});
	
	var setReadyState = function(readyState, data){
		if(readyState < 3){
			clearTimeout(data._canplaythroughTimer);
		}
		if(readyState >= 3 && data.readyState < 3){
			data.readyState = readyState;
			trigger(data._elem, 'canplay');
			if(!data.paused){
				trigger(data._elem, 'playing');
			}
			clearTimeout(data._canplaythroughTimer);
			data._canplaythroughTimer = setTimeout(function(){
				setReadyState(4, data);
			}, 4000);
		}
		if(readyState >= 4 && data.readyState < 4){
			data.readyState = readyState;
			trigger(data._elem, 'canplaythrough');
		}
		data.readyState = readyState;
	};
	
	$.extend($.event.customEvent, {
		updatemediaelementdimensions: true,
		flashblocker: true,
		swfstageresize: true,
		mediaelementapichange: true
	});
	
	mediaelement.jarisEvent = {};
	var localConnectionTimer;
	var onEvent = {
		onPlayPause: function(jaris, data, override){
			var playing, type;
			if(override == null){
				try {
					playing = data.api.api_get("isPlaying");
				} catch(e){}
			} else {
				playing = override;
			}
			if(playing == data.paused){
				
				data.paused = !playing;
				type = data.paused ? 'pause' : 'play';
				data._ppFlag = true;
				trigger(data._elem, type);
				if(data.readyState < 3){
					setReadyState(3, data);
				}
				if(!data.paused){
					trigger(data._elem, 'playing');
				}
			}
		},
		onNotBuffering: function(jaris, data){
			setReadyState(3, data);
		},
		onDataInitialized: function(jaris, data){
			
			var oldDur = data.duration;
			var durDelta;
			data.duration = jaris.duration;
			if(oldDur == data.duration || isNaN(data.duration)){return;}
			
			if(data._calledMeta && ((durDelta = Math.abs(data.lastDuration - data.duration)) < 2)){return;}
			
			
			
			data.videoHeight = jaris.height;
			data.videoWidth = jaris.width;
			
			if(!data.networkState){
				data.networkState = 2;
			}
			if(data.readyState < 1){
				setReadyState(1, data);
			}
			clearTimeout(data._durationChangeTimer);
			if(data._calledMeta && data.duration){
				data._durationChangeTimer = setTimeout(function(){
					data.lastDuration = data.duration;
					trigger(data._elem, 'durationchange');
				}, durDelta > 50 ? 0 : durDelta > 9 ? 9 : 99);
			} else {
				data.lastDuration = data.duration;
				if(data.duration){
					trigger(data._elem, 'durationchange');
				}
				if(!data._calledMeta){
					trigger(data._elem, 'loadedmetadata');
				}
			}
			data._calledMeta = true;
		},
		onBuffering: function(jaris, data){
			if(data.ended){
				data.ended = false;
			}
			setReadyState(1, data);
			trigger(data._elem, 'waiting');
		},
		onTimeUpdate: function(jaris, data){
			if(data.ended){
				data.ended = false;
			}
			if(data.readyState < 3){
				setReadyState(3, data);
				trigger(data._elem, 'playing');
			}
			
			trigger(data._elem, 'timeupdate');
		},
		onProgress: function(jaris, data){
			if(data.ended){
				data.ended = false;
			}
			if(!data.duration || isNaN(data.duration)){
				return;
			}
			var percentage = jaris.loaded / jaris.total;
			if(percentage > 0.02 && percentage < 0.2){
				setReadyState(3, data);
			} else if(percentage > 0.2){
				if(percentage > 0.99){
					data.networkState = 1;
				}
				setReadyState(4, data);
			}
			if(data._bufferedEnd && (data._bufferedEnd > percentage)){
				data._bufferedStart = data.currentTime || 0;
			}
			
			data._bufferedEnd = percentage;
			data.buffered.length = 1;
			
			$.event.trigger('progress', undefined, data._elem, true);
		},
		onPlaybackFinished: function(jaris, data){
			if(data.readyState < 4){
				setReadyState(4, data);
			}
			data.ended = true;
			trigger(data._elem, 'ended');
		},
		onVolumeChange: function(jaris, data){
			if(data.volume != jaris.volume || data.muted != jaris.mute){
				data.volume = jaris.volume;
				data.muted = jaris.mute;
				trigger(data._elem, 'volumechange');
			}
		},
		ready: (function(){
			var testAPI = function(data){
				var passed = true;
				
				try {
					data.api.api_get('volume');
				} catch(er){
					passed = false;
				}
				return passed;
			};
			
			return function(jaris, data){
				var i = 0;
				var doneFn = function(){
					if(i > 9){
						data.tryedReframeing = 0;
						return;
					}
					i++;
					
					data.tryedReframeing++;
					if(testAPI(data)){
						data.wasSwfReady = true;
						data.tryedReframeing = 0;
						startAutoPlay(data);
						workActionQueue(data);
					} else if(data.tryedReframeing < 6) {
						if(data.tryedReframeing < 3){
							data.reframeTimer = setTimeout(doneFn, 9);
							data.shadowElem.css({overflow: 'visible'});
							setTimeout(function(){
								data.shadowElem.css({overflow: 'hidden'});
							}, 1);
						} else {
							data.shadowElem.css({overflow: 'hidden'});
							$(data._elem).mediaLoad();
						}
					} else {
						clearTimeout(data.reframeTimer);
						webshims.error("reframing error");
					}
				};
				if(!data || !data.api){return;}
				if(!data.tryedReframeing){
					data.tryedReframeing = 0;
				}
				clearTimeout(localConnectionTimer);
				clearTimeout(data.reframeTimer);
				data.shadowElem.removeClass('flashblocker-assumed');
				
				if(!i){
					doneFn();
				} else {
					data.reframeTimer = setTimeout(doneFn, 9);
				}
				
			};
		})()
	};
	
	onEvent.onMute = onEvent.onVolumeChange;
	
	
	var workActionQueue = function(data){
		var actionLen = data.actionQueue.length;
		var i = 0;
		var operation;
		
		if(actionLen && data.isActive == 'third'){
			while(data.actionQueue.length && actionLen > i){
				i++;
				operation = data.actionQueue.shift();
				try{
					data.api[operation.fn].apply(data.api, operation.args);
				} catch(er){
					webshims.warn(er);
				}
			}
		}
		if(data.actionQueue.length){
			data.actionQueue = [];
		}
	};
	var startAutoPlay = function(data){
		if(!data){return;}
		if( (data._ppFlag === undefined && ($.prop(data._elem, 'autoplay')) || !data.paused)){
			setTimeout(function(){
				if(data.isActive == 'third' && (data._ppFlag === undefined || !data.paused)){
					
					try {
						$(data._elem).play();
						data._ppFlag = true;
					} catch(er){}
				}
			}, 1);
		}
		
		if(data.muted){
			$.prop(data._elem, 'muted', true);
		}
		if(data.volume != 1){
			$.prop(data._elem, 'volume', data.volume);
		}
	};
	
	
	var addMediaToStopEvents = $.noop;
	if(hasNative){
		var stopEvents = {
			play: 1,
			playing: 1
		};
		var hideEvtArray = ['play', 'pause', 'playing', 'canplay', 'progress', 'waiting', 'ended', 'loadedmetadata', 'durationchange', 'emptied'];
		var hidevents = hideEvtArray.map(function(evt){
			return evt +'.webshimspolyfill';
		}).join(' ');
		
		var hidePlayerEvents = function(event){
			var data = webshims.data(event.target, 'mediaelement');
			if(!data){return;}
			var isNativeHTML5 = ( event.originalEvent && event.originalEvent.type === event.type );
			if( isNativeHTML5 == (data.activating == 'third') ){
				event.stopImmediatePropagation();
				if(stopEvents[event.type] && data.isActive != data.activating){
					$(event.target).pause();
				}
			}
		};
		
		addMediaToStopEvents = function(elem){
			$(elem)
				.off(hidevents)
				.on(hidevents, hidePlayerEvents)
			;
			hideEvtArray.forEach(function(evt){
				webshims.moveToFirstEvent(elem, evt);
			});
		};
		addMediaToStopEvents(document);
	}
	
	
	mediaelement.setActive = function(elem, type, data){
		if(!data){
			data = webshims.data(elem, 'mediaelement');
		}
		if(!data || data.isActive == type){return;}
		if(type != 'html5' && type != 'third'){
			webshims.warn('wrong type for mediaelement activating: '+ type);
		}
		var shadowData = webshims.data(elem, 'shadowData');
		data.activating = type;
		$(elem).pause();
		data.isActive = type;
		if(type == 'third'){
			shadowData.shadowElement = shadowData.shadowFocusElement = data.shadowElem[0];
			$(elem).addClass('swf-api-active nonnative-api-active').hide().getShadowElement().show();
		} else {
			$(elem).removeClass('swf-api-active nonnative-api-active').show().getShadowElement().hide();
			shadowData.shadowElement = shadowData.shadowFocusElement = false;
		}
		$(elem).trigger('mediaelementapichange');
	};
	
	
	
	var resetSwfProps = (function(){
		var resetProtoProps = ['_calledMeta', 'lastDuration', '_bufferedEnd', '_bufferedStart', '_ppFlag', 'currentSrc', 'currentTime', 'duration', 'ended', 'networkState', 'paused', 'videoHeight', 'videoWidth'];
		var len = resetProtoProps.length;
		return function(data){
			
			if(!data){return;}
			var lenI = len;
			var networkState = data.networkState;
			setReadyState(0, data);
			clearTimeout(data._durationChangeTimer);
			while(--lenI > -1){
				delete data[resetProtoProps[lenI]];
			}
			data.actionQueue = [];
			data.buffered.length = 0;
			if(networkState){
				trigger(data._elem, 'emptied');
			}
		};
	})();
	
	var setElementDimension = function(data, hasControls){
		var elem = data._elem;
		var box = data.shadowElem;
		$(elem)[hasControls ? 'addClass' : 'removeClass']('webshims-controls');
		if(data._elemNodeName == 'audio' && !hasControls){
			box.css({width: 0, height: 0});
		} else {
			box.css({
				width: elem.style.width || $(elem).width(),
				height: elem.style.height || $(elem).height()
			});
		}
	};
	
	mediaelement.createSWF = function( elem, canPlaySrc, data ){
		if(!hasFlash){
			setTimeout(function(){
				$(elem).mediaLoad(); //<- this should produce a mediaerror
			}, 1);
			return;
		}
		
		if(loadedSwf < 1){
			loadedSwf = 1;
		} else {
			loadedSwf++;
		}
		var isRtmp = canPlaySrc.type == 'audio/rtmp' || canPlaySrc.type == 'video/rtmp';
		var vars = $.extend({}, options.vars, {
				poster: $.prop(elem, 'poster') || '',
				source: canPlaySrc.streamId || canPlaySrc.srcProp,
				server: canPlaySrc.server || ''
		});
		var elemVars = $(elem).data('vars') || {};
		
		if(!data){
			data = webshims.data(elem, 'mediaelement');
		}
		
		var hasControls = $.prop(elem, 'controls');
		var elemId = 'jarisplayer-'+ webshims.getID(elem);
		
		var params = $.extend(
			{},
			options.params,
			$(elem).data('params')
		);
		var elemNodeName = elem.nodeName.toLowerCase();
		var attrs = $.extend(
			{},
			options.attrs,
			{
				name: elemId,
				id: elemId
			},
			$(elem).data('attrs')
		);
		var box;
		
		if(data && data.swfCreated){
			mediaelement.setActive(elem, 'third', data);
			
			data.currentSrc = canPlaySrc.srcProp;
			
			data.shadowElem.html('<div id="'+ elemId +'">');
			
			data.api = false;
			data.actionQueue = [];
			box = data.shadowElem;
			resetSwfProps(data);
		} else {
			box = $('<div class="polyfill-'+ (elemNodeName) +' polyfill-mediaelement" id="wrapper-'+ elemId +'"><div id="'+ elemId +'"></div>')
				.css({
					position: 'relative',
					overflow: 'hidden'
				})
			;
			data = webshims.data(elem, 'mediaelement', webshims.objectCreate(playerStateObj, {
				actionQueue: {
					value: []
				},
				shadowElem: {
					value: box
				},
				_elemNodeName: {
					value: elemNodeName
				},
				_elem: {
					value: elem
				},
				currentSrc: {
					value: canPlaySrc.srcProp
				},
				swfCreated: {
					value: true
				},
				id: {
					value: elemId.replace(/-/g, '')
				},
				buffered: {
					value: {
						start: function(index){
							if(index >= data.buffered.length){
								webshims.error('buffered index size error');
								return;
							}
							return 0;
						},
						end: function(index){
							if(index >= data.buffered.length){
								webshims.error('buffered index size error');
								return;
							}
							return ( (data.duration - data._bufferedStart) * data._bufferedEnd) + data._bufferedStart;
						},
						length: 0
					}
				}
			}));
			setElementDimension(data, hasControls);
		
			box.insertBefore(elem);
			
			if(hasNative){
				$.extend(data, {volume: $.prop(elem, 'volume'), muted: $.prop(elem, 'muted'), paused: $.prop(elem, 'paused')});
			}
			
			webshims.addShadowDom(elem, box);
			addMediaToStopEvents(elem);
			mediaelement.setActive(elem, 'third', data);
			$(elem).on('updatemediaelementdimensions updateshadowdom', function(){
				setElementDimension(data, $.prop(elem, 'controls'));
			});
		}
		
		if(!mediaelement.jarisEvent[data.id]){
			mediaelement.jarisEvent[data.id] = function(jaris){
				if(jaris.type == 'ready'){
					if(data.api){
						onEvent[jaris.type](jaris, data);
					} else {
						setTimeout(function(){
							onEvent[jaris.type](jaris, data);
						}, 9);
					}
				} else {
					data.currentTime = jaris.position;
					
					if(data.api){
						if(!data._calledMeta && isNaN(jaris.duration) && data.duration != jaris.duration && isNaN(data.duration)){
							onEvent.onDataInitialized(jaris, data);
						}
						
						if(!data._ppFlag && jaris.type != 'onPlayPause'){
							onEvent.onPlayPause(jaris, data);
						}
						
						if(onEvent[jaris.type]){
							onEvent[jaris.type](jaris, data);
						}
					}
					data.duration = jaris.duration;
				}
				
			};
		}
		
		$.extend(vars, 
			{
				id: elemId,
				evtId: data.id,
				controls: ''+hasControls,
				autostart: 'false',
				nodename: elemNodeName
			},
			elemVars
		);
		
		if(isRtmp){
			vars.streamtype = 'rtmp';
		} else if(canPlaySrc.type == 'audio/mpeg' || canPlaySrc.type == 'audio/mp3'){
			vars.type = 'audio';
			vars.streamtype = 'file';
		} else if(canPlaySrc.type == 'video/youtube'){
			vars.streamtype = 'youtube';
		}
		options.changeSWF(vars, elem, canPlaySrc, data, 'embed');
		clearTimeout(data.flashBlock);
		swfobject.embedSWF(playerSwfPath, elemId, "100%", "100%", "9.0.0", false, vars, params, attrs, function(swfData){
			
			if(swfData.success){
				
				data.api = swfData.ref;
				
				if(!hasControls){
					$(swfData.ref).attr('tabindex', '-1').css('outline', 'none');
				}
				
				data.flashBlock = setTimeout(function(){
					if((!swfData.ref.parentNode && box[0].parentNode) || swfData.ref.style.display == "none"){
						box.addClass('flashblocker-assumed');
						$(elem).trigger('flashblocker');
						webshims.warn("flashblocker assumed");
					}
					$(swfData.ref).css({'minHeight': '2px', 'minWidth': '2px', display: 'block'});
				}, 9);
				
				if(!localConnectionTimer){
					clearTimeout(localConnectionTimer);
					localConnectionTimer = setTimeout(function(){
						var flash = $(swfData.ref);
						if(flash[0].offsetWidth > 1 && flash[0].offsetHeight > 1 && location.protocol.indexOf('file:') === 0){
							webshims.error("Add your local development-directory to the local-trusted security sandbox:  http://www.macromedia.com/support/documentation/en/flashplayer/help/settings_manager04.html");
						} else if(flash[0].offsetWidth < 2 || flash[0].offsetHeight < 2) {
							webshims.warn("JS-SWF connection can't be established on hidden or unconnected flash objects");
						}
						flash = null;
					}, 8000);
				}
			}
		});
		
	};
	
	
	var queueSwfMethod = function(elem, fn, args, data){
		data = data || getSwfDataFromElem(elem);
		
		if(data){
			if(data.api && data.api[fn]){
				data.api[fn].apply(data.api, args || []);
			} else {
				//todo add to queue
				data.actionQueue.push({fn: fn, args: args});
				
				if(data.actionQueue.length > 10){
					setTimeout(function(){
						if(data.actionQueue.length > 5){
							data.actionQueue.shift();
						}
					}, 99);
				}
			}
			return data;
		}
		return false;
	};
	
	['audio', 'video'].forEach(function(nodeName){
		var descs = {};
		var mediaSup;
		var createGetProp = function(key){
			if(nodeName == 'audio' && (key == 'videoHeight' || key == 'videoWidth')){return;}
			
			descs[key] = {
				get: function(){
					var data = getSwfDataFromElem(this);
					if(data){
						return data[key];
					} else if(hasNative && mediaSup[key].prop._supget) {
						return mediaSup[key].prop._supget.apply(this);
					} else {
						return playerStateObj[key];
					}
				},
				writeable: false
			};
		};
		var createGetSetProp = function(key, setFn){
			createGetProp(key);
			delete descs[key].writeable;
			descs[key].set = setFn;
		};
		
		createGetSetProp('volume', function(v){
			var data = getSwfDataFromElem(this);
			if(data){
				v *= 1;
				if(!isNaN(v)){
					
					if(v < 0 || v > 1){
						webshims.error('volume greater or less than allowed '+ (v / 100));
					}
					
					queueSwfMethod(this, 'api_volume', [v], data);
					
					
					if(data.volume != v){
						data.volume = v;
						trigger(data._elem, 'volumechange');
					}
					data = null;
				} 
			} else if(mediaSup.volume.prop._supset) {
				return mediaSup.volume.prop._supset.apply(this, arguments);
			}
		});
		
		createGetSetProp('muted', function(m){
			var data = getSwfDataFromElem(this);
			if(data){
				m = !!m;
				queueSwfMethod(this, 'api_muted', [m], data);
				if(data.muted != m){
					data.muted = m;
					trigger(data._elem, 'volumechange');
				}
				data = null;
			} else if(mediaSup.muted.prop._supset) {
				return mediaSup.muted.prop._supset.apply(this, arguments);
			}
		});
		
		
		createGetSetProp('currentTime', function(t){
			var data = getSwfDataFromElem(this);
			if(data){
				t *= 1;
				if (!isNaN(t)) {
					queueSwfMethod(this, 'api_seek', [t], data);
				}
				 
			} else if(mediaSup.currentTime.prop._supset) {
				return mediaSup.currentTime.prop._supset.apply(this, arguments);
			}
		});
		
		['play', 'pause'].forEach(function(fn){
			descs[fn] = {
				value: function(){
					var data = getSwfDataFromElem(this);
					if(data){
						if(data.stopPlayPause){
							clearTimeout(data.stopPlayPause);
						}
						queueSwfMethod(this, fn == 'play' ? 'api_play' : 'api_pause', [], data);
						
						data._ppFlag = true;
						if(data.paused != (fn != 'play')){
							data.paused = fn != 'play';
							trigger(data._elem, fn);
						}
					} else if(mediaSup[fn].prop._supvalue) {
						return mediaSup[fn].prop._supvalue.apply(this, arguments);
					}
				}
			};
		});
		
		getPropKeys.forEach(createGetProp);
		
		webshims.onNodeNamesPropertyModify(nodeName, 'controls', function(val, boolProp){
			var data = getSwfDataFromElem(this);
			$(this)[boolProp ? 'addClass' : 'removeClass']('webshims-controls');
			
			if(data){
				webshims.warn("changing controls currently not fully supported with jaris player");
				if(nodeName == 'audio'){
					setElementDimension(data, boolProp);
				}
				
				queueSwfMethod(this, 'api_controls', [boolProp], data);
			}
		});
		
		mediaSup = webshims.defineNodeNameProperties(nodeName, descs, 'prop');
	});
	
	if(hasFlash){
		var oldClean = $.cleanData;
		var gcBrowser = $.browser.msie && webshims.browserVersion < 9;
		var flashNames = {
			object: 1,
			OBJECT: 1
		};
		$.cleanData = function(elems){
			var i, len, prop;
			if(elems && (len = elems.length) && loadedSwf){
				
				for(i = 0; i < len; i++){
					if(flashNames[elems[i].nodeName]){
						if('api_pause' in elems[i]){
							loadedSwf--;
							try {
								elems[i].api_pause();
							} catch(er){}
						}
						if(gcBrowser){
							try {
								for (prop in elems[i]) {
									if (typeof elems[i][prop] == "function") {
										elems[i][prop] = null;
									}
								}
							} catch(er){}
						}
					}
				}
				
			}
			return oldClean.apply(this, arguments);
		};
	}

	if(!hasNative){
		
		['poster', 'src'].forEach(function(prop){
			webshims.defineNodeNamesProperty(prop == 'src' ? ['audio', 'video', 'source'] : ['video'], prop, {
				//attr: {},
				reflect: true,
				propType: 'src'
			});
		});
		
		
		['autoplay', 'controls'].forEach(function(name){
			webshims.defineNodeNamesBooleanProperty(['audio', 'video'], name);
		});
			
		webshims.defineNodeNamesProperties(['audio', 'video'], {
			HAVE_CURRENT_DATA: {
				value: 2
			},
			HAVE_ENOUGH_DATA: {
				value: 4
			},
			HAVE_FUTURE_DATA: {
				value: 3
			},
			HAVE_METADATA: {
				value: 1
			},
			HAVE_NOTHING: {
				value: 0
			},
			NETWORK_EMPTY: {
				value: 0
			},
			NETWORK_IDLE: {
				value: 1
			},
			NETWORK_LOADING: {
				value: 2
			},
			NETWORK_NO_SOURCE: {
				value: 3
			}
					
		}, 'prop');
	}
	
	
});