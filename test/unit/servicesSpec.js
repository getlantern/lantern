'use strict';

describe('The service', function() {
  beforeEach(function () {
    module('app.services');

    // Hook into the console before dependency injection happens and overrides the object
    spyOn(console, 'debug');
  });

  describe('logFactoryService', function () {
    var service, defaultLogger, customLogger;

    beforeEach(inject(function ($injector, logFactory) {
      service = logFactory;
      defaultLogger = service();
      customLogger = service("CustomCtrl");
    }));

    it('defines a logging service', function () {
      expect(defaultLogger).not.toEqual(undefined);
      expect(defaultLogger).not.toEqual(null);
      expect(typeof defaultLogger.log).toEqual('function');
      expect(typeof defaultLogger.warn).toEqual('function');
      expect(typeof defaultLogger.error).toEqual('function');
      expect(typeof defaultLogger.debug).toEqual('function');

      expect(customLogger).not.toEqual(undefined);
      expect(customLogger).not.toEqual(null);
      expect(typeof customLogger.log).toEqual('function');
      expect(typeof customLogger.warn).toEqual('function');
      expect(typeof customLogger.error).toEqual('function');
      expect(typeof customLogger.debug).toEqual('function');
    });

    it('returns valid logging functions for components on its whitelist', function () {
      expect(typeof service("Ctrl").log).toEqual('function');
      expect(service("Ctrl").log).not.toEqual(angular.noop);
    });

    it('returns no-op logging functions for components not on its whitelist', function () {
      expect(typeof service("NotWhitelisted").error).toEqual('function');
      expect(service("NotWhitelisted").error).toEqual(angular.noop);
    });

    it('prefixes log output with the component name', function () {
      defaultLogger.debug('Default debug output');
      expect(console.debug).toHaveBeenCalledWith('Default debug output');

      customLogger.debug('Custom component debug output');
      expect(console.debug).toHaveBeenCalledWith('[CustomCtrl]', 'Custom component debug output');
    });
  });
});
