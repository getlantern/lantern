//
// List of inline elements, br is left out deliberatly so it is treated as block
// level element. Spaces around br elements are redundant.
//
exports.inline = [
  'a', 'abbr', 'b', 'bdo', 'button', 'cite',
  'code', 'dfn', 'em', 'i', 'img', 'input', 'kbd',
  'label', 'q', 's', 'samp', 'small', 'span', 'strong',
  'sub', 'sup', 'textarea', 'var'
];

//
// List of singular elements, e.g. elements that have no closing tag.
//
exports.singular = [
  'area', 'base', 'br', 'col', 'command', 'embed', 'hr',
  'img', 'input', 'link', 'meta', 'param', 'source'
];

//
// List of redundant attributes, e.g. boolean attributes that require no value.
//
exports.redundant = [
  'autofocus', 'disabled', 'multiple', 'required', 'readonly', 'hidden',
  'async', 'defer', 'formnovalidate', 'checked', 'scoped', 'reversed',
  'selected', 'autoplay', 'controls', 'loop', 'muted', 'seamless',
  'default', 'ismap', 'novalidate', 'open', 'typemustmatch', 'truespeed',
  'itemscope', 'autocomplete'
];

//
// Elements that have special content, e.g. JS or CSS.
//
exports.node = [ 'tag', 'script', 'style' ];

//
// Elements that require and should keep structure to their content.
//
exports.structural = [ 'pre', 'textarea', 'code' ];

//
// Attribute table, global attributes like `hidden` and `id` are not
// included as these attributes require no additional checks.
//
exports.attributes = {
  'hidden': '*',
  'high': 'meter',
  'href': ['a', 'area', 'base', 'link'],
  'hreflang': ['a', 'area', 'link'],
  'http-equiv': 'meta',
  'icon': 'command',
  'id': '*',
  'ismap': 'img',
  'itemprop': '*',
  'itemscope': '*',
  'keytype': 'keygen',
  'kind': 'track',
  'label': 'track',
  'lang': '*',
  'language': 'script',
  'list': 'input',
  'loop': ['audio', 'bgsound', 'marquee', 'video'],
  'low': 'meter',
  'manifest': 'html',
  'max': ['input', 'meter', 'progress'],
  'maxlength': ['input', 'textarea'],
  'media': ['a', 'area', 'link', 'source', 'style'],
  'method': 'form',
  'min': ['input', 'meter'],
  'multiple': ['input', 'select'],
  'name': ['button', 'form', 'fieldset', 'iframe', 'input', 'keygen', 'object', 'output', 'select', 'textarea', 'map', 'meta', 'param'],
  'novalidate': 'form',
  'open': 'details',
  'optimum': 'meter',
  'pattern': 'input',
  'ping': ['a', 'area'],
  'placeholder': ['input', 'textarea'],
  'poster': 'video',
  'preload': ['audio', 'video'],
  'pubdate': 'time',
  'radiogroup': 'command',
  'readonly': ['input', 'textarea'],
  'rel': ['a', 'area', 'link'],
  'required': ['input', 'select', 'textarea'],
  'reversed': 'ol',
  'rows': 'textarea',
  'rowspan': ['td', 'th'],
  'sandbox': 'iframe',
  'spellcheck': '*',
  'scope': 'th',
  'scoped': 'style',
  'seamless': 'iframe',
  'selected': 'option',
  'shape': ['a', 'area'],
  'size': ['input', 'select'],
  'sizes': 'link',
  'span': ['col', 'colgroup'],
  'src': ['audio', 'embed', 'iframe', 'img', 'input', 'script', 'source', 'track', 'video'],
  'srcdoc': 'iframe',
  'srclang': 'track',
  'srcset': 'img',
  'start': 'ol',
  'step': 'input',
  'style': '*',
  'summary': 'table',
  'tabindex': '*',
  'target': ['a', 'area', 'base', 'form'],
  'title': '*',
  'type': ['button', 'input', 'command', 'embed', 'object', 'script', 'source', 'style', 'menu'],
  'usemap': ['img',  'input', 'object'],
  'value': ['button', 'option', 'input', 'li', 'meter', 'progress', 'param'],
  'width': ['canvas', 'embed', 'iframe', 'img', 'input', 'object', 'video'],
  'wrap': 'textarea',
  'border': ['img', 'object', 'table'],
  'buffered': ['audio', 'video'],
  'challenge': 'keygen',
  'charset': ['meta', 'script'],
  'checked': ['command', 'input'],
  'cite': ['blockquote', 'del', 'ins', 'q'],
  'class': '*',
  'code': 'applet',
  'codebase': 'applet',
  'color': ['basefont', 'font', 'hr'],
  'cols': 'textarea',
  'colspan': ['td', 'th'],
  'content': ['meta'],
  'contenteditable': '*',
  'contextmenu': '*',
  'controls': ['audio', 'video'],
  'coords': ['area'],
  'data': 'object',
  'datetime': ['del', 'ins', 'time'],
  'default': 'track',
  'defer': 'script',
  'dir': '*',
  'dirname': ['input', 'textarea'],
  'disabled': ['button', 'command', 'fieldset', 'input', 'keygen', 'optgroup', 'option', 'select', 'textarea'],
  'download': ['a', 'area'],
  'draggable': '*',
  'dropzone': '*',
  'enctype': 'form',
  'for': ['label', 'output'],
  'form': ['button', 'fieldset', 'input', 'keygen', 'label', 'meter', 'object', 'output', 'progress', 'select', 'textarea'],
  'formaction': ['input', 'button'],
  'headers': ['td', 'th'],
  'height': ['canvas', 'embed', 'iframe', 'img', 'input', 'object', 'video'],
  'accept': ['form', 'input'],
  'accept-charset': 'form',
  'accesskey': '*',
  'action': 'form',
  'align': ['applet', 'caption', 'col', 'colgroup',  'hr', 'iframe', 'img', 'table', 'tbody',  'td',  'tfoot' , 'th', 'thead', 'tr'],
  'alt': ['applet', 'area', 'img', 'input'],
  'async': 'script',
  'autocomplete': ['form', 'input'],
  'autofocus': ['button', 'input', 'keygen', 'select', 'textarea'],
  'autoplay': ['audio', 'video'],
  'autosave': 'input',
  'bgcolor': ['body', 'col', 'colgroup', 'marquee', 'table', 'tbody', 'tfoot', 'td', 'th', 'tr']
};