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