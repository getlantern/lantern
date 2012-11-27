(function($){
	"use strict";
	var id = 0;
	
	
	var rangeProto = {
		_create: function(){
			id++;
			this.id = 'range'+id;
			this.thumb = $('<span class="ws-range-thumb" />');
			this.element.addClass('ws-range').html(this.thumb);
			this.updateMetrics();
			this.addDrag();
		},
		addDrag: function(){
			var that = this;
			var o = this.options;
			
			var remove = function(){
				$(document).off('mousemove', move);
			};
			var move = function(e){
				var nl = l + e.pageX - x;
				if(nl < 0 && l > 0){
					nl = 0;
				} else if(nl > that.maxLeft && l < that.maxLeft) {
					nl = that.maxLeft;
				}
				if(nl >= 0 && nl <= that.maxLeft){
					x = e.pageX;
					l = nl;
					that.thumb.css({left: l});
				}
			};
			var x, l;
			this.thumb.on({
				mousedown: function(e){
					if(!o.readOnly && !o.disabled){
						x = e.pageX;
						l = parseFloat(that.thumb.css('left'), 10);
						$(document).on({
							mouseup: remove,
							mousemove: move
						});
					}
				}
			});
		},
		updateMetrics: function(){
			this.rangeWidth = this.element.innerWidth();
			this.thumbWidth = this.thumb.outerWidth();
			this.maxLeft = this.rangeWidth - this.thumbWidth;
		}
	};
	
	$.fn.rangeUI = function(opts){
		return this.each(function(){
			$.webshims.objectCreate(rangeProto, {
				element: {
					value: $(this)
				}
			}, opts || {});
		});
	};
	console.log('range-ui')
})(jQuery);
