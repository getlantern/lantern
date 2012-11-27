jQuery.webshims.register('track-ui', function($, webshims, window, document, undefined){
	"use strict";
	var options = webshims.cfg.track;
	var enterE = {type: 'enter'};
	var exitE = {type: 'exit'};
	//descriptions are not really shown, but they are inserted into the dom
	var showTracks = {subtitles: 1, captions: 1, descriptions: 1};
	var mediaelement = webshims.mediaelement;
	var usesNativeTrack =  function(){
		return !options.override && Modernizr.track;
	};
	
	var trackDisplay = {
		update: function(baseData, media){
			if(!baseData.activeCues.length){
				this.hide(baseData);
			} else {
				if(!compareArray(baseData.displayedActiveCues, baseData.activeCues)){
					baseData.displayedActiveCues = baseData.activeCues;
					if(!baseData.trackDisplay){
						baseData.trackDisplay = $('<div class="cue-display"><span class="description-cues" aria-live="assertive" /></div>').insertAfter(media);
						this.addEvents(baseData, media);
						webshims.docObserve();
					}
					
					if(baseData.hasDirtyTrackDisplay){
						media.triggerHandler('forceupdatetrackdisplay');
					}
					this.showCues(baseData);
				}
			}
		},
		showCues: function(baseData){
			var element = $('<span class="cue-wrapper" />');
			$.each(baseData.displayedActiveCues, function(i, cue){
				var id = (cue.id) ? 'id="cue-id-'+cue.id +'"' : '';
				var cueHTML = $('<span class="cue-line"><span '+ id+ ' class="cue" /></span>').find('span').html(cue.getCueAsHTML()).end();
				if(cue.track.kind == 'descriptions'){
					setTimeout(function(){
						$('span.description-cues', baseData.trackDisplay).html(cueHTML);
					}, 0);
				} else {
					element.prepend(cueHTML);
				}
			});
			$('span.cue-wrapper', baseData.trackDisplay).remove();
			baseData.trackDisplay.append(element);
		},
		addEvents: function(baseData, media){
			if(options.positionDisplay){
				var timer;
				var positionDisplay = function(_force){
					if(baseData.displayedActiveCues.length || _force === true){
						baseData.trackDisplay.css({display: 'none'});
						var uiElement = media.getShadowElement();
						var offsetElement = uiElement.offsetParent();
						var uiHeight = uiElement.innerHeight();
						var uiWidth = uiElement.innerWidth();
						var position = uiElement.position();
						var displaySize = uiHeight * uiWidth;
						baseData.trackDisplay.css({
							left: position.left,
							width: uiWidth,
							height: uiHeight - 45,
							top: position.top,
							display: 'block'
						});
						
						baseData.trackDisplay.css('fontSize', Math.max(Math.round(uiHeight / 30), 7));
						baseData.hasDirtyTrackDisplay = false;
					} else {
						baseData.hasDirtyTrackDisplay = true;
					}
				};
				var delayed = function(e){
					clearTimeout(timer);
					timer = setTimeout(positionDisplay, 0);
				};
				var forceUpdate = function(){
					positionDisplay(true);
				};
				media.on('updateshadowdom playerdimensionchange mediaelementapichange updatetrackdisplay updatemediaelementdimensions swfstageresize', delayed);
				media.on('forceupdatetrackdisplay', forceUpdate);
				forceUpdate();
			}
		},
		hide: function(baseData){
			if(baseData.trackDisplay && baseData.displayedActiveCues.length){
				baseData.displayedActiveCues = [];
				$('span.cue-wrapper', baseData.trackDisplay).remove();
				$('span.description-cues', baseData.trackDisplay).empty();
			}
		}
	};
	
	function compareArray(a1, a2){
		var ret = true;
		var i = 0;
		var len = a1.length;
		if(len != a2.length){
			ret = false;
		} else {
			for(; i < len; i++){
				if(a1[i] != a2[i]){
					ret = false;
					break;
				}
			}
		}
		return ret;
	}
	
	$.extend($.event.customEvent, {
		updatetrackdisplay: true,
		forceupdatetrackdisplay: true
	});
	
	mediaelement.trackDisplay = trackDisplay;
	
	if(!mediaelement.createCueList){
		
		var cueListProto = {
			getCueById: function(id){
				var cue = null;
				for(var i = 0, len = this.length; i < len; i++){
					if(this[i].id === id){
						cue = this[i];
						break;
					}
				}
				return cue;
			}
		};
		
		mediaelement.createCueList = function(){
			return $.extend([], cueListProto);
		};
	}
	
	mediaelement.getActiveCue = function(track, media, time, baseData){
		if(!track._lastFoundCue){
			track._lastFoundCue = {index: 0, time: 0};
		}
		
		if(Modernizr.track && !options.override && !track._shimActiveCues){
			track._shimActiveCues = mediaelement.createCueList();
		}
		
		var i = 0;
		var len;
		var cue;
		
		for(; i < track.shimActiveCues.length; i++){
			cue = track.shimActiveCues[i];
			if(cue.startTime > time || cue.endTime < time){
				track.shimActiveCues.splice(i, 1);
				i--;
				if(cue.pauseOnExit){
					$(media).pause();
				}
				$(track).triggerHandler('cuechange');
				$(cue).triggerHandler('exit');
			} else if(track.mode == 'showing' && showTracks[track.kind] && $.inArray(cue, baseData.activeCues) == -1){
				baseData.activeCues.push(cue);
			}
		}
		

		len = track.cues.length;
		i = track._lastFoundCue.time < time ? track._lastFoundCue.index : 0;
		
		for(; i < len; i++){
			cue = track.cues[i];
			
			if(cue.startTime <= time && cue.endTime >= time && $.inArray(cue, track.shimActiveCues) == -1){
				track.shimActiveCues.push(cue);
				if(track.mode == 'showing' && showTracks[track.kind]){
					baseData.activeCues.push(cue);
				}
				$(track).triggerHandler('cuechange');
				$(cue).triggerHandler('enter');
				
				track._lastFoundCue.time = time;
				track._lastFoundCue.index = i;
				
				
			}
			if(cue.startTime > time){
				break;
			}
		}
	};
	
	if(usesNativeTrack()){
		(function(){
			var block;
			var triggerDisplayUpdate = function(elem){
				setTimeout(function(){
					block = true;
					$(elem).triggerHandler('updatetrackdisplay');
					block = false;
				}, 9);
			};
			
			var createUpdateFn = function(nodeName, prop, type){
				var superType = '_sup'+type;
				var desc = {prop: {}};
				var superDesc;
				desc.prop[type] = function(){
					if(!block && usesNativeTrack()){
						triggerDisplayUpdate($(this).closest('audio, video'));
					}
					return superDesc.prop[superType].apply(this, arguments);
				};
				superDesc = webshims.defineNodeNameProperty(nodeName, prop, desc);
			};
			
			createUpdateFn('track', 'track', 'get');
			
			['audio', 'video'].forEach(function(nodeName){
				createUpdateFn(nodeName, 'textTracks', 'get');
				createUpdateFn('nodeName', 'addTextTrack', 'value');
			});
		})();
	}
	
	webshims.addReady(function(context, insertedElement){
		$('video, audio', context)
			.add(insertedElement.filter('video, audio'))
			.each(function(){
				var elem = $(this);
				
				var getDisplayCues = function(e){
					var track;
					var time;
					
					if(!trackList || !baseData){
						trackList = elem.prop('textTracks');
						baseData = webshims.data(elem[0], 'mediaelementBase') || webshims.data(elem[0], 'mediaelementBase', {});
						if(!baseData.displayedActiveCues){
							baseData.displayedActiveCues = [];
						}
					}
					
					if (!trackList){return;}
					time = elem.prop('currentTime');
					
					if(!time && time !== 0){return;}
					baseData.activeCues = [];
					for(var i = 0, len = trackList.length; i < len; i++){
						track = trackList[i];
						if(track.mode != 'disabled' && track.cues && track.cues.length){
							mediaelement.getActiveCue(track, elem, time, baseData);
						}
					}
					
					trackDisplay.update(baseData, elem);
					
				};
				var onUpdate = function(e){
					clearTimeout(updateTimer);
					if(e && e.type == 'timeupdate'){
						getDisplayCues();
						setTimeout(onUpdate, 90);
					} else {
						updateTimer = setTimeout(getDisplayCues, 9);
					}
				};
				
				var addTrackView = function(){
					
					elem
						.off('.trackview')
						.on('play.trackview timeupdate.trackview updatetrackdisplay.trackview', onUpdate)
					;
				};
				var baseData, trackList, updateTimer;
				
				if(!usesNativeTrack()){
					addTrackView();
				} else {
					elem.on('mediaelementapichange trackapichange', function(){
						if(!usesNativeTrack() || elem.is('.nonnative-api-active')){
							addTrackView();
						} else {
							trackList = elem.prop('textTracks');
							baseData = webshims.data(elem[0], 'mediaelementBase') || webshims.data(elem[0], 'mediaelementBase', {});
							
							$.each(trackList, function(i, track){
								if(track._shimActiveCues){
									delete track._shimActiveCues;
								}
							});
							trackDisplay.hide(baseData);
							elem.unbind('.trackview');
						}
					});
				}
			})
		;
	});
});