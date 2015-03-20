/*global beforeEach, afterEach*/
'use strict';

var chai = require('chai')
  , sinon = require('sinon')
  , sinonChai = require('sinon-chai')
  , expect = chai.expect
  , list = require('../lib/list');

chai.use(sinonChai);
chai.config.includeStack = true;

describe('Element lists', function () {
  describe('inline collection', function () {
    it('is an array', function () {
      expect(list.inline).to.be.an('array');
    });

    it('has all required elements', function () {
      expect(list.inline.length).to.be.equal(24);
    });
  });

  describe('singular collection', function () {
    it('is an array', function () {
      expect(list.singular).to.be.an('array');
    });

    it('has all required elements', function () {
      expect(list.singular.length).to.be.equal(13);
    });
  });

  describe('structural collection', function () {
    it('matches pre, textarea or code', function () {
      expect(!!~list.structural.indexOf('pre')).to.be.true;
      expect(!!~list.structural.indexOf('textarea')).to.be.true;
      expect(!!~list.structural.indexOf('code')).to.be.true;
    });
  });

  describe('node collection', function () {
    it('matches tag, style or script', function () {
      expect(!!~list.node.indexOf('tag')).to.be.true;
      expect(!!~list.node.indexOf('script')).to.be.true;
      expect(!!~list.node.indexOf('style')).to.be.true;
    });
  });

  describe('redundant collection', function () {
    it('matches boolean attributes', function () {
      expect(!!~list.redundant.indexOf('disabled')).to.be.true;
      expect(!!~list.redundant.indexOf('multiple')).to.be.true;
      expect(!!~list.redundant.indexOf('muted')).to.be.true;
      expect(!!~list.redundant.indexOf('class')).to.be.false;
    });
  });

  describe('attributes collection', function () {
    it('is an object', function () {
      expect(list.attributes).to.be.an('object');
    });

    it('maps attributes to elements', function () {
      expect(Object.keys(list.attributes).length).to.equal(113);
      expect(list.attributes.high).to.be.an('string');
      expect(list.attributes.high).to.equal('meter');
      expect(list.attributes.disabled).to.be.an('array');
      expect(list.attributes.disabled).to.include('input');
      expect(list.attributes.disabled).to.include('textarea');
    });

    it('has global attributes', function () {
      expect(list.attributes).to.have.property('id', '*');
      expect(list.attributes).to.have.property('hidden', '*');
    });
  });
});