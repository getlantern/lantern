module.exports = function(grunt) {
   'use strict';

   grunt.initConfig({
      pkg: grunt.file.readJSON('package.json'),

      karma: {
         unit: {
            configFile: 'karma.conf.js',
            singleRun: true
         }
      },

      jshint: {
         all: ['Gruntfile.js', 'src/*.js', 'test/**/*.js']
      },

      concat: {
         options: {
            stripBanners: false
         },
         dist: {
            src: ['dist/angulartics-scroll.min.js', 'components/jquery-waypoints/waypoints.min.js'],
            dest: 'dist/angulartics-scroll.min.js'
         }
      },

      uglify: {
         options: {
            preserveComments: 'some',
            report: 'min'
         },
         predist: {
            files: {
               'dist/angulartics-scroll.min.js': ['src/angulartics-scroll.js']
            }
         },
         dist: {
            files: {
               'dist/angulartics.min.js': ['src/angulartics.js'],
               'dist/angulartics-chartbeat.min.js': ['src/angulartics-chartbeat.js'],
               'dist/angulartics-google-analytics.min.js': ['src/angulartics-google-analytics.js'],
               'dist/angulartics-kissmetrics.min.js': ['src/angulartics-kissmetrics.js'],
               'dist/angulartics-mixpanel.min.js': ['src/angulartics-mixpanel.js'],
               'dist/angulartics-segmentio.min.js': ['src/angulartics-segmentio.js']
            }
         }
      },

      clean: ['dist']
   });

   grunt.loadNpmTasks('grunt-contrib-jshint');
   grunt.loadNpmTasks('grunt-karma');
   grunt.loadNpmTasks('grunt-contrib-concat');
   grunt.loadNpmTasks('grunt-contrib-uglify');
   grunt.loadNpmTasks('grunt-contrib-clean');

   grunt.registerTask('test', ['jshint', 'karma']);
   grunt.registerTask('default', ['jshint', 'karma', 'uglify:predist', 'concat:dist', 'uglify:dist']);
};
