module.exports = function(config) {
  'use strict';
  
  config.set({

    basePath: './',

    frameworks: ["jasmine"],

    files: [
      'components/angular/angular.js',
      'components/angular-mocks/angular-mocks.js',
      'src/**/*.js',
      'test/**/*.js'
    ],

    autoWatch: true,

    browsers: ['PhantomJS']

  });
};