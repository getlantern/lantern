(function($){
	//always load jquery ui
	$.webshims.loader.loadList(['jquery-ui']);
	$.webshims.ready('DOM jquery-ui', function(){
		if(!window.console){
			window.console = {log: $.noop};
		}
		if(!$.browser.msie || parseInt($.browser.version, 10) > 7){
			$('code.run-once').each(function(){
				var elem = this;
				$('<button>run example</button>').insertAfter(elem).click(function(){
					eval(elem.innerHTML.replace(/&gt;/g, '>').replace(/&lt;/g, '<'));
					this.disabled = true;
					return false;
				});
			});
			
		}
		
		
		$('div.feature-example').each(function(){
			var div = $('div.hidden-explanation', this).hide();
			$('button', this).bind('click', function(){
				$('#placeholder').attr('placeholder', $('#placeholder-text').val());
				div.slideDown();
				return false;
			});
		});
		$(function(){
			if($.fn.accordion){
				var hash = (location.hash || '').replace(/^#/, '');
				$('div.accordion')
					.each(function(){
						var accordion = this;
						var headers = $('h3.button', this);
						var selected = (hash) ? headers.filter('[id="'+hash+'"]') : 0;
						if(selected && selected[0]){
							var selElem = selected[0];
							setTimeout(function(){
								selElem.scrollIntoView();
							}, 0);
							selected = headers.index(selected[0]);
						}
						
						$(this).accordion({
							header: 'h3.button',
							active: selected,
							autoHeight: false
						});
						$(window).bind('hashchange', function(){
							hash = (location.hash || '').replace(/^#/, '');
							selected = headers.filter('[id="'+hash+'"]');
							if(selected[0]){
								$(accordion).accordion("option", "animated", false).accordion('activate', headers.index(selected[0])).accordion("option", "animated", "slide");
								setTimeout(function(){
									selected[0].scrollIntoView();
								}, 1);
							}
						});
					})
				;
			}
		});
	});
})(jQuery);
(function($){
	var remove;
	var regStart = /\/\/<([A-Za-z]+)/;
	var regEnd = /\/\/>/;
	var webshimsBuilder = {
		data: null,
		init: function(form){
			$.webshims.ready('DOM es5', function(){
				$(form).each(function(){
					webshimsBuilder.getData(this.getAttribute("data-polyfillpath"));
					var dependentChecked = function(id){
						$('#'+id).prop('checked', true).prop('disabled', true);
					};
					var dependentUnChecked = function(id){
						$('#'+id).prop('disabled', false);
					};
					var form = this;
					$('fieldset.config', this)
						.delegate('input[data-dependent]', 'click cfginit', function(){
							$.attr(this, 'data-dependent').split(" ").forEach( $.prop(this, 'checked') ? dependentChecked : dependentUnChecked );
						})
						
					;
					
					$(this)
						.delegate('input[type="checkbox"]', 'click cfginit', (function(){
							var timer;
							var modLink = $('a.modernizr-builder', form);
							var base = modLink.data('base');
							return function(){
								clearTimeout(timer);
								timer = setTimeout(function(){
									var mods = [];
									var add = '';
									$('input[data-mod]:checked', form).each(function(){
										$.merge(mods, ($(this).data('mod') || '').split(' '));
									});
									add = mods.length ? '-'+ (mods.join('-')) : '';
									$('code.modernizr-output', form).html(add);
									modLink.attr('href', base + add); 
								}, 0);
							};
						})())
						.find('input[data-dependent]')
						.trigger('cfginit')
					;
					
					$(this).bind('submit', function(e){
						var buildFeatures = [];
						var removeFeatures = [];
						
						$('fieldset.config input:not(:disabled)[id]', this).each(function(checkbox){
							var id = $.prop(this, 'id');
							if($.prop(this, 'checked')){
								buildFeatures.push(id);
							} else {
								$.merge(removeFeatures, $(this).data('features') || [id]);
							}
							
						});
						webshimsBuilder.buildScript(buildFeatures, removeFeatures, $('textarea[name="js_code"]', this));
					});
				});
			});
		},
		getData: function(path){
			
			$.ajax(path, {
				dataType: 'text',
				success: function(data){
					webshimsBuilder.data = data;
				}
			});
		},
		getRemoveCombos: function(removeFeatures){
			var combos = [];
			var removeModules = [];
			$.each(removeFeatures, function(i, feature){
				$.merge(removeModules, $.webshims.features[feature]);
			});
			$.each($.webshims.c, function(c, modules){
				$.each(modules, function(i, module){
					if($.inArray(module, removeModules) !== -1){
						combos.push(c);
						return false;
					}
				});
			});
			return combos;
		},
		buildScript: function(features, removeFeatures, output){
			var result = [];
			var combos = webshimsBuilder.getRemoveCombos(removeFeatures);
			var data = webshimsBuilder.data.replace(/\t/g, "").split(/[\n\r]/g);
			
			data.forEach(function(line){
				var foundFeature;
				var featureCombo;
				
				if(remove){
					remove = !(regEnd.exec(line));
				} else if( !line || !(foundFeature = regStart.exec(line)) || $.inArray(foundFeature[1], features) !== -1 ){
					if(combos.length && line.indexOf("removeCombos") != -1){
						line = line.replace(/\/\/>removeCombos</, "removeCombos = removeCombos.concat(["+ combos.join(",") +"]);" );
					}
					result.push(line);
				} else if(foundFeature){
					
					remove = true;
				}
			});
			
			$(output).val(result.join("\n"));
		}
	};
	
	webshimsBuilder.init('form[data-polyfillpath]');
})(jQuery);