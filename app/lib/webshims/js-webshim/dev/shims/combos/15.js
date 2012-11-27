(function($){
	if(navigator.geolocation){return;}
	var domWrite = function(){
			setTimeout(function(){
				throw('document.write is overwritten by geolocation shim. This method is incompatible with this plugin');
			}, 1);
		},
		id = 0
	;
	var geoOpts = $.webshims.cfg.geolocation.options || {};
	navigator.geolocation = (function(){
		var pos;
		var api = {
			getCurrentPosition: function(success, error, opts){
				var locationAPIs = 2,
					errorTimer,
					googleTimer,
					calledEnd,
					endCallback = function(){
						if(calledEnd){return;}
						if(pos){
							calledEnd = true;
							success($.extend({timestamp: new Date().getTime()}, pos));
							resetCallback();
							if(window.JSON && window.sessionStorage){
								try{
									sessionStorage.setItem('storedGeolocationData654321', JSON.stringify(pos));
								} catch(e){}
							}
						} else if(error && !locationAPIs) {
							calledEnd = true;
							resetCallback();
							error({ code: 2, message: "POSITION_UNAVAILABLE"});
						}
					},
					googleCallback = function(){
						locationAPIs--;
						getGoogleCoords();
						endCallback();
					},
					resetCallback = function(){
						$(document).unbind('google-loader', resetCallback);
						clearTimeout(googleTimer);
						clearTimeout(errorTimer);
					},
					getGoogleCoords = function(){
						if(pos || !window.google || !google.loader || !google.loader.ClientLocation){return false;}
						var cl = google.loader.ClientLocation;
			            pos = {
							coords: {
								latitude: cl.latitude,
				                longitude: cl.longitude,
				                altitude: null,
				                accuracy: 43000,
				                altitudeAccuracy: null,
				                heading: parseInt('NaN', 10),
				                velocity: null
							},
			                //extension similiar to FF implementation
							address: $.extend({streetNumber: '', street: '', premises: '', county: '', postalCode: ''}, cl.address)
			            };
						return true;
					},
					getInitCoords = function(){
						if(pos){return;}
						getGoogleCoords();
						if(pos || !window.JSON || !window.sessionStorage){return;}
						try{
							pos = sessionStorage.getItem('storedGeolocationData654321');
							pos = (pos) ? JSON.parse(pos) : false;
							if(!pos.coords){pos = false;} 
						} catch(e){
							pos = false;
						}
					}
				;
				
				getInitCoords();
				
				if(!pos){
					if(geoOpts.confirmText && !confirm(geoOpts.confirmText.replace('{location}', location.hostname))){
						if(error){
							error({ code: 1, message: "PERMISSION_DENIED"});
						}
						return;
					}
					$.ajax({
						url: 'http://freegeoip.net/json/',
						dataType: 'jsonp',
						cache: true,
						jsonp: 'callback',
						success: function(data){
							locationAPIs--;
							if(!data){return;}
							pos = pos || {
								coords: {
									latitude: data.latitude,
					                longitude: data.longitude,
					                altitude: null,
					                accuracy: 43000,
					                altitudeAccuracy: null,
					                heading: parseInt('NaN', 10),
					                velocity: null
								},
				                //extension similiar to FF implementation
								address: {
									city: data.city,
									country: data.country_name,
									countryCode: data.country_code,
									county: "",
									postalCode: data.zipcode,
									premises: "",
									region: data.region_name,
									street: "",
									streetNumber: ""
								}
				            };
							endCallback();
						},
						error: function(){
							locationAPIs--;
							endCallback();
						}
					});
					clearTimeout(googleTimer);
					if (!window.google || !window.google.loader) {
						googleTimer = setTimeout(function(){
							//destroys document.write!!!
							if (geoOpts.destroyWrite) {
								document.write = domWrite;
								document.writeln = domWrite;
							}
							$(document).one('google-loader', googleCallback);
							$.webshims.loader.loadScript('http://www.google.com/jsapi', false, 'google-loader');
						}, 800);
					} else {
						locationAPIs--;
					}
				} else {
					setTimeout(endCallback, 1);
					return;
				}
				if(opts && opts.timeout){
					errorTimer = setTimeout(function(){
						resetCallback();
						if(error) {
							error({ code: 3, message: "TIMEOUT"});
						}
					}, opts.timeout);
				} else {
					errorTimer = setTimeout(function(){
						locationAPIs = 0;
						endCallback();
					}, 10000);
				}
			},
			clearWatch: $.noop
		};
		api.watchPosition = function(a, b, c){
			api.getCurrentPosition(a, b, c);
			id++;
			return id;
		};
		return api;
	})();
	
	$.webshims.isReady('geolocation', true);
})(jQuery);

