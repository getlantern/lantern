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