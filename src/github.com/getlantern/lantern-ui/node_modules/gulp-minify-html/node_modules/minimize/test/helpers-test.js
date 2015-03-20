/*global beforeEach, afterEach*/
'use strict';

var chai = require('chai')
  , sinon = require('sinon')
  , sinonChai = require('sinon-chai')
  , expect = chai.expect
  , Helpers = require('../lib/helpers')
  , list = require('../lib/list')
  , helpers = new Helpers()
  , html = require('./fixtures/html.json');

chai.use(sinonChai);
chai.config.includeStack = true;

describe('Helpers', function () {
  describe('is a module', function () {
    it('which has a function tag', function () {
      expect(helpers).to.have.property('tag');
      expect(helpers.tag).to.be.a('function');
    });

    it('which has a function close', function () {
      expect(helpers).to.have.property('close');
      expect(helpers.close).to.be.a('function');
    });

    it('which has a function text', function () {
      expect(helpers).to.have.property('text');
      expect(helpers.text).to.be.a('function');
    });

    it('which has a function isJS', function () {
      expect(helpers).to.have.property('isJS');
      expect(helpers.isJS).to.be.a('function');
    });

    it('which has a function isStyle', function () {
      expect(helpers).to.have.property('isStyle');
      expect(helpers.isStyle).to.be.a('function');
    });

    it('which has a function structure', function () {
      expect(helpers).to.have.property('structure');
      expect(helpers.structure).to.be.a('function');
    });

    it('which has a function isInline', function () {
      expect(helpers).to.have.property('isInline');
      expect(helpers.isInline).to.be.a('function');
    });

    it('which has a function comment', function () {
      expect(helpers).to.have.property('comment');
      expect(helpers.comment).to.be.a('function');
    });

    it('which has an array named node', function () {
      expect(list).to.have.property('node');
      expect(list.node).to.be.an('array');
    });

    it('which has an named redundant', function () {
      expect(list).to.have.property('redundant');
      expect(list.redundant).to.be.an('array');
    });

    it('which has a regular expression named structural', function () {
      expect(list).to.have.property('structural');
      expect(list.structural).to.be.an('array');
    });

    it('which has an inline element reference', function () {
      expect(list).to.have.property('inline');
      expect(list.inline).to.be.an('array');
    });

    it('which has an singular element reference', function () {
      expect(list).to.have.property('singular');
      expect(list.singular).to.be.an('array');
    });

    it('which has a default config', function () {
      expect(helpers).to.have.property('config');
      expect(helpers.config).to.be.an('object');
    });
  });

  describe('#directive', function () {
    it('returns a string wrapped with < >', function () {
      expect(helpers.directive(html.doctype)).to.be.equal('<!doctype html>');
    });
  });

  describe('#attributes', function () {
    var quote;

    beforeEach(function () {
      quote = sinon.spy(helpers, 'quote');
    });

    afterEach(function () {
      quote.restore();
      html.block.attribs = null;
    });

    it('should convert the attribute object to string', function () {
      expect(helpers.attributes(html.singular)).to.be.equal(' type=text name=temp');
      expect(quote).to.be.calledTwice;
    });

    it('should return early if element has no attributes', function () {
      expect(helpers.attributes(html.block)).to.be.equal('');
      expect(quote.callCount).to.be.equal(0);
    });

    it('should remove attributes that are empty, not boolean and are allowed on the element', function () {
      html.block.attribs = { disabled: 'disabled' };
      expect(helpers.attributes(html.block)).to.be.equal(' disabled=disabled');
      html.block.attribs = { autofocus: '' };
      expect(helpers.attributes(html.block)).to.be.equal(' autofocus=""');
      html.block.attribs = { loop: 'random' };
      expect(helpers.attributes(html.block)).to.not.equal(' loop');
      expect(helpers.attributes(html.block)).to.be.equal(' loop=random');
      html.block.attribs = { class: 'true' };
      expect(helpers.attributes(html.block)).to.be.equal(' class=true');
      html.block.attribs = { hidden: 'true' };
      expect(helpers.attributes(html.block)).to.be.equal(' hidden');
      expect(quote.callCount).to.be.equal(5);
    });

    it('should retain empty schemantic and data attributes', function () {
      html.block.attribs = { 'data-type': '' };
      expect(helpers.attributes(html.block)).to.be.equal(' data-type');
      html.block.attribs = { 'itemscope': '' };
      expect(helpers.attributes(html.block)).to.be.equal(' itemscope');
      expect(quote.callCount).to.be.equal(0);
    });

    it('should remove mutliple white spaces and newlines in attribute values', function () {
      html.block.attribs = {
        'class': 'some value \n\r  with mutliple   \n spaces and \r    newlines'
      };

      expect(helpers.attributes(html.block)).to.equal(
        ' class="some value with mutliple spaces and newlines"'
      );
    });
  });

  describe('#quote', function () {
    var quote;

    beforeEach(function () {
      quote = sinon.spy(helpers, 'quote');
    });

    afterEach(function () {
      quote.restore();
    });


    it('should omit quotes if an attribute does not require any', function () {
      expect(helpers.quote(html.attribs.href)).to.be.equal('http://without.params.com');
      expect(helpers.quote(html.attribs.name)).to.be.equal('temp-name');
      expect(helpers.quote(html.attribs.type)).to.be.equal('text');
    });

    it('should always quote an attribute ending with /', function () {
      expect(helpers.quote('path/')).to.be.equal('"path/"');
    });

    it('should add quotes to attributes with spaces or =', function () {
      expect(helpers.quote(html.attribs.class)).to.be.equal('"some classes with spaces"');
      expect(helpers.quote(html.attribs.hrefparam)).to.be.equal('"http://with.params.com?test=test"');
    });

    it('should always retain quotes if configured', function () {
      var configurable = new Helpers({ quotes: true });
      expect(configurable.quote(html.attribs.name)).to.be.equal('"temp-name"');
      expect(configurable.quote(html.attribs.type)).to.be.equal('"text"');
      expect(configurable.quote(html.attribs.class)).to.be.equal('"some classes with spaces"');
    });
  });

  describe('#tag', function () {
    var structure, attr;

    beforeEach(function () {
      structure = sinon.spy(helpers, 'structure');
      attr = sinon.spy(helpers, 'attributes');
    });

    afterEach(function () {
      structure.restore();
      attr.restore();
    });

    it('returns a string wrapped with < >', function () {
      expect(helpers.tag(html.block)).to.be.equal('<section>');

      expect(structure).to.be.calledOnce;
    });

    it('calls helpers#attributes once and appends content behind name', function () {
      expect(helpers.tag(html.singular)).to.be.equal('<input type=text name=temp>');

      expect(attr).to.be.calledAfter(structure);
      expect(attr).to.be.calledOnce;
    });

    it('is callable by element.type through proxy', function () {
      expect(helpers.script(html.script, '')).to.be.equal(
        '<script type=text/javascript>'
      );

      expect(structure).to.be.calledOnce;
    });
  });

  describe('#isInline', function () {
    it('returns true if inline element <strong>', function () {
      expect(helpers.isInline(html.inline)).to.be.true;
    });

    it('returns false if block element <html>', function () {
      expect(helpers.isInline(html.element)).to.be.false;
    });

    it('returns type Boolean', function () {
      expect(helpers.isInline(html.inline)).to.be.a('boolean');
    });
  });

  describe('#close', function () {
    var structure;

    beforeEach(function () {
      structure = sinon.spy(helpers, 'structure');
    });

    afterEach(function () {
      structure.restore();
    });

    it('only generates closing element for tags and scripts', function () {
      var result = helpers.close(html.doctype);

      expect(result).to.equal('');
      expect(result).to.be.a('string');
      expect(result.length).to.equal(0);
      expect(structure).to.be.calledOnce;
    });

    it('returns a string wrapped with </ >', function () {
      var result = helpers.close(html.element);

      expect(result).to.equal('</html>');
      expect(result).to.be.a('string');
      expect(structure).to.be.calledOnce;
    });

    it('returns an empty string if element.type is wrong', function () {
      var result = helpers.close(html.singular);

      expect(result).to.equal('');
      expect(result).to.be.a('string');
      expect(result.length).to.equal(0);
      expect(structure).to.be.calledOnce;
    });
  });

  describe('#isStyle', function () {
    it('returns true if an element is of type style', function () {
      expect(helpers.isStyle(html.style)).to.be.true;
    });
  });

  describe('#isJS', function () {
    afterEach(function () {
      html.script.name = 'script';
      html.script.attribs = { type: 'text/javascript' }
    });

    it('returns false if element is not of type script', function () {
      expect(helpers.isJS(html.inline)).to.be.false;
    });

    it('returns true if type is script and has no attributes', function () {
      html.script.attribs = {};
      expect(helpers.isJS(html.script)).to.be.true;
    });

    it('returns true if type is script and has random attributes', function () {
      html.script.attribs = { 'data-type': 'test' };
      expect(helpers.isJS(html.script)).to.be.true;
    });

    it('returns true if type is script and attribute === "text/javascript"', function () {
      expect(helpers.isJS(html.script)).to.be.true;
    });

    it('returns false if type !== "text/javascript"', function () {
      html.script.attribs.type = 'text/template';
      expect(helpers.isJS(html.script)).to.be.false;
    });

    it('returns type Boolean', function () {
      expect(helpers.isJS(html.element)).to.be.a('boolean');
    });
  });

  describe('#structure', function () {
    it('returns false if element is text', function () {
      expect(helpers.structure(html.text)).to.be.false;
    });

    it('returns true if element is textarea', function () {
      expect(helpers.structure(html.structure)).to.be.true;
    });

    it('returns true if element is script of type text/javascript', function () {
      var isJS = sinon.spy(helpers, 'isJS');

      expect(helpers.structure(html.script)).to.be.true;
      expect(isJS).to.be.calledOnce;

      isJS.restore();
    });

    it('returns false if element requires no structure', function () {
      expect(helpers.structure(html.element)).to.be.false;
    });

    it('returns type Boolean', function () {
      expect(helpers.structure(html.element)).to.be.a('boolean');
    });
  });

  describe('#comment', function () {
    it('surrounds text with comment directives', function () {
      var local = new Helpers({ comments: true });
      expect(local.comment({ data: 'test' })).to.be.a('string');
      expect(local.comment({ data: 'test' })).to.equal('<!--test-->');
    });

    it('returns empty string by default', function () {
      var result = helpers.comment({ data: 'test' });
      expect(result).to.be.a('string');
      expect(result).to.equal('');
    });
  });

  describe('#text', function () {
    var text = 'some random text';

    beforeEach(function () {
      helpers.ancestor = [];
      html.text.data = text;
    });

    afterEach(function () {
      delete html.text.next;
      delete html.text.prev;
    });

    it('trims whitespace', function () {
      html.text.data += '   ';
      var result = helpers.text(html.text, '');

      expect(result).to.be.equal(text);
    });

    it('replaces whitelines and spaces in non structural elements', function () {
      var result = helpers.text(html.multiline, '');

      expect(result).to.be.equal(
        'some additional lines. some random text, and alot of spaces'
      );
    });

    it('retains structure if element requires structure', function () {
      helpers.ancestor = [ 'pre' ];

      expect(helpers.text(html.multiline, '')).to.be.equal(
        'some additional lines.\n\n some random text, and            alot of spaces'
      );
    });

    it('removes whitespace after block elements', function () {
      html.text.prev = html.block;
      html.text.data = '  \n\n   ' + html.text.data;
      var result = helpers.text(html.text, '');

      expect(result).to.be.equal(text);
    });

    it('collapses whitespace after inline elements', function () {
      html.text.prev = html.inline;
      html.text.data = '  \n\n   ' + html.text.data;
      var result = helpers.text(html.text, '');

      expect(result).to.be.equal(' ' + text);
    });

    it('removes whitespace before block elements', function () {
      html.text.next = html.block;
      html.text.data = html.text.data + '  \n\n   ';
      var result = helpers.text(html.text, '');

      expect(result).to.be.equal(text);
    });

    it('collapses whitespace before inline elements', function () {
      html.text.next = html.inline;
      html.text.data = html.text.data + '  \n\n   ';
      var result = helpers.text(html.text, '');

      expect(result).to.be.equal(text + ' ');
    });

    it('retains one whitespace if configured losely', function () {
      var helpers = new Helpers({ loose: true });

      html.text.prev = html.inline;
      html.text.data = '<span> block element  \n\n   </span>  ';
      var result = helpers.text(html.text, '');

      expect(result).to.be.equal('<span> block element </span> ');
    });
  });

  describe('has options', function () {
    it('which are all false by default', function () {
      for (var key in helpers.config) {
        expect(helpers.config[key]).to.be.false;
      }
    });

    it('which are overideable with options', function () {
      var test = new Helpers({ empty: true });
      expect(test.config.empty).to.be.true;
    });
  });
});