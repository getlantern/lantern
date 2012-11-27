jQuery.webshims.register('mediaelement-yt', function($, webshims, window, document, undefined, options){
"use strict";
var mediaelement = webshims.mediaelement;
var ytAPI = jQuery.Deferred();
window.onYouTubePlayerAPIReady = function() {
	ytAPI.resolve();
};
if(window.YT && YT.Player){
	window.onYouTubePlayerAPIReady();
}

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
	_metadata: false,
	_callMeta: false,
	currentTime: 0,
	_buffered: 0,
	_ppFlag: undefined
}, getProps, getSetProps);

var trigger = function(elem, evt){
	evt = $.Event(evt);
	evt.preventDefault();
	$.event.trigger(evt, undefined, elem);
};

var resetSwfProps = (function(){
	var resetProtoProps = ['_buffered', '_metadata', '_ppFlag', 'currentSrc', 'currentTime', 'duration', 'ended', 'networkState', 'paused', 'videoHeight', 'videoWidth', '_callMeta'];
	var len = resetProtoProps.length;
	return function(data){
		
		if(!data){return;}
		var lenI = len;
		var networkState = data.networkState;
		data.readyState = 0;
		while(--lenI){
			delete data[resetProtoProps[lenI]];
		}
		data.buffered.length = 0;
		clearInterval(data._timeInterval);
		if(networkState){
			trigger(data._elem, 'emptied');
		}
	};
})();

var setElementDimension = function(data){
	var elem = data._elem;
	var box = data.shadowElem;
	box.css({
		width: elem.style.width || $(elem).width(),
		height: elem.style.height || $(elem).height()
	});
};

var getYtDataFromElem = function(elem){
	try {
		(elem.nodeName);
	} catch(er){
		return null;
	}
	var data = webshims.data(elem, 'mediaelement');
	return (data && data.isActive == 'third') ? data : null;
};

var getYtId = function(src){
	var found;
	src = src.split('?');
	if(src[0].indexOf('youtube.com/watch') != -1 && src[1]){
		src = src[1].split('&');
		$.each(src, function(i, name){
			name = name.split('=');
			if(name[0] == 'v'){
				src = name[1];
				found = true;
				return false;
			}
		});
	} else if(src[0].indexOf('youtube.com/v/') != -1) {
		src = src[0].split('/');
		$.each(src, function(i, name){
			if(found){
				src = name;
				return false;
			}
			
			if(name == 'v'){
				found = true;
			}
		});
	}
	if(!found){
		webshims.warn('no youtube id found: '+ src);
	}
	return src;
};

var startAutoPlay = function(data){
	if(!data){return;}
	if( (data._ppFlag === undefined && ($.prop(data._elem, 'autoplay')) || !data.paused)){
		setTimeout(function(){
			if(data.isActive == 'third' && (data._ppFlag === undefined || !data.paused)){
				try {
					$(data._elem).play();
				} catch(er){}
			}
		}, 1);
	}
};

var addMediaToStopEvents = $.noop;
(function(){
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
})();

$(document).on('emptied', function(e){
	var data = getYtDataFromElem(e.target);
	startAutoPlay(data);
});
	
	
	
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
		$(elem).addClass('yt-api-active nonnative-api-active').hide().getShadowElement().show();
	} else {
		clearInterval(data._timeInterval);
		$(elem).removeClass('yt-api-active nonnative-api-active').show().getShadowElement().hide();
		shadowData.shadowElement = shadowData.shadowFocusElement = false;
	}
	$(elem).trigger('mediaelementapichange');
};


var handlePlayPauseState = function(state, data){
	data._ppFlag = true;
	if(state == 'playing'){
		handlePlayPauseState('play', data);
		if(data.readyState < 3){
			data.readyState = 3;
			trigger(data._elem, 'canplay');
		}
		$(data._elem).trigger('playing');
	}
	
	if(state == 'play' && data.paused){
		data.paused = false;
		trigger(data._elem, 'play');
	} else if(state == 'pause' && !data.paused){
		data.paused = true;
		trigger(data._elem, 'pause');
	}
};

