(function($, Modernizr, webshims){
	"use strict";
	var hasNative = Modernizr.audio && Modernizr.video;
	var supportsLoop = false;
	var bugs = webshims.bugs;
	
	var loadSwf = function(){
		webshims.ready(swfType, function(){
			if(!webshims.mediaelement.createSWF){
				webshims.mediaelement.loadSwf = true;
				webshims.reTest([swfType], hasNative);
			}
		});
	};
	var options = webshims.cfg.mediaelement;
	var swfType = options && options.player == 'jwplayer' ? 'mediaelement-swf' : 'mediaelement-jaris';
	var hasSwf;
	if(!options){
		webshims.error("mediaelement wasn't implemented but loaded");
		return;
	}
	if(hasNative){
		var videoElem = document.createElement('video');
		Modernizr.videoBuffered = ('buffered' in videoElem);
		supportsLoop = ('loop' in videoElem);
		
		webshims.capturingEvents(['play', 'playing', 'waiting', 'paused', 'ended', 'durationchange', 'loadedmetadata', 'canplay', 'volumechange']);
		
		if(!Modernizr.videoBuffered){
			webshims.addPolyfill('mediaelement-native-fix', {
				f: 'mediaelement',
				test: Modernizr.videoBuffered,
				d: ['dom-support']
			});
			
			webshims.reTest('mediaelement-native-fix');
		}
	}
	
	if(hasNative && !options.preferFlash){
		var switchOptions = function(e){
			var parent = e.target.parentNode;
			if(!options.preferFlash && ($(e.target).is('audio, video') || (parent && $('source:last', parent)[0] == e.target)) ){
				webshims.ready('DOM mediaelement', function(){
					if(hasSwf){
						loadSwf();
					}
					webshims.ready('WINDOWLOAD '+swfType, function(){
						setTimeout(function(){
							if(hasSwf && !options.preferFlash && webshims.mediaelement.createSWF && !$(e.target).closest('audio, video').is('.nonnative-api-active')){
								options.preferFlash = true;
								document.removeEventListener('error', switchOptions, true);
								$('audio, video').mediaLoad();
								webshims.info("switching mediaelements option to 'preferFlash', due to an error with native player: "+e.target.src);
							} else if(!hasSwf){
								document.removeEventListener('error', switchOptions, true);
							}
						}, 20);
					});
				});
			}
		};
		document.addEventListener('error', switchOptions, true);
		$('audio, video').each(function(){
			if(this.error){
				switchOptions({target: this});
			}
		});
	}
	
	
	if(Modernizr.track && !bugs.track){
		(function(){
			
			if(!bugs.track){
				bugs.track = typeof $('<track />')[0].readyState != 'number';
			}
			
			if(!bugs.track){
				try {
					new TextTrackCue(2, 3, '');
				} catch(e){
					bugs.track = true;
				}
			}
			
			var trackOptions = webshims.cfg.track;
			var trackListener = function(e){
				$(e.target).filter('track').each(changeApi);
			};
			var changeApi = function(){
				if(bugs.track || (!trackOptions.override && $.prop(this, 'readyState') == 3)){
					trackOptions.override = true;
					webshims.reTest('track');
					document.removeEventListener('error', trackListener, true);
					if(this && $.nodeName(this, 'track')){
						webshims.error("track support was overwritten. Please check your vtt including your vtt mime-type");
					} else {
						webshims.info("track support was overwritten. due to bad browser support");
					}
				}
			};
			var detectTrackError = function(){
				document.addEventListener('error', trackListener, true);
				
				if(bugs.track){
					changeApi();
				} else {
					$('track').each(changeApi);
				}
			};
			if(!trackOptions.override){
				if(webshims.isReady('track')){
					detectTrackError();
				} else {
					$(detectTrackError);
				}
			}
		})();
		
	}

webshims.register('mediaelement-core', function($, webshims, window, document, undefined){
	hasSwf = swfobject.hasFlashPlayerVersion('9.0.115');
	$('html').addClass(hasSwf ? 'swf' : 'no-swf');
	var mediaelement = webshims.mediaelement;
	mediaelement.parseRtmp = function(data){
		var src = data.src.split('://');
		var paths = src[1].split('/');
		var i, len, found;
		data.server = src[0]+'://'+paths[0]+'/';
		data.streamId = [];
		for(i = 1, len = paths.length; i < len; i++){
			if(!found && paths[i].indexOf(':') !== -1){
				paths[i] = paths[i].split(':')[1];
				found = true;
			}
			if(!found){
				data.server += paths[i]+'/';
			} else {
				data.streamId.push(paths[i]);
			}
		}
		if(!data.streamId.length){
			webshims.error('Could not parse rtmp url');
		}
		data.streamId = data.streamId.join('/');
		console.log(data)
	};
	var getSrcObj = function(elem, nodeName){
		elem = $(elem);
		var src = {src: elem.attr('src') || '', elem: elem, srcProp: elem.prop('src')};
		var tmp;
		
		if(!src.src){return src;}
		
		tmp = elem.attr('data-server');
		if(tmp != null){
			src.server = tmp;
		}
		
		tmp = elem.attr('type');
		if(tmp){
			src.type = tmp;
			src.container = $.trim(tmp.split(';')[0]);
		} else {
			if(!nodeName){
				nodeName = elem[0].nodeName.toLowerCase();
				if(nodeName == 'source'){
					nodeName = (elem.closest('video, audio')[0] || {nodeName: 'video'}).nodeName.toLowerCase();
				}
			}
			if(src.server){
				src.type = nodeName+'/rtmp';
				src.container = nodeName+'/rtmp';
			} else {
				
				tmp = mediaelement.getTypeForSrc( src.src, nodeName, src );
				
				if(tmp){
					src.type = tmp;
					src.container = tmp;
				}
			}
		}
		tmp = elem.attr('media');
		if(tmp){
			src.media = tmp;
		}
		if(src.type == 'audio/rtmp' || src.type == 'video/rtmp'){
			if(src.server){
				src.streamId = src.src;
			} else {
				mediaelement.parseRtmp(src);
			}
		}
		return src;
	};
	
	
	
	var hasYt = !hasSwf && ('postMessage' in window) && hasNative;
	
	var loadTrackUi = function(){
		if(loadTrackUi.loaded){return;}
		loadTrackUi.loaded = true;
		$(function(){
			webshims.loader.loadList(['track-ui']);
		});
	};
	var loadYt = (function(){
		var loaded;
		return function(){
			if(loaded || !hasYt){return;}
			loaded = true;
			webshims.loader.loadScript("https://www.youtube.com/player_api");
			$(function(){
				webshims.polyfill("mediaelement-yt");
			});
		};
	})();
	var loadThird = function(){
		if(hasSwf){
			loadSwf();
		} else {
			loadYt();
		}
	};
	
	webshims.addPolyfill('mediaelement-yt', {
		test: !hasYt,
		d: ['dom-support']
	});
	
	mediaelement.mimeTypes = {
		audio: {
				//ogm shouldn´t be used!
				'audio/ogg': ['ogg','oga', 'ogm'],
				'audio/ogg;codecs="opus"': 'opus',
				'audio/mpeg': ['mp2','mp3','mpga','mpega'],
				'audio/mp4': ['mp4','mpg4', 'm4r', 'm4a', 'm4p', 'm4b', 'aac'],
				'audio/wav': ['wav'],
				'audio/3gpp': ['3gp','3gpp'],
				'audio/webm': ['webm'],
				'audio/fla': ['flv', 'f4a', 'fla'],
				'application/x-mpegURL': ['m3u8', 'm3u']
			},
			video: {
				//ogm shouldn´t be used!
				'video/ogg': ['ogg','ogv', 'ogm'],
				'video/mpeg': ['mpg','mpeg','mpe'],
				'video/mp4': ['mp4','mpg4', 'm4v'],
				'video/quicktime': ['mov','qt'],
				'video/x-msvideo': ['avi'],
				'video/x-ms-asf': ['asf', 'asx'],
				'video/flv': ['flv', 'f4v'],
				'video/3gpp': ['3gp','3gpp'],
				'video/webm': ['webm'],
				'application/x-mpegURL': ['m3u8', 'm3u'],
				'video/MP2T': ['ts']
			}
		}
	;
	
	mediaelement.mimeTypes.source =  $.extend({}, mediaelement.mimeTypes.audio, mediaelement.mimeTypes.video);
	
	mediaelement.getTypeForSrc = function(src, nodeName, data){
		if(src.indexOf('youtube.com/watch?') != -1 || src.indexOf('youtube.com/v/') != -1){
			return 'video/youtube';
		}
		if(src.indexOf('rtmp') === 0){
			return nodeName+'/rtmp';
		}
		src = src.split('?')[0].split('.');
		src = src[src.length - 1];
		var mt;
		
		$.each(mediaelement.mimeTypes[nodeName], function(mimeType, exts){
			if(exts.indexOf(src) !== -1){
				mt = mimeType;
				return false;
			}
		});
		return mt;
	};
	
	
	mediaelement.srces = function(mediaElem, srces){
		mediaElem = $(mediaElem);
		if(!srces){
			srces = [];
			var nodeName = mediaElem[0].nodeName.toLowerCase();
			var src = getSrcObj(mediaElem, nodeName);
			
			if(!src.src){
				
				$('source', mediaElem).each(function(){
					src = getSrcObj(this, nodeName);
					if(src.src){srces.push(src);}
				});
			} else {
				srces.push(src);
			}
			return srces;
		} else {
			mediaElem.removeAttr('src').removeAttr('type').find('source').remove();
			if(!$.isArray(srces)){
				srces = [srces]; 
			}
			srces.forEach(function(src){
				var source = document.createElement('source');
				if(typeof src == 'string'){
					src = {src: src};
				} 
				source.setAttribute('src', src.src);
				if(src.type){
					source.setAttribute('type', src.type);
				}
				if(src.media){
					source.setAttribute('media', src.media);
				}
				mediaElem.append(source);
			});
			
		}
	};
	
	
	$.fn.loadMediaSrc = function(srces, poster){
		return this.each(function(){
			if(poster !== undefined){
				$(this).removeAttr('poster');
				if(poster){
					$.attr(this, 'poster', poster);
				}
			}
			mediaelement.srces(this, srces);
			$(this).mediaLoad();
		});
	};
	
	mediaelement.swfMimeTypes = ['video/3gpp', 'video/x-msvideo', 'video/quicktime', 'video/x-m4v', 'video/mp4', 'video/m4p', 'video/x-flv', 'video/flv', 'audio/mpeg', 'audio/aac', 'audio/mp4', 'audio/x-m4a', 'audio/m4a', 'audio/mp3', 'audio/x-fla', 'audio/fla', 'youtube/flv', 'jwplayer/jwplayer', 'video/youtube', 'video/rtmp', 'audio/rtmp'];
	
	mediaelement.canThirdPlaySrces = function(mediaElem, srces){
		var ret = '';
		if(hasSwf || hasYt){
			mediaElem = $(mediaElem);
			srces = srces || mediaelement.srces(mediaElem);
			$.each(srces, function(i, src){
				if(src.container && src.src && ((hasSwf && mediaelement.swfMimeTypes.indexOf(src.container) != -1) || (hasYt && src.container == 'video/youtube'))){
					ret = src;
					return false;
				}
			});
			
		}
		
		return ret;
	};
	
	var nativeCanPlayType = {};
	mediaelement.canNativePlaySrces = function(mediaElem, srces){
		var ret = '';
		if(hasNative){
			mediaElem = $(mediaElem);
			var nodeName = (mediaElem[0].nodeName || '').toLowerCase();
			if(!nativeCanPlayType[nodeName]){return ret;}
			srces = srces || mediaelement.srces(mediaElem);
			
			$.each(srces, function(i, src){
				if(src.type && nativeCanPlayType[nodeName].prop._supvalue.call(mediaElem[0], src.type) ){
					ret = src;
					return false;
				}
			});
		}
		return ret;
	};
	
	mediaelement.setError = function(elem, message){
		if(!message){
			message = "can't play sources";
		}
		
		$(elem).pause().data('mediaerror', message);
		webshims.warn('mediaelementError: '+ message);
		setTimeout(function(){
			if($(elem).data('mediaerror')){
				$(elem).trigger('mediaerror');
			}
		}, 1);
	};
	
	var handleThird = (function(){
		var requested;
		return function( mediaElem, ret, data ){
			if(!requested){
				loadTrackUi();
			}
			webshims.ready(hasSwf ? swfType : 'mediaelement-yt', function(){
				if(mediaelement.createSWF){
					mediaelement.createSWF( mediaElem, ret, data );
				} else if(!requested) {
					requested = true;
					loadThird();
					//readd to ready
					handleThird( mediaElem, ret, data );
				}
			});
			if(!requested && hasYt && !mediaelement.createSWF){
				loadYt();
			}
		};
	})();
	
	var stepSources = function(elem, data, useSwf, _srces, _noLoop){
		var ret;
		if(useSwf || (useSwf !== false && data && data.isActive == 'third')){
			ret = mediaelement.canThirdPlaySrces(elem, _srces);
			if(!ret){
				if(_noLoop){
					mediaelement.setError(elem, false);
				} else {
					stepSources(elem, data, false, _srces, true);
				}
			} else {
				handleThird(elem, ret, data);
			}
		} else {
			ret = mediaelement.canNativePlaySrces(elem, _srces);
			if(!ret){
				if(_noLoop){
					mediaelement.setError(elem, false);
					if(data && data.isActive == 'third') {
						mediaelement.setActive(elem, 'html5', data);
					}
				} else {
					stepSources(elem, data, true, _srces, true);
				}
			} else if(data && data.isActive == 'third') {
				mediaelement.setActive(elem, 'html5', data);
			}
		}
	};
	var stopParent = /^(?:embed|object|datalist)$/i;
	var selectSource = function(elem, data){
		var baseData = webshims.data(elem, 'mediaelementBase') || webshims.data(elem, 'mediaelementBase', {});
		var _srces = mediaelement.srces(elem);
		var parent = elem.parentNode;
		
		clearTimeout(baseData.loadTimer);
		$.data(elem, 'mediaerror', false);
		
		if(!_srces.length || !parent || parent.nodeType != 1 || stopParent.test(parent.nodeName || '')){return;}
		data = data || webshims.data(elem, 'mediaelement');
		stepSources(elem, data, options.preferFlash || undefined, _srces);
	};
	
	
	$(document).on('ended', function(e){
		var data = webshims.data(e.target, 'mediaelement');
		if( supportsLoop && (!data || data.isActive == 'html5') && !$.prop(e.target, 'loop')){return;}
		setTimeout(function(){
			if( $.prop(e.target, 'paused') || !$.prop(e.target, 'loop') ){return;}
			$(e.target).prop('currentTime', 0).play();
		}, 1);
		
	});
	if(!supportsLoop){
		webshims.defineNodeNamesBooleanProperty(['audio', 'video'], 'loop');
	}
	
	['audio', 'video'].forEach(function(nodeName){
		var supLoad = webshims.defineNodeNameProperty(nodeName, 'load',  {
			prop: {
				value: function(){
					var data = webshims.data(this, 'mediaelement');
					selectSource(this, data);
					if(hasNative && (!data || data.isActive == 'html5') && supLoad.prop._supvalue){
						supLoad.prop._supvalue.apply(this, arguments);
					}
				}
			}
		});
		nativeCanPlayType[nodeName] = webshims.defineNodeNameProperty(nodeName, 'canPlayType',  {
			prop: {
				value: function(type){
					var ret = '';
					if(hasNative && nativeCanPlayType[nodeName].prop._supvalue){
						ret = nativeCanPlayType[nodeName].prop._supvalue.call(this, type);
						if(ret == 'no'){
							ret = '';
						}
					}
					if(!ret && hasSwf){
						type = $.trim((type || '').split(';')[0]);
						if(mediaelement.swfMimeTypes.indexOf(type) != -1){
							ret = 'maybe';
						}
					}
					return ret;
				}
			}
		});
	});
	webshims.onNodeNamesPropertyModify(['audio', 'video'], ['src', 'poster'], {
		set: function(){
			var elem = this;
			var baseData = webshims.data(elem, 'mediaelementBase') || webshims.data(elem, 'mediaelementBase', {});
			clearTimeout(baseData.loadTimer);
			baseData.loadTimer = setTimeout(function(){
				selectSource(elem);
				elem = null;
			}, 9);
		}
	});
		
	var initMediaElements = function(){
		
		webshims.addReady(function(context, insertedElement){
			var media = $('video, audio', context)
				.add(insertedElement.filter('video, audio'))
				.each(function(){
					if($.browser.msie && webshims.browserVersion > 8 && $.prop(this, 'paused') && !$.prop(this, 'readyState') && $(this).is('audio[preload="none"][controls]:not([autoplay])')){
						$(this).prop('preload', 'metadata').mediaLoad();
					} else {
						selectSource(this);
					}
					
					
					
					if(hasNative){
						var bufferTimer;
						var lastBuffered;
						var elem = this;
						var getBufferedString = function(){
							var buffered = $.prop(elem, 'buffered');
							if(!buffered){return;}
							var bufferString = "";
							for(var i = 0, len = buffered.length; i < len;i++){
								bufferString += buffered.end(i);
							}
							return bufferString;
						};
						var testBuffer = function(){
							var buffered = getBufferedString();
							if(buffered != lastBuffered){
								lastBuffered = buffered;
								$(elem).triggerHandler('progress');
							}
						};
						
						$(this)
							.on({
								'play loadstart progress': function(e){
									if(e.type == 'progress'){
										lastBuffered = getBufferedString();
									}
									clearTimeout(bufferTimer);
									bufferTimer = setTimeout(testBuffer, 999);
								},
								'emptied stalled mediaerror abort suspend': function(e){
									if(e.type == 'emptied'){
										lastBuffered = false;
									}
									clearTimeout(bufferTimer);
								}
							})
						;
					}
					
				})
			;
			if(!loadTrackUi.loaded && $('track', media).length){
				loadTrackUi();
			}
			media = null;
		});
	};
	
	if(Modernizr.track && !bugs.track){
		webshims.defineProperty(TextTrack.prototype, 'shimActiveCues', {
			get: function(){
				return this._shimActiveCues || this.activeCues;
			}
		});
	}
	//set native implementation ready, before swf api is retested
	if(hasNative){
		webshims.isReady('mediaelement-core', true);
		initMediaElements();
		webshims.ready('WINDOWLOAD mediaelement', loadThird);
	} else {
		webshims.ready(swfType, initMediaElements);
	}
	webshims.ready('WINDOWLOAD mediaelement', loadTrackUi);
});
})(jQuery, Modernizr, jQuery.webshims);