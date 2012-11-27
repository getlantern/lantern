/* number-date-ui */
/* https://github.com/aFarkas/webshim/issues#issue/23 */
jQuery.webshims.register('form-number-date-ui', function($, webshims, window, document, undefined, options){
	"use strict";
	
	var triggerInlineForm = webshims.triggerInlineForm;
	var modernizrInputTypes = Modernizr.inputtypes;
	var adjustInputWithBtn = (function(){
		var fns = {"padding-box": "innerWidth", "border-box": "outerWidth", "content-box": "width"};
		var boxSizing = Modernizr.prefixed && Modernizr.prefixed("boxSizing");
		if($.browser.msie && webshims.browserVersion < 8){
			boxSizing = false;
		}
		var getWidth = function(input){
			var widthFn = "width";
			if(boxSizing){
				widthFn = fns[input.css(boxSizing)] || widthFn;
			}
			
			return {
				w: input[widthFn](),
				add: widthFn == "width"
			};
			
		};
		
		
		return function(input, button){
			var inputDim = getWidth(input);
			if(!inputDim.w){return;}
			var controlDim = {
				mL: (parseInt(button.css('marginLeft'), 10) || 0),
				w: button.outerWidth()
			};
			inputDim.mR = (parseInt(input.css('marginRight'), 10) || 0);
			if(inputDim.mR){
				input.css('marginRight', 0);
			}
			//is inside
			if( controlDim.mL <= (controlDim.w * -1) ){
				button.css('marginRight',  Math.floor(Math.abs(controlDim.w + controlDim.mL - 0.1) + inputDim.mR));
				input.css('paddingRight', (parseInt(input.css('paddingRight'), 10) || 0) + Math.abs(controlDim.mL));
				if(inputDim.add){
					input.css('width', Math.floor(inputDim.w + controlDim.mL - (boxSizing ? 0.1 : 0.6)));
				}
			} else {
				button.css('marginRight', inputDim.mR);
				input.css('width',  Math.floor(inputDim.w - controlDim.mL - controlDim.w - (boxSizing ? 0.2 : 0.6)));
			}
		};
	})();
	
	
	var defaultDatepicker = {};
	var labelID = 0;
	var emptyJ = $([]);
	var isCheckValidity;
	var replaceInputUI = function(context, elem){
		$('input', context).add(elem.filter('input')).each(function(){
			var type = $.prop(this, 'type');
			if(replaceInputUI[type]  && !webshims.data(this, 'shadowData')){
				replaceInputUI[type]($(this));
			}
		});
	};
	//set date is extremly slow in IE so we do it lazy
	var lazySetDate = function(elem, date){
		if(!options.lazyDate){
			elem.datepicker('setDate', date);
			return;
		}
		var timer = $.data(elem[0], 'setDateLazyTimer');
		if(timer){
			clearTimeout(timer);
		}
		$.data(elem[0], 'setDateLazyTimer', setTimeout(function(){
			elem.datepicker('setDate', date);
			$.removeData(elem[0], 'setDateLazyTimer');
			elem = null;
		}, 0));
	};
	
	
	var copyAttrs = {
		tabindex: 1,
		tabIndex: 1,
		title: 1,
		"aria-required": 1,
		"aria-invalid": 1
	};
	if(!options.copyAttrs){
		options.copyAttrs = {};
	}
	
	webshims.extendUNDEFProp(options.copyAttrs, copyAttrs);
	
	var getDimensions = function(orig){
		return (options.calculateWidth) ? 
			{
				css: {
					marginRight: orig.css('marginRight'),
					marginLeft: orig.css('marginLeft')
				},
				outerWidth: orig.outerWidth()
				
			} :
			{}
		;
	};
	var focusAttrs = copyAttrs;
	
	replaceInputUI.common = function(orig, shim, methods){
		if(Modernizr.formvalidation){
			orig.on('firstinvalid', function(e){
				if(!webshims.fromSubmit && isCheckValidity){return;}
				orig.off('invalid.replacedwidgetbubble').on('invalid.replacedwidgetbubble', function(evt){
					if(!e.isInvalidUIPrevented() && !evt.isDefaultPrevented()){
						webshims.validityAlert.showFor( e.target );
						e.preventDefault();
						evt.preventDefault();
					}
					orig.off('invalid.replacedwidgetbubble');
				});
			});
		}
		var i, prop;
		var focusElement = $('input, span.ui-slider-handle', shim);
		var attrs = orig[0].attributes;
		for(i in options.copyAttrs){
			if ((prop = attrs[i]) && prop.specified) {
				if(focusAttrs[i] && focusElement[0]){
					focusElement.attr(i, prop.nodeValue);
				} else {
					shim[0].setAttribute(i, prop.nodeValue);
				}
			}
		}
		
		var id = orig.attr('id'),
			label =  (id) ? $('label[for="'+ id +'"]', orig[0].form) : emptyJ
		;
		
		
		
		shim.addClass(orig[0].className);
		webshims.addShadowDom(orig, shim, {
			data: methods || {},
			shadowFocusElement: $('input.input-datetime-local-date, span.ui-slider-handle', shim)[0],
			shadowChilds: focusElement
		});
		
		orig.after(shim);
		
		if(orig[0].form){
			$(orig[0].form).on('reset', function(e){
				if(e.originalEvent && !e.isDefaultPrevented()){
					setTimeout(function(){orig.prop( 'value', orig.prop('value') );}, 0);
				}
			});
		}
		
		if(label[0]){
			shim.getShadowFocusElement().attr('aria-labelledby', webshims.getID(label));
			label.on('click', function(){
				orig.getShadowFocusElement().focus();
				return false;
			});
		}
	};
	
	if(Modernizr.formvalidation){
		['input', 'form'].forEach(function(name){
			var desc = webshims.defineNodeNameProperty(name, 'checkValidity', {
				prop: {
					value: function(){
						isCheckValidity = true;
						var ret = desc.prop._supvalue.apply(this, arguments);
						isCheckValidity = false;
						return ret;
					}
				}
			});
		});
	}
	//date and datetime-local implement if we have to replace
	if(!modernizrInputTypes['date'] /*||!modernizrInputTypes['datetime-local']*/ || options.replaceUI){
		
		var datetimeFactor = {
			trigger: [0.595,0.395],
			normal: [0.565,0.425]
		};
		var subPixelCorrect = (!$.browser.msie || webshims.browserVersion > 6) ? 0 : 0.45;
		
		var configureDatePicker = function(elem, datePicker, change, _wrapper){
			var stopFocusout;
			var focusedOut;
			var resetFocusHandler = function(){
				data.dpDiv.unbind('mousedown.webshimsmousedownhandler');
				stopFocusout = false;
				focusedOut = false;
			};
			var data = datePicker
				.on({
					focusin: function(){
						resetFocusHandler();
						data.dpDiv.unbind('mousedown.webshimsmousedownhandler').bind('mousedown.webshimsmousedownhandler', function(){
							stopFocusout = true;
						});
					},
					'focusout blur': function(e){
						if(stopFocusout){
							focusedOut = true;
							e.stopImmediatePropagation();
						}
					}
				})
				.datepicker($.extend({
					onClose: function(){
						if(focusedOut && datePicker.not(':focus')){
							resetFocusHandler();
							datePicker.trigger('focusout');
							datePicker.triggerHandler('blur');
						} else {
							resetFocusHandler();
						}
					}
				}, defaultDatepicker, options.datepicker, elem.data('datepicker')))
				.on('change', change)
				.data('datepicker')
			;
			data.dpDiv.addClass('input-date-datepicker-control');
			
			if(_wrapper){
				webshims.triggerDomUpdate(_wrapper[0]);	
			}
			['disabled', 'min', 'max', 'value', 'step', 'data-placeholder'].forEach(function(name){
				var fn = 'data-placeholder' ? 'attr' : 'prop';
				var val = elem[fn](name);
				if(val){
					elem[fn](name, val);
				}
			});
			
			return data;
		};
		
//		replaceInputUI['datetime-local'] = function(elem){
//			if(!$.fn.datepicker){return;}
//			
//			var date = $('<span role="group" class="input-datetime-local"><input type="text" class="input-datetime-local-date" /><input type="time" class="input-datetime-local-time" /></span>'),
//				attr  = this.common(elem, date, replaceInputUI['datetime-local'].attrs),
//				datePicker = $('input.input-datetime-local-date', date),
//				datePickerChange = function(e){
//						
//						var value = datePicker.prop('value') || '', 
//							timeVal = ''
//						;
//						if(options.lazyDate){
//							var timer = $.data(datePicker[0], 'setDateLazyTimer');
//							if(timer){
//								clearTimeout(timer);
//								$.removeData(datePicker[0], 'setDateLazyTimer');
//							}
//						}
//						
//						if(value){
//							timeVal = $('input.input-datetime-local-time', date).prop('value') || '00:00';
//							try {
//								value = $.datepicker.parseDate(datePicker.datepicker('option', 'dateFormat'), value);
//								value = (value) ? $.datepicker.formatDate('yy-mm-dd', value) : datePicker.prop('value');
//							} catch (e) {value = datePicker.prop('value');}
//						} 
//						value = (!value && !timeVal) ? '' : value + 'T' + timeVal;
//						replaceInputUI['datetime-local'].blockAttr = true;
//						elem.prop('value', value);
//						replaceInputUI['datetime-local'].blockAttr = false;
//						e.stopImmediatePropagation();
//						triggerInlineForm(elem[0], 'input');
//						triggerInlineForm(elem[0], 'change');
//					},
//				data = configureDatePicker(elem, datePicker, datePickerChange, date)
//			;
//			
//			
//			$('input.input-datetime-local-time', date).bind('change', function(e){
//				var timeVal = $.prop(this, 'value');
//				var val = ['', ''];
//				if(timeVal){
//					val = elem.prop('value').split('T');
//					if((val.length < 2 || !val[0])){
//						val[0] = $.datepicker.formatDate('yy-mm-dd', new Date());
//					}
//					val[1] = timeVal;
//					
//					if (timeVal) {
//						try {
//							datePicker.prop('value', $.datepicker.formatDate(datePicker.datepicker('option', 'dateFormat'), $.datepicker.parseDate('yy-mm-dd', val[0])));
//						} catch (e) {}
//					}
//				}
//				val = (!val[0] && !val[1]) ? '' : val.join('T');
//				replaceInputUI['datetime-local'].blockAttr = true;
//				elem.prop('value', val);
//				replaceInputUI['datetime-local'].blockAttr = false;
//				e.stopImmediatePropagation();
//				triggerInlineForm(elem[0], 'input');
//				triggerInlineForm(elem[0], 'change');
//			});
//			
//			
//			
//			date.attr('aria-labelledby', attr.label.attr('id'));
//			attr.label.bind('click', function(){
//				datePicker.focus();
//				return false;
//			});
//			
//			if(attr.css){
//				date.css(attr.css);
//				if(attr.outerWidth){
//					date.outerWidth(attr.outerWidth);
//					var width = date.width();
//					var widthFac = (data.trigger[0]) ? datetimeFactor.trigger : datetimeFactor.normal;
//					datePicker.outerWidth(Math.floor((width * widthFac[0]) - subPixelCorrect), true);
//					$('input.input-datetime-local-time', date).outerWidth(Math.floor((width * widthFac[1]) - subPixelCorrect), true);
//					if(data.trigger[0]){
//						adjustInputWithBtn(datePicker, data.trigger);
//					}
//				}
//			}
//			
//			
//		};
//		
//		replaceInputUI['datetime-local'].attrs = {
//			disabled: function(orig, shim, value){
//				$('input.input-datetime-local-date', shim).prop('disabled', !!value);
//				$('input.input-datetime-local-time', shim).prop('disabled', !!value);
//			},
//			step: function(orig, shim, value){
//				$('input.input-datetime-local-time', shim).attr('step', value);
//			},
//			//ToDo: use min also on time
//			min: function(orig, shim, value){
//				if(value){
//					value = (value.split) ? value.split('T') : [];
//					try {
//						value = $.datepicker.parseDate('yy-mm-dd', value[0]);
//					} catch(e){value = false;}
//				}
//				if(!value){
//					value = null;
//				}
//				$('input.input-datetime-local-date', shim).datepicker('option', 'minDate', value);
//				
//			},
//			//ToDo: use max also on time
//			max: function(orig, shim, value){
//				if(value){
//					value = (value.split) ? value.split('T') : [];
//					try {
//						value = $.datepicker.parseDate('yy-mm-dd', value[0]);
//					} catch(e){value = false;}
//				}
//				if(!value){
//					value = null;
//				}
//				$('input.input-datetime-local-date', shim).datepicker('option', 'maxDate', value);
//			},
//			value: function(orig, shim, value){
//				var dateValue;
//				if(value){
//					value = (value.split) ? value.split('T') : [];
//					try {
//						dateValue = $.datepicker.parseDate('yy-mm-dd', value[0]);
//					} catch(e){dateValue = false;}
//				}
//				if(dateValue){
//					if(!replaceInputUI['datetime-local'].blockAttr){
//						lazySetDate($('input.input-datetime-local-date', shim), dateValue);
//					}
//					$('input.input-datetime-local-time', shim).prop('value', value[1] || '00:00');
//				} else {
//					$('input.input-datetime-local-date', shim).prop('value', value[0] || '');
//					$('input.input-datetime-local-time', shim).prop('value', value[1] || '');
//				}
//					
//				
//			}
//		};
			
		
		replaceInputUI.date = function(elem){
			
			if(!$.fn.datepicker){return;}
			var date = $('<input class="input-date" type="text" />'),
				
				change = function(e){
					
					replaceInputUI.date.blockAttr = true;
					var value;
					if(options.lazyDate){
						var timer = $.data(date[0], 'setDateLazyTimer');
						if(timer){
							clearTimeout(timer);
							$.removeData(date[0], 'setDateLazyTimer');
						}
					}
					try {
						value = $.datepicker.parseDate(date.datepicker('option', 'dateFormat'), date.prop('value') );
						value = (value) ? $.datepicker.formatDate( 'yy-mm-dd', value ) : date.prop('value');
					} catch(e){
						value = date.prop('value');
					}
					elem.prop('value', value);
					replaceInputUI.date.blockAttr = false;
					e.stopImmediatePropagation();
					triggerInlineForm(elem[0], 'input');
					triggerInlineForm(elem[0], 'change');
				},
				data
				
			;
			
			this.common(elem, date, replaceInputUI.date.attrs);
			
			data = configureDatePicker(elem, date, change);
			
			$(elem)
				.on('updateshadowdom', function(){
					if (data.trigger[0]) {
						elem.css({display: ''});
						if(elem[0].offsetWidth || elem[0].offsetHeight){
							var attr = getDimensions(elem);
							if (attr.css) {
								date.css(attr.css);
								if (attr.outerWidth) {
									date.outerWidth(attr.outerWidth);
								}
								adjustInputWithBtn(date, data.trigger);
							}
						}
					}
					elem.css({display: 'none'});
				})
				.triggerHandler('updateshadowdom')
			;
			if (data.trigger[0]) {
				setTimeout(function(){
					webshims.ready('WINDOWLOAD', function(){
						$(elem).triggerHandler('updateshadowdom');
					});
				}, 9);
			}
			
		};
		
		
		replaceInputUI.date.attrs = {
			disabled: function(orig, shim, value){
				$.prop(shim, 'disabled', !!value);
			},
			min: function(orig, shim, value){
				try {
					value = $.datepicker.parseDate('yy-mm-dd', value);
				} catch(e){value = false;}
				if(value){
					$(shim).datepicker('option', 'minDate', value);
				}
			},
			max: function(orig, shim, value){
				try {
					value = $.datepicker.parseDate('yy-mm-dd', value);
				} catch(e){value = false;}
				if(value){
					$(shim).datepicker('option', 'maxDate', value);
				}
			},
			'data-placeholder': function(orig, shim, value){
				var hintValue = (value || '').split('-');
				var dateFormat;
				if(hintValue.length == 3){
					value = $(shim).datepicker('option','dateFormat').replace('yy', hintValue[0]).replace('mm', hintValue[1]).replace('dd', hintValue[2]);
				} 
				$.prop(shim, 'placeholder', value);
			},
			value: function(orig, shim, value){
				if(!replaceInputUI.date.blockAttr){
					try {
						var dateValue = $.datepicker.parseDate('yy-mm-dd', value);
					} catch(e){var dateValue = false;}
					
					if(dateValue){
						lazySetDate($(shim), dateValue);
					} else {
						$.prop(shim, 'value', value);
					}
				}
			}
		};
	}
	if (!modernizrInputTypes.range || options.replaceUI) {
		replaceInputUI.range = function(elem){
			if(!$.fn.slider){return;}
			var range = $('<span class="input-range"><span class="ui-slider-handle" role="slider" tabindex="0" /></span>'),
				change = function(e, ui){
					if(e.originalEvent){
						replaceInputUI.range.blockAttr = true;
						elem.prop('value', ui.value);
						replaceInputUI.range.blockAttr = false;
						triggerInlineForm(elem[0], 'input');
					}
				}
			;
			
			this.common(elem, range, replaceInputUI.range.attrs);
			
			
			elem
				.on('updateshadowdom', function(){
					elem.css({display: ''});
					if (elem[0].offsetWidth || elem[0].offsetHeight) {
						var attr = getDimensions(elem);
						if (attr.css) {
							range.css(attr.css);
							if (attr.outerWidth) {
								range.outerWidth(attr.outerWidth);
							}
						}
					}
					elem.css({display: 'none'});
				})
				.triggerHandler('updateshadowdom')
			;
			
			
			range.slider($.extend(true, {}, options.slider, elem.data('slider')))
				.on({
					slide: change,
					slidechange: function(e){
						if(e.originalEvent){
							triggerInlineForm(elem[0], 'change');
						}
					}
				})
			;
			
			['disabled', 'min', 'max', 'step', 'value'].forEach(function(name){
				var val = elem.prop(name);
				var shadow;
				if(name == 'value' && !val){
					
					shadow = elem.getShadowElement();
					if(shadow){
						val = ($(shadow).slider('option', 'max') - $(shadow).slider('option', 'min')) / 2;
					}
				}
				if(val != null){
					elem.prop(name, val);
				}
			});
		};
		
		replaceInputUI.range.attrs = {
			disabled: function(orig, shim, value){
				value = !!value;
				$(shim).slider( "option", "disabled", value );
				$('span', shim)
					.attr({
						'aria-disabled': value+'',
						'tabindex': (value) ? '-1' : '0'
					})
				;
			},
			min: function(orig, shim, value){
				value = (value) ? value * 1 || 0 : 0;
				$(shim).slider( "option", "min", value );
				$('span', shim).attr({'aria-valuemin': value});
			},
			max: function(orig, shim, value){
				value = (value || value === 0) ? value * 1 || 100 : 100;
				$(shim).slider( "option", "max", value );
				$('span', shim).attr({'aria-valuemax': value});
			},
			value: function(orig, shim, value){
				value = $(orig).prop('valueAsNumber');
				if(!isNaN(value)){
					if(!replaceInputUI.range.blockAttr){
						$(shim).slider( "option", "value", value );
					}
					$('span', shim).attr({'aria-valuenow': value, 'aria-valuetext': value});
				}
			},
			step: function(orig, shim, value){
				value = (value && $.trim(value)) ? value * 1 || 1 : 1;
				$(shim).slider( "option", "step", value );
			}
		};
	}
	
	if(options.replaceUI || !Modernizr.inputtypes.date /*|| !Modernizr.inputtypes["datetime-local"]*/ || !Modernizr.inputtypes.range){
		var reflectFn = function(val){
			if(webshims.data(this, 'hasShadow')){
				$.prop(this, 'value', $.prop(this, 'value'));
			}
		};
		
		webshims.onNodeNamesPropertyModify('input', 'valueAsNumber', reflectFn);
		webshims.onNodeNamesPropertyModify('input', 'valueAsDate', reflectFn);
	}
	
	$.each(['disabled', 'min', 'max', 'value', 'step', 'data-placeholder'], function(i, attr){
		webshims.onNodeNamesPropertyModify('input', attr, function(val){
				var shadowData = webshims.data(this, 'shadowData');
				if(shadowData && shadowData.data && shadowData.data[attr] && shadowData.nativeElement === this){
					shadowData.data[attr](this, shadowData.shadowElement, val);
				}
			}
		);
	});
	if(!options.availabeLangs){
		options.availabeLangs = 'af ar ar-DZ az bg bs ca cs da de el en-AU en-GB en-NZ eo es et eu fa fi fo fr fr-CH gl he hr hu hy id is it ja ko kz lt lv ml ms nl no pl pt-BR rm ro ru sk sl sq sr sr-SR sv ta th tr uk vi zh-CN zh-HK zh-TW'.split(' ');
	}
	
	var getDefaults = function(){
		if(!$.datepicker){return;}
		
		webshims.activeLang({
			langObj: $.datepicker.regional, 
			module: 'form-number-date-ui', 
			callback: function(langObj){
				var datepickerCFG = $.extend({}, defaultDatepicker, langObj, options.datepicker);
				
				
				if(datepickerCFG.dateFormat && options.datepicker.dateFormat != datepickerCFG.dateFormat ){
					$('input.hasDatepicker')
						.filter('.input-date, .input-datetime-local-date')
						.datepicker('option', 'dateFormat', datepickerCFG.dateFormat)
						.getNativeElement()
						.filter('[data-placeholder]')
						.attr('data-placeholder', function(i, val){
							return val;
						})
					;
				}
				$.datepicker.setDefaults(datepickerCFG);
			}
		});
		$(document).unbind('jquery-uiReady.langchange input-widgetsReady.langchange');
	};
	
	$(document).on('jquery-uiReady.langchange input-widgetsReady.langchange', getDefaults);
	getDefaults();
	
	//implement set/arrow controls
(function(){
	var supportsType = (function(){
		var types = {};
		return function(type){
			if(type in types){
				return types[type];
			}
			return (types[type] = ($('<input type="'+type+'" />')[0].type === type));
		};
	})();
	
	if(supportsType('number') && supportsType('time')){return;}
	var doc = document;
	var options = webshims.cfg["forms-ext"];
	var typeModels = webshims.inputTypes;
	var allowedChars = {
		number: '0123456789.',
		time: '0123456789:.'
	};
	
	var getNextStep = function(input, upDown, cache){
		
		cache = cache || {};
		
		if( !('type' in cache) ){
			cache.type = $.prop(input, 'type');
		}
		if( !('step' in cache) ){
			cache.step = webshims.getStep(input, cache.type);
		}
		if( !('valueAsNumber' in cache) ){
			cache.valueAsNumber = typeModels[cache.type].asNumber($.prop(input, 'value'));
		}
		var delta = (cache.step == 'any') ? typeModels[cache.type].step * typeModels[cache.type].stepScaleFactor : cache.step,
			ret
		;
		webshims.addMinMaxNumberToCache('min', $(input), cache);
		webshims.addMinMaxNumberToCache('max', $(input), cache);
		
		if(isNaN(cache.valueAsNumber)){
			cache.valueAsNumber = typeModels[cache.type].stepBase || 0;
		}
		//make a valid step
		if(cache.step !== 'any'){
			ret = Math.round( ((cache.valueAsNumber - (cache.minAsnumber || 0)) % cache.step) * 1e7 ) / 1e7;
			if(ret &&  Math.abs(ret) != cache.step){
				cache.valueAsNumber = cache.valueAsNumber - ret;
			}
		}
		ret = cache.valueAsNumber + (delta * upDown);
		//using NUMBER.MIN/MAX is really stupid | ToDo: either use disabled state or make this more usable
		if(!isNaN(cache.minAsNumber) && ret < cache.minAsNumber){
			ret = (cache.valueAsNumber * upDown  < cache.minAsNumber) ? cache.minAsNumber : isNaN(cache.maxAsNumber) ? cache.valueAsNumber : cache.maxAsNumber;
		} else if(!isNaN(cache.maxAsNumber) && ret > cache.maxAsNumber){
			ret = (cache.valueAsNumber * upDown > cache.maxAsNumber) ? cache.maxAsNumber : isNaN(cache.minAsNumber) ? cache.valueAsNumber : cache.minAsNumber;
		} else {
			ret = Math.round( ret * 1e7)  / 1e7;
		}
		return ret;
	};
	
	webshims.modules["form-number-date-ui"].getNextStep = getNextStep;
	
	
	if(options.stepArrows){
		var stepDisableEnable = {
			// don't change getter
			set: function(value){
				var stepcontrols = webshims.data(this, 'step-controls');
				if(stepcontrols){
					stepcontrols[ (this.disabled || this.readonly) ? 'addClass' : 'removeClass' ]('disabled-step-control');
				}
			}
		};
		webshims.onNodeNamesPropertyModify('input', 'disabled', stepDisableEnable);
		webshims.onNodeNamesPropertyModify('input', 'readonly', $.extend({}, stepDisableEnable));
	}
	var stepKeys = {
		38: 1,
		40: -1
	};
	
	var changeInput = function(elem, type){
		var blockBlurChange = false;
		var DELAY = 9;
		var doChangeValue, blockChangeValue;

		function step(dir){
			if($.prop(elem, 'disabled') || elem.readOnly || !dir){return;}
			doChangeValue = typeModels[type].numberToString(getNextStep(elem, dir, {type: type}));
			$.prop(elem, 'value', doChangeValue);
			triggerInlineForm(elem, 'input');
		}

		function setFocus(){
			blockBlurChange = true;
			setTimeout(function(){
				blockBlurChange = false;
			}, DELAY + 9);
			setTimeout(function(){
				if(!$(elem).is(':focus')){
					try{
						elem.focus();
					} catch(e){}
				}
			}, 1);
		}

		function triggerChange(){
			var curValue = $.prop(elem, 'value');
			if(curValue == doChangeValue && curValue != blockChangeValue && typeof curValue == 'string'){
				triggerInlineForm(elem, 'change');
			}
			blockChangeValue = curValue;
		}

		function init(){
			blockChangeValue = $(elem)
				.on({
					'change.stepcontrol focus.stepcontrol': function(e){
						if(!blockBlurChange || e.type != 'focus'){
							blockChangeValue = $.prop(elem, 'value');
						}
					},
					'blur.stepcontrol': function(){
						if(!blockBlurChange){
							setTimeout(function(){
								if(!blockBlurChange && !$(elem).is(':focus')){
									triggerChange();
								}
								doChangeValue = false;
							}, DELAY);
						}
					}
				})
				.prop('value')
			;
		}

		init();
		return {
			triggerChange: triggerChange,
			step: step,
			setFocus: setFocus
		};
	};
	
	webshims.addReady(function(context, contextElem){
		//ui for numeric values
		if(options.stepArrows){
			$('input', context).add(contextElem.filter('input')).each(function(){
				var type = $.prop(this, 'type');
				if(!typeModels[type] || !typeModels[type].asNumber || !options.stepArrows || (options.stepArrows !== true && !options.stepArrows[type]) || supportsType(type) || $(elem).hasClass('has-step-controls')){return;}
				var elem = this;
				var uiEvents = changeInput(elem, type);
				var controls = $('<span class="step-controls" unselectable="on"><span class="step-up" /><span class="step-down" /></span>')	
					.insertAfter(elem)
					.on({
						'selectstart dragstart': function(){return false;},
						'mousedown mousepress': function(e){
							if(!$(e.target).hasClass('step-controls')){
								uiEvents.step(($(e.target).hasClass('step-up')) ? 1 : -1);
							}
							uiEvents.setFocus();
							return false;
						},
						'mousepressstart mousepressend': function(e){
							if(e.type == 'mousepressend'){
								uiEvents.triggerChange();
							}
							$(e.target)[e.type == 'mousepressstart' ? 'addClass' : 'removeClass']('mousepress-ui');
						}
					})
				;
				var mwheelUpDown = function(e, d){
					if(d){
						uiEvents.step(d);
						return false;
					}
				};
				
				var jElm = $(elem)
					.addClass('has-step-controls')
					.attr({
						readonly: elem.readOnly,
						disabled: elem.disabled,
						autocomplete: 'off',
						role: 'spinbutton'
					})
					.on('keyup', function(e){
						var step = stepKeys[e.keyCode];
						if(step){
							uiEvents.triggerChange(step);
						}
					})
					.on(($.browser.msie) ? 'keydown' : 'keypress', function(e){
						var step = stepKeys[e.keyCode];
						if(step){
							uiEvents.step(step);
							return false;
						}
					})
				;
				
				if(allowedChars[type]){
					jElm.on('keypress', (function(){
						var chars = allowedChars[type];
						return function(event){
							var chr = String.fromCharCode(event.charCode == null ? event.keyCode : event.charCode);
							return event.ctrlKey || event.metaKey || (chr < ' ' || chars.indexOf(chr) > -1);
						};
					})());
				}
				
				jElm
					.on({
						focus: function(){
							jElm.add(controls).off('.mwhellwebshims')
								.on('mousewheel.mwhellwebshims', mwheelUpDown)
							;
						},
						blur: function(){
							$(elem).add(controls).off('.mwhellwebshims');
						}
					})
				;
				
				webshims.data(elem, 'step-controls', controls);
				if(options.calculateWidth){
					var init;
					jElm
						.on('updateshadowdom', function(){
							if(!init && (elem.offsetWidth || elem.offsetHeight)){
								init = true;
								adjustInputWithBtn(jElm, controls);
								controls.css('marginTop', (jElm.outerHeight() - controls.outerHeight()) / 2);
							}
						})
						.triggerHandler('updateshadowdom')
					;
				}
			});
		}
	});
})();

	
	webshims.addReady(function(context, elem){
		$(document).on('jquery-uiReady.initinputui input-widgetsReady.initinputui', function(e){
			if($.datepicker || $.fn.slider){
				if($.datepicker && !defaultDatepicker.dateFormat){
					defaultDatepicker.dateFormat = $.datepicker._defaults.dateFormat;
				}
				replaceInputUI(context, elem);
			}
			if($.datepicker && $.fn.slider){
				$(document).unbind('.initinputui');
			} else if(!webshims.modules["input-widgets"].src){
				webshims.warn('jQuery UI Widget factory is already included, but not datepicker or slider. configure src of $.webshims.modules["input-widgets"].src');
			}
		});
	});
	
});