var addYtAPI = function(mediaElm, elemId, data, ytID){
	ytAPI.done(function(){
		var handleBuffered = function(){
			var buffered, bufFac;
			if(data._metadata && data._ytAPI.getVideoLoadedFraction){
				bufFac = data._ytAPI.getVideoLoadedFraction();
				buffered = bufFac * data.duration;
				if(data._buffered !== buffered){
					data._buffered = buffered;
					data.buffered.length = 1;
					$(mediaElm).trigger('progress');
				}
				if(bufFac > 0.99){
					data.networkState = 1;
				}
				if(data.readyState < 4 && data.currentTime && (data._buffered - data.currentTime > 9 || bufFac > 0.9) ){
					data.readyState = 4;
					trigger(data._elem, 'canplaythrough');
				}
			}
		};
		var getTime = function(){
			if(data._ytAPI && data._ytAPI.getCurrentTime){
				var currentTime = data._ytAPI.getCurrentTime();
				if(data.currentTime != currentTime){
					data.currentTime = currentTime;
					$(mediaElm).trigger('timeupdate');
				}
				handleBuffered();
			}
		};
		
		var getData = function(){
			if(data.isActive == 'third' && data._ytAPI && data._ytAPI.getVolume){
				
				var volume = data._ytAPI.getVolume() / 100;
				var muted = data._ytAPI.isMuted();
				var triggerVolume;
				if(volume != data.volume){
					data.volume = volume;
					triggerVolume = true;
				}
				if(muted != data.muted){
					data.muted = muted;
					triggerVolume = true;
				}
				getTime();
				handleBuffered();
				if(triggerVolume){
					$(mediaElm).trigger('volumechange');
				}
			}
		};
		var getIntervalTime = function(){
			clearInterval(data._timeInterval);
			data._timeInterval = setInterval(function(){
				var currentTime = data._ytAPI.getCurrentTime();
				if(data.currentTime != currentTime){
					data.currentTime = currentTime;
					$(mediaElm).trigger('timeupdate');
				}
			}, 350);
		};
		data._ytAPI = new YT.Player(elemId, {
			height: '100%',
			width: '100%',
			playerVars: {
				allowfullscreen: true,
				fs: 1,
				rel: 0,
				showinfo: 0,
				autohide: 1,
				controls: $.prop(mediaElm, 'controls') ? 1:0
			},
			
			videoId: ytID,
			events: {
				'onReady': function(e){
					startAutoPlay(data);
					setTimeout(getData, 9);
					setInterval(getData, 5000);
				},
				
				'onStateChange': function(e){
					if(!e.target.getDuration){return;}
					var callMeta;
					if(!data._metadata){
						var duration = e.target.getDuration();
						if(duration){
							data._metadata = true;
							data.duration = duration;
							if(data.readyState < 1){
								data.readyState = 1;
							}
							if(data.networkState < 1){
								data.networkState = 2;
							}
							callMeta = true;
						}
					}
					
					if(callMeta){
						$(mediaElm)
							.trigger('durationchange')
							.trigger('loadedmetadata')
						;
					}
					setTimeout(getData, 9);
					if(e.data == 1){
						handlePlayPauseState('playing', data);
						getIntervalTime();
					} else if(e.data == 2){
						clearInterval(data._timeInterval);
						handlePlayPauseState('pause', data);
					} else if(e.data == 3){
						if(data.readyState > 2){
							data.readyState = 2;
						}
						data.networkState = 2;
						$(mediaElm).trigger('waiting');
					} else if(e.data === 0){
						if(data.readyState > 4){
							data.readyState = 4;
						}
						data.networkState = 1;
						clearInterval(data._timeInterval);
						$(mediaElm).trigger('ended');
					}
				}
			}
		});
		
		$(mediaElm).on('updateytdata', getData);
		
	});
};

