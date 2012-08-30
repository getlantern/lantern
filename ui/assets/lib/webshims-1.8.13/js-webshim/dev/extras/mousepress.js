/*
 * simple helper for a mousepress event
 * used by webshims improving spinbutton controls for input[type=time], input[type=number]...
 * 
 * $(element).bind('mousepress', function(){
 * 	//repeatedly called after mousedown, till mouseleave/mouseup
 * });
 */
(function($){
	var removeTimer = function(elem, full){
		var timer = elem.data('mousepresstimer');
		if(timer){
			clearTimeout(timer);
		}
		if(full){
			elem.unbind('mouseup.mousepressext mouseleave.mousepressext');
		}
		elem = null;
	};
	$.event.special.mousepress = {
		setup: function(){
			var timer;
			$(this).bind('mousedown.mousepressext', function(e){
				var elem = $(this);
				
				var startIntervall = function(delay){
					var steps = 0;
					removeTimer(elem);
					elem.data('mousepresstimer', setInterval(function(){
						$.event.special.mousepress.handler(elem[0], e);
						steps++;
						if(steps > 3 && delay > 45){
							startIntervall(delay - 40);
						}
					}, delay));
				};
				var target = $(e.target).trigger('mousepressstart', [e]);
				
				removeTimer(elem);
				elem.data('mousepresstimer', setTimeout(function(){
					startIntervall(180);
				}, 200));
				
				elem.bind('mouseup.mousepressext mouseleave.mousepressext', function(e){
					removeTimer(elem, true);
					target.trigger('mousepressend', [e]);
					elem = null;
					target = null;
				});
			});
		},
		teardown: function(){
			removeTimer($(this).unbind('.mousepressext'), true);
		},
		handler: function(elem, e){
	         return $.event.handle.call(elem, {type: 'mousepress', target: e.target, pageX: e.pageX, pageY: e.pageY});
		}
	};
	
})(jQuery);
