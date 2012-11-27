//additional tests for partial implementation of forms features
(function($){
	"use strict";
	var Modernizr = window.Modernizr;
	var webshims = $.webshims;
	var bugs = webshims.bugs;
	var form = $('<form action="#" style="width: 1px; height: 1px; overflow: hidden;"><select name="b" required="" /><input required="" name="a" /></form>');
	var testRequiredFind = function(){
		if(form[0].querySelector){
			try {
				bugs.findRequired = !(form[0].querySelector('select:required'));
			} catch(er){
				bugs.findRequired = false;
			}
		}
	};
	var inputElem = $('input', form).eq(0);
	var onDomextend = function(fn){
		webshims.loader.loadList(['dom-extend']);
		webshims.ready('dom-extend', fn);
	};
	
	bugs.findRequired = false;
	bugs.validationMessage = false;
	
	webshims.capturingEventPrevented = function(e){
		if(!e._isPolyfilled){
			var isDefaultPrevented = e.isDefaultPrevented;
			var preventDefault = e.preventDefault;
			e.preventDefault = function(){
				clearTimeout($.data(e.target, e.type + 'DefaultPrevented'));
				$.data(e.target, e.type + 'DefaultPrevented', setTimeout(function(){
					$.removeData(e.target, e.type + 'DefaultPrevented');
				}, 30));
				return preventDefault.apply(this, arguments);
			};
			e.isDefaultPrevented = function(){
				return !!(isDefaultPrevented.apply(this, arguments) || $.data(e.target, e.type + 'DefaultPrevented') || false);
			};
			e._isPolyfilled = true;
		}
	};
	
	if(!Modernizr.formvalidation || bugs.bustedValidity){
		testRequiredFind();
		return;
	}
	
	//create delegatable events
	webshims.capturingEvents(['input']);
	webshims.capturingEvents(['invalid'], true);
	
	if(window.opera || window.testGoodWithFix){
		
		form.appendTo('head');
		
		testRequiredFind();
		bugs.validationMessage = !(inputElem.prop('validationMessage'));
		
		webshims.reTest(['form-native-extend', 'form-message']);
		
		form.remove();
			
		$(function(){
			onDomextend(function(){
				
				//Opera shows native validation bubbles in case of input.checkValidity()
				// Opera 11.6/12 hasn't fixed this issue right, it's buggy
				var preventDefault = function(e){
					e.preventDefault();
				};
				
				['form', 'input', 'textarea', 'select'].forEach(function(name){
					var desc = webshims.defineNodeNameProperty(name, 'checkValidity', {
						prop: {
							value: function(){
								if (!webshims.fromSubmit) {
									$(this).on('invalid.checkvalidity', preventDefault);
								}
								
								webshims.fromCheckValidity = true;
								var ret = desc.prop._supvalue.apply(this, arguments);
								if (!webshims.fromSubmit) {
									$(this).unbind('invalid.checkvalidity', preventDefault);
								}
								webshims.fromCheckValidity = false;
								return ret;
							}
						}
					});
				});
				
			});
		});
	}
	
	if($.browser.webkit && !webshims.bugs.bustedValidity){
		(function(){
			var elems = /^(?:textarea|input)$/i;
			var form = false;

			document.addEventListener('contextmenu', function(e){
				if(elems.test( e.target.nodeName || '') && (form = e.target.form)){
					setTimeout(function(){
						form = false;
					}, 1);
				}
			}, false);
			
			$(window).on('invalid', function(e){
				if(e.originalEvent && form && form == e.target.form){
					e.wrongWebkitInvalid = true;
					e.stopImmediatePropagation();
				}
			});
		})();
	}
})(jQuery);