mediaelement.createSWF = function(mediaElem, src, data){
	if(!data){
		data = webshims.data(mediaElem, 'mediaelement');
	}
	var ytID = getYtId(src.src);
	if(data){
		mediaelement.setActive(mediaElem, 'third', data);
		resetSwfProps(data);
		data.currentSrc = src.srcProp;
		ytAPI.done(function(){
			if(data._ytAPI.loadVideoById){
				data._ytAPI.loadVideoById(ytID);
			}
		});
		
		return;
	}
	var hasControls = $.prop(mediaElem, 'controls');
	var elemId = 'yt-'+ webshims.getID(mediaElem);
	var box = $('<div class="polyfill-video polyfill-mediaelement" id="wrapper-'+ elemId +'"><div id="'+ elemId +'"></div>')
		.css({
			position: 'relative',
			overflow: 'hidden'
		})
	;
	
	
	
	data = webshims.data(mediaElem, 'mediaelement', webshims.objectCreate(playerStateObj, {
		shadowElem: {
			value: box
		},
		_elem: {
			value: mediaElem
		},
		currentSrc: {
			value: src.srcProp
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
					return data._buffered;
				},
				length: 0
			}
		}
	}));
	
	
	
	setElementDimension(data);
	box.insertBefore(mediaElem);
	
	webshims.addShadowDom(mediaElem, box);
	mediaelement.setActive(mediaElem, 'third', data);
	addMediaToStopEvents(mediaElem);
	
	addYtAPI(mediaElem, elemId, data, ytID);
	$(mediaElem).on('updatemediaelementdimensions updateshadowdom', function(){
		setElementDimension(data);
	});
};

(function(){
	var triggerUpdate =  function(data){
		clearTimeout(data.updateDataTimer);
		data.updateDataTimer = setTimeout(function(){
			$(data._elem).triggerHandler('updateytdata');
		}, 9);
	};
	var descs = {};
	var mediaSup;
	var createGetProp = function(key){
		descs[key] = {
			get: function(){
				var data = getYtDataFromElem(this);
				if(data){
					return data[key];
				} else {
					return mediaSup[key].prop._supget.apply(this);
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
	
	getPropKeys.forEach(createGetProp);
	
	createGetSetProp('currentTime', function(t){
		var data = getYtDataFromElem(this);
		if(data){
			t *= 1;
			if (!isNaN(t) && data._ytAPI && data._ytAPI.seekTo) {
				data._ytAPI.seekTo(t);
				triggerUpdate(data);
			}
		} else {
			return mediaSup.currentTime.prop._supset.apply(this, arguments);
		}
	});
	
	createGetSetProp('muted', function(mute){
		var data = getYtDataFromElem(this);
		if(data){
			if (data._ytAPI && data._ytAPI.mute) {
				data._ytAPI[mute ? 'mute' : 'unMute']();
				triggerUpdate(data);
			}
			 
		} else {
			return mediaSup.muted.prop._supset.apply(this, arguments);
		}
	});
	
	createGetSetProp('volume', function(v){
		var data = getYtDataFromElem(this);
		if(data){
			v *= 100;
			if (!isNaN(v) && data._ytAPI && data._ytAPI.setVolume) {
				if(v < 0 || v > 100){
					webshims.error('volume greater or less than allowed '+ (v / 100));
				}
				data._ytAPI.setVolume(v);
				triggerUpdate(data);
			}
			 
		} else {
			return mediaSup.volume.prop._supset.apply(this, arguments);
		}
	});
	
	$.each(['play', 'pause'], function(i, name){
		var ytName = name+'Video';
		descs[name] = { 
			value: function(){
				var data = getYtDataFromElem(this);
				if(data){
					if(data._ytAPI && data._ytAPI[ytName]){
						data._ytAPI[ytName]();
						handlePlayPauseState(name, data);
					}
				} else {
					return mediaSup[name].prop._supvalue.apply(this, arguments);
				}
			} 
		};
		
	});
	mediaSup = webshims.defineNodeNameProperties('video', descs, 'prop');
})();



});
