
//JSON
(function(){
if('JSON'in window && JSON.stringify && JSON.parse){return;}

if(!this.JSON){this.JSON={};}(function(){function f(n){return n<10?'0'+n:n;}if(typeof Date.prototype.toJSON!=='function'){Date.prototype.toJSON=function(key){return isFinite(this.valueOf())?this.getUTCFullYear()+'-'+f(this.getUTCMonth()+1)+'-'+f(this.getUTCDate())+'T'+f(this.getUTCHours())+':'+f(this.getUTCMinutes())+':'+f(this.getUTCSeconds())+'Z':null;};String.prototype.toJSON=Number.prototype.toJSON=Boolean.prototype.toJSON=function(key){return this.valueOf();};}var cx=/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,escapable=/[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,gap,indent,meta={'\b':'\\b','\t':'\\t','\n':'\\n','\f':'\\f','\r':'\\r','"':'\\"','\\':'\\\\'},rep;function quote(string){escapable.lastIndex=0;return escapable.test(string)?'"'+string.replace(escapable,function(a){var c=meta[a];return typeof c==='string'?c:'\\u'+('0000'+a.charCodeAt(0).toString(16)).slice(-4);})+'"':'"'+string+'"';}function str(key,holder){var i,k,v,length,mind=gap,partial,value=holder[key];if(value&&typeof value==='object'&&typeof value.toJSON==='function'){value=value.toJSON(key);}if(typeof rep==='function'){value=rep.call(holder,key,value);}switch(typeof value){case'string':return quote(value);case'number':return isFinite(value)?String(value):'null';case'boolean':case'null':return String(value);case'object':if(!value){return'null';}gap+=indent;partial=[];if(Object.prototype.toString.apply(value)==='[object Array]'){length=value.length;for(i=0;i<length;i+=1){partial[i]=str(i,value)||'null';}v=partial.length===0?'[]':gap?'[\n'+gap+partial.join(',\n'+gap)+'\n'+mind+']':'['+partial.join(',')+']';gap=mind;return v;}if(rep&&typeof rep==='object'){length=rep.length;for(i=0;i<length;i+=1){k=rep[i];if(typeof k==='string'){v=str(k,value);if(v){partial.push(quote(k)+(gap?': ':':')+v);}}}}else{for(k in value){if(Object.hasOwnProperty.call(value,k)){v=str(k,value);if(v){partial.push(quote(k)+(gap?': ':':')+v);}}}}v=partial.length===0?'{}':gap?'{\n'+gap+partial.join(',\n'+gap)+'\n'+mind+'}':'{'+partial.join(',')+'}';gap=mind;return v;}}if(typeof JSON.stringify!=='function'){JSON.stringify=function(value,replacer,space){var i;gap='';indent='';if(typeof space==='number'){for(i=0;i<space;i+=1){indent+=' ';}}else if(typeof space==='string'){indent=space;}rep=replacer;if(replacer&&typeof replacer!=='function'&&(typeof replacer!=='object'||typeof replacer.length!=='number')){throw new Error('JSON.stringify');}return str('',{'':value});};}if(typeof JSON.parse!=='function'){JSON.parse=function(text,reviver){var j;function walk(holder,key){var k,v,value=holder[key];if(value&&typeof value==='object'){for(k in value){if(Object.hasOwnProperty.call(value,k)){v=walk(value,k);if(v!==undefined){value[k]=v;}else{delete value[k];}}}}return reviver.call(holder,key,value);}text=String(text);cx.lastIndex=0;if(cx.test(text)){text=text.replace(cx,function(a){return'\\u'+('0000'+a.charCodeAt(0).toString(16)).slice(-4);});}if(/^[\],:{}\s]*$/.test(text.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,'@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,']').replace(/(?:^|:|,)(?:\s*\[)+/g,''))){j=eval('('+text+')');return typeof reviver==='function'?walk({'':j},''):j;}throw new SyntaxError('JSON.parse');};}}());

})();

//modified version from http://gist.github.com/350433
//using window.name for sessionStorage and cookies for localStorage

(function () {
var $ = jQuery;	
if ('localStorage' in window && 'sessionStorage' in window) {
	$.webshims.isReady('json-storage', true);
	return;
}


var storageNameError = function(name){
	if(name && name.indexOf && name.indexOf(';') != -1){
		setTimeout(function(){
			$.webshims.warn("Bad key for localStorage: ; in localStorage. name was: "+ name);
		}, 0);
	}
};
var winData;
var selfWindow = false;
$.each(['opener', 'top', 'parent'], function(i, name){
	try {
		winData = window[name];
		if(winData && 'name' in winData){
			var test = winData.name;
			return false;
		} else {
			winData = false;
		}
	} catch(e){
		winData = false;
	}
});
if(!winData){
	winData = window;
	selfWindow = true;
}
var setWindowData = function(data){
	if(!selfWindow){
		try {
			window.name = data;
		} catch(e){}
	}
	try {
		winData.name = data;
	} catch(e){
		winData = window;
		selfWindow = true;
	}
};
var getWindowData = function(){
	var data;
	if(!selfWindow){
		try {
			data = window.name;
		} catch(e){}
	}
	if(!data){
		try {
			data = winData.name;
		} catch(e){
			winData = window;
			selfWindow = true;
		}
	}
	return data;
};
var Storage = function (type) {
	function createCookie(name, value, days) {
		var date, expires;
		
		if (days) {
			date = new Date();
			date.setTime(date.getTime()+(days*24*60*60*1000));
			expires = "; expires="+date.toGMTString();
		} else {
			expires = "";
		}
		document.cookie = name+"="+value+expires+"; path=/";
	}
	
	function readCookie(name) {
		var nameEQ = name + "=",
			ca = document.cookie.split(';'),
			i, c;
		
		for (i=0; i < ca.length; i++) {
			c = ca[i];
			while (c.charAt(0)==' ') {
				c = c.substring(1,c.length);
			}
			
			if (c.indexOf(nameEQ) === 0) {
				return c.substring(nameEQ.length,c.length);
			}
		}
		return null;
	}
	
	function setData(data) {
		data = JSON.stringify(data);
		if (type == 'session') {
			setWindowData(data);
		} else {
			createCookie('localStorage', data, 365);
		}
	}
	
	function clearData() {
		if (type == 'session') {
			setWindowData('');
		} else {
			createCookie('localStorage', '', 365);
		}
	}
	
	function getData() {
		var data;
		if(type == 'session'){
			data = getWindowData();
		} else {
			data = readCookie('localStorage');
		}
		if(data){
			try {
				data = JSON.parse(data);
			} catch(e){
				data = {};
			}
		}
		return data || {};
	}
	
	
	// initialise if there's already data
	var data = getData();
	
	return {
		clear: function () {
			data = {};
			clearData();
		},
		getItem: function (key) {
			return (key in data) ? data[key] : null;
		},
		key: function (i) {
			// not perfect, but works
			var ctr = 0;
			for (var k in data) {
				if (ctr == i) {
					return k;
				} else {
					ctr++;
				}
			}
			return null;
		},
		removeItem: function (key) {
			delete data[key];
			setData(data);
		},
		setItem: function (key, value) {
			storageNameError(key);
			data[key] = value+''; // forces the value to a string
			setData(data);
		}
	};
};



if (!('sessionStorage' in window)) {window.sessionStorage = new Storage('session');}



(function(){
	var swfTimer;
	var emptyString = '(empty string)+1287520303738';
	var runStart;
	var shim;
	var localStorageSwfCallback = function(type){
		clearTimeout(swfTimer);
		
		if(window.localStorage && (type != 'swf' || (shim && shim.key))){
			$.webshims.isReady('json-storage', true);
			return;
		}

		if(type === 'swf'){
			shim = document.getElementById('swflocalstorageshim');
			//brute force flash getter
			if( !shim || typeof shim.GetVariable == 'undefined' ){
				shim = document.swflocalstorageshim;
			}
			if( !shim || typeof shim.GetVariable == 'undefined'){
				shim = window.localstorageshim;
			}
			
			if(shim && typeof shim.GetVariable !== 'undefined'){
				window.localStorage = {};
				
				window.localStorage.clear = function(){
					if(shim.clear){shim.clear();}
				};
				window.localStorage.key = function(i){
					if(shim.key){shim.key(i);}
				};
				window.localStorage.removeItem = function(name){
					if(shim.removeItem){shim.removeItem(name);}
				};
				
				window.localStorage.setItem = function(name, val){
					storageNameError(name);
					val += '';
					if(!val){
						val = emptyString;
					}
					if(shim.setItem){
						shim.setItem(name, val);
					}
				};
				window.localStorage.getItem = function(name){
					if(!shim.getItem){
						return null;
					}
					var val = shim.getItem(name, val);
					if(val == emptyString){
						val = '';
					}
					return val;
				};
				$.webshims.log('flash-localStorage was implemented');
			}
		}
		if(!('localStorage' in window)){
			window.localStorage = new Storage('local');
			$.webshims.warn('implement cookie-localStorage');
		}
		
		$.webshims.isReady('json-storage', true);
	};
	var storageCFG = $.webshims.cfg['json-storage'];
	$.webshims.swfLocalStorage = {
		show: function(){
			if(storageCFG.exceededMessage){
				$('#swflocalstorageshim-wrapper').prepend('<div class="polyfill-exceeded-message">'+ storageCFG.exceededMessage +'</div>');
			}
			$('#swflocalstorageshim-wrapper').css({
				top: $(window).scrollTop() + 20,
				left: ($(window).width() / 2) - ($('#swflocalstorageshim-wrapper').outerWidth() / 2)
			});
			
		},
		hide: function(success){
			$('#swflocalstorageshim-wrapper')
				.css({top: '', left: ''})
				.find('div.polyfill-exceeded-message')
				.remove()
			;
			if(!success){
				var err = new Error('DOMException: QUOTA_EXCEEDED_ERR');
				err.code = 22;
				err.name = 'DOMException';
				throw(err);
			}
		},
		isReady: localStorageSwfCallback
	};
	
//	$.webshims.swfLocalStorage.storageEvent = function(newVal, oldVal, url){
//		
//	};
	
	$.webshims.ready('DOM swfobject', function(){
		if(runStart || (('localStorage' in window) && document.getElementById('swflocalstorageshim')) ){return;}
		runStart = true;
		if(window.swfobject && swfobject.hasFlashPlayerVersion('8.0.0')){
			$('body')[$.browser.mozilla ? 'after' : 'append']('<div id="swflocalstorageshim-wrapper"><div id="swflocalstorageshim" /></div>');
			swfobject.embedSWF($.webshims.cfg.basePath +'swf/localStorage.swf' +($.webshims.cfg.addCacheBuster || ''), 'swflocalstorageshim', '295', '198', '8.0.0', '', {allowscriptaccess: 'always'}, {name: 'swflocalstorageshim'}, function(e){
				if(!e.success && !window.localStorage){
					localStorageSwfCallback();
				}
			});
			clearTimeout(swfTimer);
			swfTimer = setTimeout(function(){
				if(!('localStorage' in window)){
					$.webshims.warn('Add your development-directory to the local-trusted security sandbox: http://www.macromedia.com/support/documentation/en/flashplayer/help/settings_manager04.html');
				}
				localStorageSwfCallback();
			}, (location.protocol.indexOf('file') === 0) ? 500 : 9999);
		} else {
			localStorageSwfCallback();
		}
	});
})();


})();