jQuery.webshims.register('details', function($, webshims, window, doc, undefined, options){
	var isInterActiveSummary = function(summary){
		var details = $(summary).parent('details');
		if(details[0] && details.children(':first').get(0) === summary){
			return details;
		}
	};
	
	var bindDetailsSummary = function(summary, details){
		summary = $(summary);
		details = $(details);
		var oldSummary = $.data(details[0], 'summaryElement');
		$.data(summary[0], 'detailsElement', details);
		if(!oldSummary || summary[0] !== oldSummary[0]){
			if(oldSummary){
				if(oldSummary.hasClass('fallback-summary')){
					oldSummary.remove();
				} else {
					oldSummary
						.unbind('.summaryPolyfill')
						.removeData('detailsElement')
						.removeAttr('role')
						.removeAttr('tabindex')
						.removeAttr('aria-expanded')
						.removeClass('summary-button')
						.find('span.details-open-indicator')
						.remove()
					;
				}
			}
			$.data(details[0], 'summaryElement', summary);
			details.prop('open', details.prop('open'));
		}
	};
	var getSummary = function(details){
		var summary = $.data(details, 'summaryElement');
		if(!summary){
			summary = $('> summary:first-child', details);
			if(!summary[0]){
				$(details).prependPolyfill('<summary class="fallback-summary">'+ options.text +'</summary>');
				summary = $.data(details, 'summaryElement');
			} else {
				bindDetailsSummary(summary, details);
			}
		}
		return summary;
	};
	
//	var isOriginalPrevented = function(e){
//		var src = e.originalEvent;
//		if(!src){return e.isDefaultPrevented();}
//		
//		return src.defaultPrevented || src.returnValue === false ||
//			src.getPreventDefault && src.getPreventDefault();
//	};
	
	webshims.createElement('summary', function(){
		var details = isInterActiveSummary(this);
		if(!details || $.data(this, 'detailsElement')){return;}
		var timer;
		var stopNativeClickTest;
		var tabindex = $.attr(this, 'tabIndex') || '0';
		bindDetailsSummary(this, details);
		$(this)
			.on({
				'focus.summaryPolyfill': function(){
					$(this).addClass('summary-has-focus');
				},
				'blur.summaryPolyfill': function(){
					$(this).removeClass('summary-has-focus');
				},
				'mouseenter.summaryPolyfill': function(){
					$(this).addClass('summary-has-hover');
				},
				'mouseleave.summaryPolyfill': function(){
					$(this).removeClass('summary-has-hover');
				},
				'click.summaryPolyfill': function(e){
					var details = isInterActiveSummary(this);
					if(details){
						if(!stopNativeClickTest && e.originalEvent){
							stopNativeClickTest = true;
							e.stopImmediatePropagation();
							e.preventDefault();
							$(this).trigger('click');
							stopNativeClickTest = false;
							return false;
						} else {
							clearTimeout(timer); 
							
							timer = setTimeout(function(){
								if(!e.isDefaultPrevented()){
									details.prop('open', !details.prop('open'));
								}
							}, 0);
						}
					}
				},
				'keydown.summaryPolyfill': function(e){
					if( (e.keyCode == 13 || e.keyCode == 32) && !e.isDefaultPrevented()){
						stopNativeClickTest = true;
						e.preventDefault();
						$(this).trigger('click');
						stopNativeClickTest = false;
					}
				}
			})
			.attr({tabindex: tabindex, role: 'button'})
			.prepend('<span class="details-open-indicator" />')
		;
		webshims.moveToFirstEvent(this, 'click');
	});
	
	var initDetails;
	webshims.defineNodeNamesBooleanProperty('details', 'open', function(val){
		var summary = $($.data(this, 'summaryElement'));
		if(!summary){return;}
		var action = (val) ? 'removeClass' : 'addClass';
		var details = $(this);
		if (!initDetails && options.animate){
			details.stop().css({width: '', height: ''});
			var start = {
				width: details.width(),
				height: details.height()
			};
		}
		summary.attr('aria-expanded', ''+val);
		details[action]('closed-details-summary').children().not(summary[0])[action]('closed-details-child');
		if(!initDetails && options.animate){
			var end = {
				width: details.width(),
				height: details.height()
			};
			details.css(start).animate(end, {
				complete: function(){
					$(this).css({width: '', height: ''});
				}
			});
		}
		
	});
	webshims.createElement('details', function(){
		initDetails = true;
		var summary = getSummary(this);
		$.prop(this, 'open', $.prop(this, 'open'));
		initDetails = false;
	});
});
