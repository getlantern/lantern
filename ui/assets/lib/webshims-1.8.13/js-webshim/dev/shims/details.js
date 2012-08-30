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
			.bind('focus.summaryPolyfill', function(){
				$(this).addClass('summary-has-focus');
			})
			.bind('blur.summaryPolyfill', function(){
				$(this).removeClass('summary-has-focus');
			})
			.bind('mouseenter.summaryPolyfill', function(){
				$(this).addClass('summary-has-hover');
			})
			.bind('mouseleave.summaryPolyfill', function(){
				$(this).removeClass('summary-has-hover');
			})
			.bind('click.summaryPolyfill', function(e){
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
			})
			.bind('keydown.summaryPolyfill', function(e){
				if( (e.keyCode == 13 || e.keyCode == 32) && !e.isDefaultPrevented()){
					stopNativeClickTest = true;
					e.preventDefault();
					$(this).trigger('click');
					stopNativeClickTest = false;
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