jQuery.webshims.register('form-core', function($, webshims, window, document, undefined, options){
	"use strict";
	
	var groupTypes = {radio: 1};
	var checkTypes = {checkbox: 1, radio: 1};
	var emptyJ = $([]);
	var bugs = webshims.bugs;
	var getGroupElements = function(elem){
		elem = $(elem);
		var name;
		var form;
		var ret = emptyJ;
		if(groupTypes[elem[0].type]){
			form = elem.prop('form');
			name = elem[0].name;
			if(!name){
				ret = elem;
			} else if(form){
				ret = $(form[name]);
			} else {
				ret = $(document.getElementsByName(name)).filter(function(){
					return !$.prop(this, 'form');
				});
			}
			ret = ret.filter('[type="radio"]');
		}
		return ret;
	};
	
	var getContentValidationMessage = webshims.getContentValidationMessage = function(elem, validity, key){
		var message = $(elem).data('errormessage') || elem.getAttribute('x-moz-errormessage') || '';
		if(key && message[key]){
			message = message[key];
		}
		if(typeof message == 'object'){
			validity = validity || $.prop(elem, 'validity') || {valid: 1};
			if(!validity.valid){
				$.each(validity, function(name, prop){
					if(prop && name != 'valid' && message[name]){
						message = message[name];
						return false;
					}
				});
			}
		}
		
		if(typeof message == 'object'){
			message = message.defaultMessage;
		}
		return message || '';
	};
	
	/*
	 * Selectors for all browsers
	 */
	var rangeTypes = {number: 1, range: 1, date: 1/*, time: 1, 'datetime-local': 1, datetime: 1, month: 1, week: 1*/};
	var hasInvalid = function(elem){
		var ret = false;
		$($.prop(elem, 'elements')).each(function(){
			ret = $(this).is(':invalid');
			if(ret){
				return false;
			}
		});
		return ret;
	};
	$.extend($.expr[":"], {
		"valid-element": function(elem){
			return $.nodeName(elem, 'form') ? !hasInvalid(elem) :!!($.prop(elem, 'willValidate') && isValid(elem));
		},
		"invalid-element": function(elem){
			return $.nodeName(elem, 'form') ? hasInvalid(elem) : !!($.prop(elem, 'willValidate') && !isValid(elem));
		},
		"required-element": function(elem){
			return !!($.prop(elem, 'willValidate') && $.prop(elem, 'required'));
		},
		"user-error": function(elem){
			return ($.prop(elem, 'willValidate') && $(elem).hasClass('user-error'));
		},
		"optional-element": function(elem){
			return !!($.prop(elem, 'willValidate') && $.prop(elem, 'required') === false);
		},
		"in-range": function(elem){
			if(!rangeTypes[$.prop(elem, 'type')] || !$.prop(elem, 'willValidate')){
				return false;
			}
			var val = $.prop(elem, 'validity');
			return !!(val && !val.rangeOverflow && !val.rangeUnderflow);
		},
		"out-of-range": function(elem){
			if(!rangeTypes[$.prop(elem, 'type')] || !$.prop(elem, 'willValidate')){
				return false;
			}
			var val = $.prop(elem, 'validity');
			return !!(val && (val.rangeOverflow || val.rangeUnderflow));
		}
		
	});
	
	['valid', 'invalid', 'required', 'optional'].forEach(function(name){
		$.expr[":"][name] = $.expr.filters[name+"-element"];
	});
	
	
	$.expr[":"].focus = function( elem ) {
		try {
			var doc = elem.ownerDocument;
			return elem === doc.activeElement && (!doc.hasFocus || doc.hasFocus());
		} catch(e){}
		return false;
	};
	
	var customEvents = $.event.customEvent || {};
	var isValid = function(elem){
		return ($.prop(elem, 'validity') || {valid: 1}).valid;
	};
	
	if (bugs.bustedValidity || bugs.findRequired) {
		(function(){
			var find = $.find;
			var matchesSelector = $.find.matchesSelector;
			
			var regExp = /(\:valid|\:invalid|\:optional|\:required|\:in-range|\:out-of-range)(?=[\s\[\~\.\+\>\:\#*]|$)/ig;
			var regFn = function(sel){
				return sel + '-element';
			};
			
			$.find = (function(){
				var slice = Array.prototype.slice;
				var fn = function(sel){
					var ar = arguments;
					ar = slice.call(ar, 1, ar.length);
					ar.unshift(sel.replace(regExp, regFn));
					return find.apply(this, ar);
				};
				for (var i in find) {
					if(find.hasOwnProperty(i)){
						fn[i] = find[i];
					}
				}
				return fn;
			})();
			if(!Modernizr.prefixed || Modernizr.prefixed("matchesSelector", document.documentElement)){
				$.find.matchesSelector = function(node, expr){
					expr = expr.replace(regExp, regFn);
					return matchesSelector.call(this, node, expr);
				};
			}
			
		})();
	}
	
	//ToDo needs testing
	var oldAttr = $.prop;
	var changeVals = {selectedIndex: 1, value: 1, checked: 1, disabled: 1, readonly: 1};
	$.prop = function(elem, name, val){
		var ret = oldAttr.apply(this, arguments);
		if(elem && 'form' in elem && changeVals[name] && val !== undefined && $(elem).hasClass(invalidClass)){
			if(isValid(elem)){
				$(elem).getShadowElement().removeClass(invalidClasses);
				if(name == 'checked' && val) {
					getGroupElements(elem).not(elem).removeClass(invalidClasses).removeAttr('aria-invalid');
				}
			}
		}
		return ret;
	};
	
	var returnValidityCause = function(validity, elem){
		var ret;
		$.each(validity, function(name, value){
			if(value){
				ret = (name == 'customError') ? $.prop(elem, 'validationMessage') : name;
				return false;
			}
		});
		return ret;
	};
	
	var isInGroup = function(name){
		var ret;
		try {
			ret = document.activeElement.name === name;
		} catch(e){}
		return ret;
	};
	/* form-ui-invalid/form-ui-valid are deprecated. use user-error/user-succes instead */
	var invalidClass = 'user-error';
	var invalidClasses = 'user-error form-ui-invalid';
	var validClass = 'user-success';
	var validClasses = 'user-success form-ui-valid';
	var switchValidityClass = function(e){
		var elem, timer;
		if(!e.target){return;}
		elem = $(e.target).getNativeElement()[0];
		if(elem.type == 'submit' || !$.prop(elem, 'willValidate')){return;}
		timer = $.data(elem, 'webshimsswitchvalidityclass');
		var switchClass = function(){
			if(e.type == 'focusout' && elem.type == 'radio' && isInGroup(elem.name)){return;}
			var validity = $.prop(elem, 'validity');
			var shadowElem = $(elem).getShadowElement();
			var addClass, removeClass, trigger, generaltrigger, validityCause;
			
			$(elem).trigger('refreshCustomValidityRules');
			if(validity.valid){
				if(!shadowElem.hasClass(validClass)){
					addClass = validClasses;
					removeClass = invalidClasses;
					generaltrigger = 'changedvaliditystate';
					trigger = 'changedvalid';
					if(checkTypes[elem.type] && elem.checked){
						getGroupElements(elem).not(elem).removeClass(removeClass).addClass(addClass).removeAttr('aria-invalid');
					}
					$.removeData(elem, 'webshimsinvalidcause');
				}
			} else {
				validityCause = returnValidityCause(validity, elem);
				if($.data(elem, 'webshimsinvalidcause') != validityCause){
					$.data(elem, 'webshimsinvalidcause', validityCause);
					generaltrigger = 'changedvaliditystate';
				}
				if(!shadowElem.hasClass(invalidClass)){
					addClass = invalidClasses;
					removeClass = validClasses;
					if (checkTypes[elem.type] && !elem.checked) {
						getGroupElements(elem).not(elem).removeClass(removeClass).addClass(addClass);
					}
					trigger = 'changedinvalid';
				}
			}
			if(addClass){
				shadowElem.addClass(addClass).removeClass(removeClass);
				//jQuery 1.6.1 IE9 bug (doubble trigger bug)
				setTimeout(function(){
					$(elem).trigger(trigger);
				}, 0);
			}
			if(generaltrigger){
				setTimeout(function(){
					$(elem).trigger(generaltrigger);
				}, 0);
			}
			$.removeData(e.target, 'webshimsswitchvalidityclass');
		};
		
		if(timer){
			clearTimeout(timer);
		}
		if(e.type == 'refreshvalidityui'){
			switchClass();
		} else {
			$.data(elem, 'webshimsswitchvalidityclass', setTimeout(switchClass, 9));
		}
	};
	
	$(document).on(options.validityUIEvents || 'focusout change refreshvalidityui', switchValidityClass);
	customEvents.changedvaliditystate = true;
	customEvents.refreshCustomValidityRules = true;
	customEvents.changedvalid = true;
	customEvents.changedinvalid = true;
	customEvents.refreshvalidityui = true;
	
	
	webshims.triggerInlineForm = function(elem, event){
		$(elem).trigger(event);
	};
	
	webshims.modules["form-core"].getGroupElements = getGroupElements;
	
	
	var setRoot = function(){
		webshims.scrollRoot = ($.browser.webkit || document.compatMode == 'BackCompat') ?
			$(document.body) : 
			$(document.documentElement)
		;
	};
	setRoot();
	webshims.ready('DOM', setRoot);
	
	webshims.getRelOffset = function(posElem, relElem){
		posElem = $(posElem);
		var offset = $(relElem).offset();
		var bodyOffset;
		$.swap($(posElem)[0], {visibility: 'hidden', display: 'inline-block', left: 0, top: 0}, function(){
			bodyOffset = posElem.offset();
		});
		offset.top -= bodyOffset.top;
		offset.left -= bodyOffset.left;
		return offset;
	};
	
	/* some extra validation UI */
	webshims.validityAlert = (function(){
		var alertElem = (!$.browser.msie || parseInt($.browser.version, 10) > 7) ? 'span' : 'label';
		var errorBubble;
		var hideTimer = false;
		var focusTimer = false;
		var resizeTimer = false;
		var boundHide;
		
		var api = {
			hideDelay: 5000,
			
			showFor: function(elem, message, noFocusElem, noBubble){
				api._create();
				elem = $(elem);
				var visual = $(elem).getShadowElement();
				var offset = api.getOffsetFromBody(visual);
				api.clear();
				if(noBubble){
					this.hide();
				} else {
					this.getMessage(elem, message);
					this.position(visual, offset);
					
					this.show();
					if(this.hideDelay){
						hideTimer = setTimeout(boundHide, this.hideDelay);
					}
					$(window)
						.on('resize.validityalert', function(){
							clearTimeout(resizeTimer);
							resizeTimer = setTimeout(function(){
								api.position(visual);
							}, 9);
						})
					;
				}
				
				if(!noFocusElem){
					this.setFocus(visual, offset);
				}
			},
			getOffsetFromBody: function(elem){
				return webshims.getRelOffset(errorBubble, elem);
			},
			setFocus: function(visual, offset){
				var focusElem = $(visual).getShadowFocusElement();
				var scrollTop = webshims.scrollRoot.scrollTop();
				var elemTop = ((offset || focusElem.offset()).top) - 30;
				var smooth;
				
				if(webshims.getID && alertElem == 'label'){
					errorBubble.attr('for', webshims.getID(focusElem));
				}
				
				if(scrollTop > elemTop){
					webshims.scrollRoot.animate(
						{scrollTop: elemTop - 5}, 
						{
							queue: false, 
							duration: Math.max( Math.min( 600, (scrollTop - elemTop) * 1.5 ), 80 )
						}
					);
					smooth = true;
				}
				try {
					focusElem[0].focus();
				} catch(e){}
				if(smooth){
					webshims.scrollRoot.scrollTop(scrollTop);
					setTimeout(function(){
						webshims.scrollRoot.scrollTop(scrollTop);
					}, 0);
				}
				setTimeout(function(){
					$(document).on('focusout.validityalert', boundHide);
				}, 10);
			},
			getMessage: function(elem, message){
				if (!message) {
					message = getContentValidationMessage(elem[0]) || elem.prop('validationMessage');
				}
				if (message) {
					$('span.va-box', errorBubble).text(message);
				}
				else {
					this.hide();
				}
			},
			position: function(elem, offset){
				offset = offset ? $.extend({}, offset) : api.getOffsetFromBody(elem);
				offset.top += elem.outerHeight();
				errorBubble.css(offset);
			},
			show: function(){
				if(errorBubble.css('display') === 'none'){
					errorBubble.css({opacity: 0}).show();
				}
				errorBubble.addClass('va-visible').fadeTo(400, 1);
			},
			hide: function(){
				errorBubble.removeClass('va-visible').fadeOut();
			},
			clear: function(){
				clearTimeout(focusTimer);
				clearTimeout(hideTimer);
				$(document).unbind('.validityalert');
				$(window).unbind('.validityalert');
				errorBubble.stop().removeAttr('for');
			},
			_create: function(){
				if(errorBubble){return;}
				errorBubble = api.errorBubble = $('<'+alertElem+' class="validity-alert-wrapper" role="alert"><span  class="validity-alert"><span class="va-arrow"><span class="va-arrow-box"></span></span><span class="va-box"></span></span></'+alertElem+'>').css({position: 'absolute', display: 'none'});
				webshims.ready('DOM', function(){
					errorBubble.appendTo('body');
					if($.fn.bgIframe && $.browser.msie && parseInt($.browser.version, 10) < 7){
						errorBubble.bgIframe();
					}
				});
			}
		};
		
		
		boundHide = $.proxy(api, 'hide');
		
		return api;
	})();
	
	
	/* extension, but also used to fix native implementation workaround/bugfixes */
	(function(){
		var firstEvent,
			invalids = [],
			stopSubmitTimer,
			form
		;
		
		$(document).on('invalid', function(e){
			if(e.wrongWebkitInvalid){return;}
			var jElm = $(e.target);
			var shadowElem = jElm.getShadowElement();
			if(!shadowElem.hasClass(invalidClass)){
				shadowElem.addClass(invalidClasses).removeClass(validClasses);
				setTimeout(function(){
					$(e.target).trigger('changedinvalid').trigger('changedvaliditystate');
				}, 0);
			}
			
			if(!firstEvent){
				//trigger firstinvalid
				firstEvent = $.Event('firstinvalid');
				firstEvent.isInvalidUIPrevented = e.isDefaultPrevented;
				var firstSystemInvalid = $.Event('firstinvalidsystem');
				$(document).triggerHandler(firstSystemInvalid, {element: e.target, form: e.target.form, isInvalidUIPrevented: e.isDefaultPrevented});
				jElm.trigger(firstEvent);
			}

			//if firstinvalid was prevented all invalids will be also prevented
			if( firstEvent && firstEvent.isDefaultPrevented() ){
				e.preventDefault();
			}
			invalids.push(e.target);
			e.extraData = 'fix'; 
			clearTimeout(stopSubmitTimer);
			stopSubmitTimer = setTimeout(function(){
				var lastEvent = {type: 'lastinvalid', cancelable: false, invalidlist: $(invalids)};
				//reset firstinvalid
				firstEvent = false;
				invalids = [];
				$(e.target).trigger(lastEvent, lastEvent);
			}, 9);
			jElm = null;
			shadowElem = null;
		});
	})();
	
	$.fn.getErrorMessage = function(){
		var message = '';
		var elem = this[0];
		if(elem){
			message = getContentValidationMessage(elem) || $.prop(elem, 'customValidationMessage') || $.prop(elem, 'validationMessage');
		}
		return message;
	};
	
	if(options.replaceValidationUI){
		webshims.ready('DOM forms', function(){
			$(document).on('firstinvalid', function(e){
				if(!e.isInvalidUIPrevented()){
					e.preventDefault();
					$.webshims.validityAlert.showFor( e.target, $(e.target).prop('customValidationMessage') ); 
				}
			});
		});
	}
	
});
jQuery.webshims.register('form-native-extend', function($, webshims, window, doc, undefined, options){
	"use strict";
	var Modernizr = window.Modernizr;
	var modernizrInputTypes = Modernizr.inputtypes;
	if(!Modernizr.formvalidation || webshims.bugs.bustedValidity){return;}
	var typeModels = webshims.inputTypes;
	var validityRules = {};
	
	webshims.addInputType = function(type, obj){
		typeModels[type] = obj;
	};
	
	webshims.addValidityRule = function(type, fn){
		validityRules[type] = fn;
	};
	
	webshims.addValidityRule('typeMismatch',function (input, val, cache, validityState){
		if(val === ''){return false;}
		var ret = validityState.typeMismatch;
		if(!('type' in cache)){
			cache.type = (input[0].getAttribute('type') || '').toLowerCase();
		}
		
		if(typeModels[cache.type] && typeModels[cache.type].mismatch){
			ret = typeModels[cache.type].mismatch(val, input);
		}
		return ret;
	});
	
	var overrideNativeMessages = options.overrideMessages;	
	
	var overrideValidity = (!modernizrInputTypes.number || !modernizrInputTypes.time || !modernizrInputTypes.range || overrideNativeMessages);
	var validityProps = ['customError','typeMismatch','rangeUnderflow','rangeOverflow','stepMismatch','tooLong','patternMismatch','valueMissing','valid'];
	
	var validityChanger = (overrideNativeMessages)? ['value', 'checked'] : ['value'];
	var validityElements = [];
	var testValidity = function(elem, init){
		if(!elem){return;}
		var type = (elem.getAttribute && elem.getAttribute('type') || elem.type || '').toLowerCase();
		
		if(!overrideNativeMessages && !typeModels[type]){
			return;
		}
		
		if(overrideNativeMessages && !init && type == 'radio' && elem.name){
			$(doc.getElementsByName( elem.name )).each(function(){
				$.prop(this, 'validity');
			});
		} else {
			$.prop(elem, 'validity');
		}
	};
	
	var oldSetCustomValidity = {};
	['input', 'textarea', 'select'].forEach(function(name){
		var desc = webshims.defineNodeNameProperty(name, 'setCustomValidity', {
			prop: {
				value: function(error){
					error = error+'';
					var elem = (name == 'input') ? $(this).getNativeElement()[0] : this;
					desc.prop._supvalue.call(elem, error);
					
					if(webshims.bugs.validationMessage){
						webshims.data(elem, 'customvalidationMessage', error);
					}
					if(overrideValidity){
						webshims.data(elem, 'hasCustomError', !!(error));
						testValidity(elem);
					}
				}
			}
		});
		oldSetCustomValidity[name] = desc.prop._supvalue;
	});
		
	
	if(overrideValidity || overrideNativeMessages){
		validityChanger.push('min');
		validityChanger.push('max');
		validityChanger.push('step');
		validityElements.push('input');
	}
	if(overrideNativeMessages){
		validityChanger.push('required');
		validityChanger.push('pattern');
		validityElements.push('select');
		validityElements.push('textarea');
	}
	
	if(overrideValidity){
		var stopValidity;
		validityElements.forEach(function(nodeName){
			
			var oldDesc = webshims.defineNodeNameProperty(nodeName, 'validity', {
				prop: {
					get: function(){
						if(stopValidity){return;}
						var elem = (nodeName == 'input') ? $(this).getNativeElement()[0] : this;
						
						var validity = oldDesc.prop._supget.call(elem);
						
						if(!validity){
							return validity;
						}
						var validityState = {};
						validityProps.forEach(function(prop){
							validityState[prop] = validity[prop];
						});
						
						if( !$.prop(elem, 'willValidate') ){
							return validityState;
						}
						stopValidity = true;
						var jElm 			= $(elem),
							cache 			= {type: (elem.getAttribute && elem.getAttribute('type') || '').toLowerCase(), nodeName: (elem.nodeName || '').toLowerCase()},
							val				= jElm.val(),
							customError 	= !!(webshims.data(elem, 'hasCustomError')),
							setCustomMessage
						;
						stopValidity = false;
						validityState.customError = customError;
						
						if( validityState.valid && validityState.customError ){
							validityState.valid = false;
						} else if(!validityState.valid) {
							var allFalse = true;
							$.each(validityState, function(name, prop){
								if(prop){
									allFalse = false;
									return false;
								}
							});
							
							if(allFalse){
								validityState.valid = true;
							}
							
						}
						
						$.each(validityRules, function(rule, fn){
							validityState[rule] = fn(jElm, val, cache, validityState);
							if( validityState[rule] && (validityState.valid || !setCustomMessage) && (overrideNativeMessages || (typeModels[cache.type] && typeModels[cache.type].mismatch)) ) {
								oldSetCustomValidity[nodeName].call(elem, webshims.createValidationMessage(elem, rule));
								validityState.valid = false;
								setCustomMessage = true;
							}
						});
						if(validityState.valid){
							oldSetCustomValidity[nodeName].call(elem, '');
							webshims.data(elem, 'hasCustomError', false);
						} else if(overrideNativeMessages && !setCustomMessage && !customError){
							$.each(validityState, function(name, prop){
								if(name !== 'valid' && prop){
									oldSetCustomValidity[nodeName].call(elem, webshims.createValidationMessage(elem, name));
									return false;
								}
							});
						}
						return validityState;
					},
					writeable: false
					
				}
			});
		});

		validityChanger.forEach(function(prop){
			webshims.onNodeNamesPropertyModify(validityElements, prop, function(s){
				testValidity(this);
			});
		});
		
		if(doc.addEventListener){
			var inputThrottle;
			var testPassValidity = function(e){
				if(!('form' in e.target)){return;}
				var form = e.target.form;
				clearTimeout(inputThrottle);
				testValidity(e.target);
				if(form && overrideNativeMessages){
					$('input', form).each(function(){
						if(this.type == 'password'){
							testValidity(this);
						}
					});
				}
			};
			
			doc.addEventListener('change', testPassValidity, true);
			
			if(overrideNativeMessages){
				doc.addEventListener('blur', testPassValidity, true);
				doc.addEventListener('keydown', function(e){
					if(e.keyCode != 13){return;}
					testPassValidity(e);
				}, true);
			}
			
			doc.addEventListener('input', function(e){
				clearTimeout(inputThrottle);
				inputThrottle = setTimeout(function(){
					testValidity(e.target);
				}, 290);
			}, true);
		}
		
		var validityElementsSel = validityElements.join(',');	
		
		webshims.addReady(function(context, elem){
			$(validityElementsSel, context).add(elem.filter(validityElementsSel)).each(function(){
				$.prop(this, 'validity');
			});
		});
		
		
		if(overrideNativeMessages){
			webshims.ready('DOM form-message', function(){
				webshims.activeLang({
					register: 'form-core',
					callback: function(){
						$('input, select, textarea')
							.getNativeElement()
							.each(function(){
								if(webshims.data(this, 'hasCustomError')){return;}
								var elem = this;
								var validity = $.prop(elem, 'validity') || {valid: true};
								var nodeName;
								if(validity.valid){return;}
								nodeName = (elem.nodeName || '').toLowerCase();
								$.each(validity, function(name, prop){
									if(name !== 'valid' && prop){
										oldSetCustomValidity[nodeName].call(elem, webshims.createValidationMessage(elem, name));
										return false;
									}
								});
							})
						;
					}
				});
			});
		}
		
	} //end: overrideValidity
	
	webshims.defineNodeNameProperty('input', 'type', {
		prop: {
			get: function(){
				var elem = this;
				var type = (elem.getAttribute('type') || '').toLowerCase();
				return (webshims.inputTypes[type]) ? type : elem.type;
			}
		}
	});
	
	
});
jQuery.webshims.register('form-message', function($, webshims, window, document, undefined, options){
	"use strict";
	var validityMessages = webshims.validityMessages;
	
	var implementProperties = (options.overrideMessages || options.customMessages) ? ['customValidationMessage'] : [];
	
	validityMessages['en'] = $.extend(true, {
		typeMismatch: {
			email: 'Please enter an email address.',
			url: 'Please enter a URL.',
			number: 'Please enter a number.',
			date: 'Please enter a date.',
			time: 'Please enter a time.',
			range: 'Invalid input.',
			"datetime-local": 'Please enter a datetime.'
		},
		rangeUnderflow: {
			defaultMessage: 'Value must be greater than or equal to {%min}.'
		},
		rangeOverflow: {
			defaultMessage: 'Value must be less than or equal to {%max}.'
		},
		stepMismatch: 'Invalid input.',
		tooLong: 'Please enter at most {%maxlength} character(s). You entered {%valueLen}.',
		
		patternMismatch: 'Invalid input. {%title}',
		valueMissing: {
			defaultMessage: 'Please fill out this field.',
			checkbox: 'Please check this box if you want to proceed.'
		}
	}, (validityMessages['en'] || validityMessages['en-US'] || {}));
	
	
	['select', 'radio'].forEach(function(type){
		validityMessages['en'].valueMissing[type] = 'Please select an option.';
	});
	
	['date', 'time', 'datetime-local'].forEach(function(type){
		validityMessages.en.rangeUnderflow[type] = 'Value must be at or after {%min}.';
	});
	['date', 'time', 'datetime-local'].forEach(function(type){
		validityMessages.en.rangeOverflow[type] = 'Value must be at or before {%max}.';
	});
	
	validityMessages['en-US'] = validityMessages['en-US'] || validityMessages['en'];
	validityMessages[''] = validityMessages[''] || validityMessages['en-US'];
	
	validityMessages['de'] = $.extend(true, {
		typeMismatch: {
			email: '{%value} ist keine zulässige E-Mail-Adresse',
			url: '{%value} ist keine zulässige Webadresse',
			number: '{%value} ist keine Nummer!',
			date: '{%value} ist kein Datum',
			time: '{%value} ist keine Uhrzeit',
			range: '{%value} ist keine Nummer!',
			"datetime-local": '{%value} ist kein Datum-Uhrzeit Format.'
		},
		rangeUnderflow: {
			defaultMessage: '{%value} ist zu niedrig. {%min} ist der unterste Wert, den Sie benutzen können.'
		},
		rangeOverflow: {
			defaultMessage: '{%value} ist zu hoch. {%max} ist der oberste Wert, den Sie benutzen können.'
		},
		stepMismatch: 'Der Wert {%value} ist in diesem Feld nicht zulässig. Hier sind nur bestimmte Werte zulässig. {%title}',
		tooLong: 'Der eingegebene Text ist zu lang! Sie haben {%valueLen} Zeichen eingegeben, dabei sind {%maxlength} das Maximum.',
		patternMismatch: '{%value} hat für dieses Eingabefeld ein falsches Format! {%title}',
		valueMissing: {
			defaultMessage: 'Bitte geben Sie einen Wert ein',
			checkbox: 'Bitte aktivieren Sie das Kästchen'
		}
	}, (validityMessages['de'] || {}));
	
	['select', 'radio'].forEach(function(type){
		validityMessages['de'].valueMissing[type] = 'Bitte wählen Sie eine Option aus';
	});
	
	['date', 'time', 'datetime-local'].forEach(function(type){
		validityMessages.de.rangeUnderflow[type] = '{%value} ist zu früh. {%min} ist die früheste Zeit, die Sie benutzen können.';
	});
	['date', 'time', 'datetime-local'].forEach(function(type){
		validityMessages.de.rangeOverflow[type] = '{%value} ist zu spät. {%max} ist die späteste Zeit, die Sie benutzen können.';
	});
	
	var currentValidationMessage =  validityMessages[''];
	
	
	webshims.createValidationMessage = function(elem, name){
		var message = currentValidationMessage[name];
		if(message && typeof message !== 'string'){
			message = message[ $.prop(elem, 'type') ] || message[ (elem.nodeName || '').toLowerCase() ] || message[ 'defaultMessage' ];
		}
		if(message){
			['value', 'min', 'max', 'title', 'maxlength', 'label'].forEach(function(attr){
				if(message.indexOf('{%'+attr) === -1){return;}
				var val = ((attr == 'label') ? $.trim($('label[for="'+ elem.id +'"]', elem.form).text()).replace(/\*$|:$/, '') : $.attr(elem, attr)) || '';
				if(name == 'patternMismatch' && attr == 'title' && !val){
					webshims.error('no title for patternMismatch provided. Always add a title attribute.');
				}
				message = message.replace('{%'+ attr +'}', val);
				if('value' == attr){
					message = message.replace('{%valueLen}', val.length);
				}
			});
		}
		return message || '';
	};
	
	
	if(webshims.bugs.validationMessage || !Modernizr.formvalidation || webshims.bugs.bustedValidity){
		implementProperties.push('validationMessage');
	}
	
	webshims.activeLang({
		langObj: validityMessages, 
		module: 'form-core', 
		callback: function(langObj){
			currentValidationMessage = langObj;
		}
	});
	
	implementProperties.forEach(function(messageProp){
		webshims.defineNodeNamesProperty(['fieldset', 'output', 'button'], messageProp, {
			prop: {
				value: '',
				writeable: false
			}
		});
		['input', 'select', 'textarea'].forEach(function(nodeName){
			var desc = webshims.defineNodeNameProperty(nodeName, messageProp, {
				prop: {
					get: function(){
						var elem = this;
						var message = '';
						if(!$.prop(elem, 'willValidate')){
							return message;
						}
						
						var validity = $.prop(elem, 'validity') || {valid: 1};
						
						if(validity.valid){return message;}
						message = webshims.getContentValidationMessage(elem, validity);
						
						if(message){return message;}
						
						if(validity.customError && elem.nodeName){
							message = (Modernizr.formvalidation && !webshims.bugs.bustedValidity && desc.prop._supget) ? desc.prop._supget.call(elem) : webshims.data(elem, 'customvalidationMessage');
							if(message){return message;}
						}
						$.each(validity, function(name, prop){
							if(name == 'valid' || !prop){return;}
							
							message = webshims.createValidationMessage(elem, name);
							if(message){
								return false;
							}
						});
						return message || '';
					},
					writeable: false
				}
			});
		});
		
	});
});
jQuery.webshims.register('form-datalist', function($, webshims, window, document, undefined){
	"use strict";
	var doc = document;	

	/*
	 * implement propType "element" currently only used for list-attribute (will be moved to dom-extend, if needed)
	 */
	webshims.propTypes.element = function(descs){
		webshims.createPropDefault(descs, 'attr');
		if(descs.prop){return;}
		descs.prop = {
			get: function(){
				var elem = descs.attr.get.call(this);
				if(elem){
					elem = document.getElementById(elem);
					if(elem && descs.propNodeName && !$.nodeName(elem, descs.propNodeName)){
						elem = null;
					}
				}
				return elem || null;
			},
			writeable: false
		};
	};
	
	
	/*
	 * Implements datalist element and list attribute
	 */
	
	(function(){
		var formsCFG = $.webshims.cfg.forms;
		var listSupport = Modernizr.input.list;
		if(listSupport && !formsCFG.customDatalist){return;}
		
			var initializeDatalist =  function(){
				
				
			if(!listSupport){
				webshims.defineNodeNameProperty('datalist', 'options', {
					prop: {
						writeable: false,
						get: function(){
							var elem = this;
							var select = $('select', elem);
							var options;
							if(select[0]){
								options = select[0].options;
							} else {
								options = $('option', elem).get();
								if(options.length){
									webshims.warn('you should wrap your option-elements for a datalist in a select element to support IE and other old browsers.');
								}
							}
							return options;
						}
					}
				});
			}
				
			var inputListProto = {
				//override autocomplete
				autocomplete: {
					attr: {
						get: function(){
							var elem = this;
							var data = $.data(elem, 'datalistWidget');
							if(data){
								return data._autocomplete;
							}
							return ('autocomplete' in elem) ? elem.autocomplete : elem.getAttribute('autocomplete');
						},
						set: function(value){
							var elem = this;
							var data = $.data(elem, 'datalistWidget');
							if(data){
								data._autocomplete = value;
								if(value == 'off'){
									data.hideList();
								}
							} else {
								if('autocomplete' in elem){
									elem.autocomplete = value;
								} else {
									elem.setAttribute('autocomplete', value);
								}
							}
						}
					}
				}
			};
			
//			if(formsCFG.customDatalist && (!listSupport || !('selectedOption') in $('<input />')[0])){
//				//currently not supported x-browser (FF4 has not implemented and is not polyfilled )
//				inputListProto.selectedOption = {
//					prop: {
//						writeable: false,
//						get: function(){
//							var elem = this;
//							var list = $.prop(elem, 'list');
//							var ret = null;
//							var value, options;
//							if(!list){return ret;}
//							value = $.prop(elem, 'value');
//							if(!value){return ret;}
//							options = $.prop(list, 'options');
//							if(!options.length){return ret;}
//							$.each(options, function(i, option){
//								if(value == $.prop(option, 'value')){
//									ret = option;
//									return false;
//								}
//							});
//							return ret;
//						}
//					}
//				};
//			}
			
			if(!listSupport){
				inputListProto['list'] = {
					attr: {
						get: function(){
							var val = webshims.contentAttr(this, 'list');
							return (val == null) ? undefined : val;
						},
						set: function(value){
							var elem = this;
							webshims.contentAttr(elem, 'list', value);
							webshims.objectCreate(shadowListProto, undefined, {input: elem, id: value, datalist: $.prop(elem, 'list')});
						}
					},
					initAttr: true,
					reflect: true,
					propType: 'element',
					propNodeName: 'datalist'
				};
			} else {
				//options only return options, if option-elements are rooted: but this makes this part of HTML5 less backwards compatible
				if(!($('<datalist><select><option></option></select></datalist>').prop('options') || []).length ){
					webshims.defineNodeNameProperty('datalist', 'options', {
						prop: {
							writeable: false,
							get: function(){
								var options = this.options || [];
								if(!options.length){
									var elem = this;
									var select = $('select', elem);
									if(select[0] && select[0].options && select[0].options.length){
										options = select[0].options;
									}
								}
								return options;
							}
						}
					});
				}
				inputListProto['list'] = {
					attr: {
						get: function(){
							var val = webshims.contentAttr(this, 'list');
							if(val != null){
								this.removeAttribute('list');
							} else {
								val = $.data(this, 'datalistListAttr');
							}
							
							return (val == null) ? undefined : val;
						},
						set: function(value){
							var elem = this;
							$.data(elem, 'datalistListAttr', value);
							webshims.objectCreate(shadowListProto, undefined, {input: elem, id: value, datalist: $.prop(elem, 'list')});
						}
					},
					initAttr: true,
					reflect: true,
					propType: 'element',
					propNodeName: 'datalist'
				};
			}
				
				
			webshims.defineNodeNameProperties('input', inputListProto);
			
			if($.event.customEvent){
				$.event.customEvent.updateDatalist = true;
				$.event.customEvent.updateInput = true;
				$.event.customEvent.datalistselect = true;
			} 
			webshims.addReady(function(context, contextElem){
				contextElem
					.filter('datalist > select, datalist, datalist > option, datalist > select > option')
					.closest('datalist')
					.triggerHandler('updateDatalist')
				;
				
			});
			
			
		};
		
		
		/*
		 * ShadowList
		 */
		var listidIndex = 0;
		
		var noDatalistSupport = {
			submit: 1,
			button: 1,
			reset: 1, 
			hidden: 1,
			
			//ToDo
			range: 1,
			date: 1
		};
		var lteie6 = ($.browser.msie && parseInt($.browser.version, 10) < 7);
		var globStoredOptions = {};
		var getStoredOptions = function(name){
			if(!name){return [];}
			if(globStoredOptions[name]){
				return globStoredOptions[name];
			}
			var data;
			try {
				data = JSON.parse(localStorage.getItem('storedDatalistOptions'+name));
			} catch(e){}
			globStoredOptions[name] = data || [];
			return data || [];
		};
		var storeOptions = function(name, val){
			if(!name){return;}
			val = val || [];
			try {
				localStorage.setItem( 'storedDatalistOptions'+name, JSON.stringify(val) );
			} catch(e){}
		};
		
		var getText = function(elem){
			return (elem.textContent || elem.innerText || $.text([ elem ]) || '');
		};
		
		var shadowListProto = {
			_create: function(opts){
				
				if(noDatalistSupport[$.prop(opts.input, 'type')]){return;}
				var datalist = opts.datalist;
				var data = $.data(opts.input, 'datalistWidget');
				if(datalist && data && data.datalist !== datalist){
					data.datalist = datalist;
					data.id = opts.id;
					
					data.shadowList.prop('className', 'datalist-polyfill '+ (data.datalist.className || '') + ' '+ data.datalist.id +'-shadowdom');
					if(formsCFG.positionDatalist){
						data.shadowList.insertAfter(opts.input);
					} else {
						data.shadowList.appendTo('body');
					}
					$(data.datalist)
						.off('updateDatalist.datalistWidget')
						.on('updateDatalist.datalistWidget', $.proxy(data, '_resetListCached'))
					;
					data._resetListCached();
					return;
				} else if(!datalist){
					if(data){
						data.destroy();
					}
					return;
				} else if(data && data.datalist === datalist){
					return;
				}
				listidIndex++;
				var that = this;
				this.hideList = $.proxy(that, 'hideList');
				this.timedHide = function(){
					clearTimeout(that.hideTimer);
					that.hideTimer = setTimeout(that.hideList, 9);
				};
				this.datalist = datalist;
				this.id = opts.id;
				this.hasViewableData = true;
				this._autocomplete = $.attr(opts.input, 'autocomplete');
				$.data(opts.input, 'datalistWidget', this);
				this.shadowList = $('<div class="datalist-polyfill '+ (this.datalist.className || '') + ' '+ this.datalist.id +'-shadowdom' +'" />');
				
				if(formsCFG.positionDatalist || $(opts.input).hasClass('position-datalist')){
					this.shadowList.insertAfter(opts.input);
				} else {
					this.shadowList.appendTo('body');
				}
				
				this.index = -1;
				this.input = opts.input;
				this.arrayOptions = [];
				
				this.shadowList
					.delegate('li', 'mouseenter.datalistWidget mousedown.datalistWidget click.datalistWidget', function(e){
						var items = $('li:not(.hidden-item)', that.shadowList);
						var select = (e.type == 'mousedown' || e.type == 'click');
						that.markItem(items.index(e.currentTarget), select, items);
						if(e.type == 'click'){
							that.hideList();
							if(formsCFG.customDatalist){
								$(opts.input).trigger('datalistselect');
							}
						}
						return (e.type != 'mousedown');
					})
					.on('focusout', this.timedHide)
				;
				
				opts.input.setAttribute('autocomplete', 'off');
				
				$(opts.input)
					.attr({
						//role: 'combobox',
						'aria-haspopup': 'true'
					})
					.on({
						'input.datalistWidget': function(){
							if(!that.triggeredByDatalist){
								that.changedValue = false;
								that.showHideOptions();
							}
						},
						'keydown.datalistWidget': function(e){
							var keyCode = e.keyCode;
							var activeItem;
							var items;
							if(keyCode == 40 && !that.showList()){
								that.markItem(that.index + 1, true);
								return false;
							}
							
							if(!that.isListVisible){return;}
							
							 
							if(keyCode == 38){
								that.markItem(that.index - 1, true);
								return false;
							} 
							if(!e.shiftKey && (keyCode == 33 || keyCode == 36)){
								that.markItem(0, true);
								return false;
							} 
							if(!e.shiftKey && (keyCode == 34 || keyCode == 35)){
								items = $('li:not(.hidden-item)', that.shadowList);
								that.markItem(items.length - 1, true, items);
								return false;
							} 
							if(keyCode == 13 || keyCode == 27){
								if (keyCode == 13){
									activeItem = $('li.active-item:not(.hidden-item)', that.shadowList);
									that.changeValue( $('li.active-item:not(.hidden-item)', that.shadowList) );
								}
								that.hideList();
								if(formsCFG.customDatalist && activeItem && activeItem[0]){
									$(opts.input).trigger('datalistselect');
								}
								return false;
							}
						},
						'focus.datalistWidget': function(){
							if($(this).hasClass('list-focus')){
								that.showList();
							}
						},
						'mousedown.datalistWidget': function(){
							if($(this).is(':focus')){
								that.showList();
							}
						},
						'blur.datalistWidget': this.timedHide
					})
				;
				
				
				$(this.datalist)
					.off('updateDatalist.datalistWidget')
					.on('updateDatalist.datalistWidget', $.proxy(this, '_resetListCached'))
				;
				
				this._resetListCached();
				
				if(opts.input.form && (opts.input.name || opts.input.id)){
					$(opts.input.form).on('submit.datalistWidget'+opts.input.id, function(){
						if(!$(opts.input).hasClass('no-datalist-cache') && that._autocomplete != 'off'){
							var val = $.prop(opts.input, 'value');
							var name = (opts.input.name || opts.input.id) + $.prop(opts.input, 'type');
							if(!that.storedOptions){
								that.storedOptions = getStoredOptions( name );
							}
							if(val && that.storedOptions.indexOf(val) == -1){
								that.storedOptions.push(val);
								storeOptions(name, that.storedOptions );
							}
						}
					});
				}
				$(window).on('unload.datalist'+this.id+' beforeunload.datalist'+this.id, function(){
					that.destroy();
				});
			},
			destroy: function(){
				var autocomplete = $.attr(this.input, 'autocomplete');
				$(this.input)
					.off('.datalistWidget')
					.removeData('datalistWidget')
				;
				this.shadowList.remove();
				$(document).off('.datalist'+this.id);
				$(window).off('.datalist'+this.id);
				if(this.input.form && this.input.id){
					$(this.input.form).off('submit.datalistWidget'+this.input.id);
				}
				this.input.removeAttribute('aria-haspopup');
				if(autocomplete === undefined){
					this.input.removeAttribute('autocomplete');
				} else {
					$(this.input).attr('autocomplete', autocomplete);
				}
			},
			_resetListCached: function(e){
				var that = this;
				var forceShow;
				this.needsUpdate = true;
				this.lastUpdatedValue = false;
				this.lastUnfoundValue = '';

				if(!this.updateTimer){
					if(window.QUnit || (forceShow = (e && document.activeElement == that.input))){
						that.updateListOptions(forceShow);
					} else {
						webshims.ready('WINDOWLOAD', function(){
							that.updateTimer = setTimeout(function(){
								that.updateListOptions();
								that = null;
								listidIndex = 1;
							}, 200 + (100 * listidIndex));
						});
					}
				}
			},
			maskHTML: function(str){
				return str.replace(/</g, '&lt;').replace(/>/g, '&gt;');
			},
			updateListOptions: function(_forceShow){
				this.needsUpdate = false;
				clearTimeout(this.updateTimer);
				this.updateTimer = false;
				this.shadowList
					.css({
						fontSize: $.css(this.input, 'fontSize'),
						fontFamily: $.css(this.input, 'fontFamily')
					})
				;
				this.searchStart = formsCFG.customDatalist && $(this.input).hasClass('search-start');
				
				var list = [];
				
				var values = [];
				var allOptions = [];
				var rElem, rItem, rOptions, rI, rLen, item;
				for(rOptions = $.prop(this.datalist, 'options'), rI = 0, rLen = rOptions.length; rI < rLen; rI++){
					rElem = rOptions[rI];
					if(rElem.disabled){return;}
					rItem = {
						value: $(rElem).val() || '',
						text: $.trim($.attr(rElem, 'label') || getText(rElem)),
						className: rElem.className || '',
						style: $.attr(rElem, 'style') || ''
					};
					if(!rItem.text){
						rItem.text = rItem.value;
					} else if(rItem.text != rItem.value){
						rItem.className += ' different-label-value';
					}
					values[rI] = rItem.value;
					allOptions[rI] = rItem;
				}
				
				if(!this.storedOptions){
					this.storedOptions = ($(this.input).hasClass('no-datalist-cache') || this._autocomplete == 'off') ? [] : getStoredOptions((this.input.name || this.input.id) + $.prop(this.input, 'type'));
				}
				
				this.storedOptions.forEach(function(val, i){
					if(values.indexOf(val) == -1){
						allOptions.push({value: val, text: val, className: 'stored-suggest', style: ''});
					}
				});
				
				for(rI = 0, rLen = allOptions.length; rI < rLen; rI++){
					item = allOptions[rI];
					list[rI] = '<li class="'+ item.className +'" style="'+ item.style +'" tabindex="-1" role="listitem"><span class="option-label">'+ this.maskHTML(item.text) +'</span> <span class="option-value">'+ this.maskHTML(item.value) +'</span></li>';
				}
				
				this.arrayOptions = allOptions;
				this.shadowList.html('<div class="datalist-outer-box"><div class="datalist-box"><ul role="list">'+ list.join("\n") +'</ul></div></div>');
				
				if($.fn.bgIframe && lteie6){
					this.shadowList.bgIframe();
				}
				
				if(_forceShow || this.isListVisible){
					this.showHideOptions();
				}
			},
			showHideOptions: function(_fromShowList){
				var value = $.prop(this.input, 'value').toLowerCase();
				//first check prevent infinite loop, second creates simple lazy optimization
				if(value === this.lastUpdatedValue || (this.lastUnfoundValue && value.indexOf(this.lastUnfoundValue) === 0)){
					return;
				}
				
				this.lastUpdatedValue = value;
				var found = false;
				var startSearch = this.searchStart;
				var lis = $('li', this.shadowList);
				if(value){
					this.arrayOptions.forEach(function(item, i){
						var search;
						if(!('lowerText' in item)){
							if(item.text != item.value){
								item.lowerText = item.value.toLowerCase() + item.text.toLowerCase();
							} else {
								item.lowerText = item.text.toLowerCase();
							}
						}
						search = item.lowerText.indexOf(value);
						search = startSearch ? !search : search !== -1;
						if(search){
							$(lis[i]).removeClass('hidden-item');
							found = true;
						} else {
							$(lis[i]).addClass('hidden-item');
						}
					});
				} else if(lis.length) {
					lis.removeClass('hidden-item');
					found = true;
				}
				
				this.hasViewableData = found;
				if(!_fromShowList && found){
					this.showList();
				}
				if(!found){
					this.lastUnfoundValue = value;
					this.hideList();
				}
			},
			setPos: function(){
				this.shadowList.css({marginTop: 0, marginLeft: 0, marginRight: 0, marginBottom: 0});
				var css = (formsCFG.positionDatalist) ? $(this.input).position() : webshims.getRelOffset(this.shadowList, this.input);
				css.top += $(this.input).outerHeight();
				css.width = $(this.input).outerWidth() - (parseInt(this.shadowList.css('borderLeftWidth'), 10)  || 0) - (parseInt(this.shadowList.css('borderRightWidth'), 10)  || 0);
				this.shadowList.css({marginTop: '', marginLeft: '', marginRight: '', marginBottom: ''}).css(css);
				return css;
			},
			showList: function(){
				if(this.isListVisible){return false;}
				if(this.needsUpdate){
					this.updateListOptions();
				}
				this.showHideOptions(true);
				if(!this.hasViewableData){return false;}
				this.isListVisible = true;
				var that = this;
				
				that.setPos();
				that.shadowList.addClass('datalist-visible').find('li.active-item').removeClass('active-item');
				
				$(window).unbind('.datalist'+that.id);
				$(document)
					.off('.datalist'+that.id)
					.on('mousedown.datalist'+that.id +' focusin.datalist'+that.id, function(e){
						if(e.target === that.input ||  that.shadowList[0] === e.target || $.contains( that.shadowList[0], e.target )){
							clearTimeout(that.hideTimer);
							setTimeout(function(){
								clearTimeout(that.hideTimer);
							}, 9);
						} else {
							that.timedHide();
						}
					})
					.on('updateshadowdom.datalist'+that.id, function(){
						that.setPos();
					})
				;
				return true;
			},
			hideList: function(){
				if(!this.isListVisible){return false;}
				var that = this;
				var triggerChange = function(e){
					if(that.changedValue){
						$(that.input).trigger('change');
					}
					that.changedValue = false;
				};
				
				that.shadowList.removeClass('datalist-visible list-item-active');
				that.index = -1;
				that.isListVisible = false;
				if(that.changedValue){
					that.triggeredByDatalist = true;
					webshims.triggerInlineForm && webshims.triggerInlineForm(that.input, 'input');
					if($(that.input).is(':focus')){
						$(that.input).one('blur', triggerChange);
					} else {
						triggerChange();
					}
					that.triggeredByDatalist = false;
				}
				$(document).unbind('.datalist'+that.id);
				$(window)
					.off('.datalist'+that.id)
					.one('resize.datalist'+that.id, function(){
						that.shadowList.css({top: 0, left: 0});
					})
				;
				return true;
			},
			scrollIntoView: function(elem){
				var ul = $('ul', this.shadowList);
				var div = $('div.datalist-box', this.shadowList);
				var elemPos = elem.position();
				var containerHeight;
				elemPos.top -=  (parseInt(ul.css('paddingTop'), 10) || 0) + (parseInt(ul.css('marginTop'), 10) || 0) + (parseInt(ul.css('borderTopWidth'), 10) || 0);
				if(elemPos.top < 0){
					div.scrollTop( div.scrollTop() + elemPos.top - 2);
					return;
				}
				elemPos.top += elem.outerHeight();
				containerHeight = div.height();
				if(elemPos.top > containerHeight){
					div.scrollTop( div.scrollTop() + (elemPos.top - containerHeight) + 2);
				}
			},
			changeValue: function(activeItem){
				if(!activeItem[0]){return;}
				var newValue = $('span.option-value', activeItem).text();
				var oldValue = $.prop(this.input, 'value');
				if(newValue != oldValue){
					$(this.input)
						.prop('value', newValue)
						.triggerHandler('updateInput')
					;
					this.changedValue = true;
				}
			},
			markItem: function(index, doValue, items){
				var activeItem;
				var goesUp;
				
				items = items || $('li:not(.hidden-item)', this.shadowList);
				if(!items.length){return;}
				if(index < 0){
					index = items.length - 1;
				} else if(index >= items.length){
					index = 0;
				}
				items.removeClass('active-item');
				this.shadowList.addClass('list-item-active');
				activeItem = items.filter(':eq('+ index +')').addClass('active-item');
				
				if(doValue){
					this.changeValue(activeItem);
					this.scrollIntoView(activeItem);
				}
				this.index = index;
			}
		};
		
		//init datalist update
		initializeDatalist();
	})();
	
});