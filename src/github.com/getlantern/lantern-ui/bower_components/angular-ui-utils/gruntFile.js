module.exports = function (grunt) {

  // Loading external tasks
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-karma');

  grunt.loadTasks('./out/tasks/');


  // Default task.
  grunt.registerTask('default', ['jshint', 'karma:unit']);
  grunt.registerTask('build', ['directory_names_concat', 'concat:tmp', 'concat:modules', 'clean:rm_tmp', 'uglify']);
  grunt.registerTask('build-doc', ['build', 'concat:html_doc']);
  grunt.registerTask('server', ['karma:start']);


  var testConfig = function (configFile, customOptions) {
    var options = { configFile: configFile, singleRun: true };
    var travisOptions = process.env.TRAVIS && { browsers: [ 'Firefox', 'PhantomJS'], reporters: ['dots'] };
    return grunt.util._.extend(options, customOptions, travisOptions);
  };

  // Project configuration.
  grunt.initConfig({
    dist: 'out/build',
    pkg: grunt.file.readJSON('package.json'),
    meta: {
      banner: ['/**',
        ' * <%= pkg.name %> - <%= pkg.description %>',
        ' * @version v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %>',
        ' * @link <%= pkg.homepage %>',
        ' * @license <%= pkg.license %>',
        ' */',
        ''].join('\n'),
      destName : '<%= dist %>/<%= pkg.name %>'
    },
    watch: {
      karma: {
        files: ['modules/**/*.js'],
        tasks: ['karma:unit:run'] //NOTE the :run flag
      }
    },
    karma: {
      unit: testConfig('test/karma.conf.js'),
      start: {
        configFile: 'test/karma.conf.js'
      }
    },
    directory_names_concat: {
      util: {
        moduleName: "ui.utils",
        prefix: 'ui.',
        src: ['modules/*', '!modules/ie-shiv'],
        dest: 'modules/utils.js'
      }
    },
    concat: {
      html_doc: {
        options: {banner: '<!-- Le content - v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %>\n================================================== -->\n'},
        src: [ 'modules/**/demo/index.html'],
        dest: 'out/demos.html'
      },
      tmp: {
        files: {  'tmp/dep.js': [ 'modules/**/*.js', '!modules/utils.js', '!modules/ie-shiv/*.js', '!modules/**/test/*.js']}
      },
      modules: {
        options: {banner: '<%= meta.banner %>'},
        files: {
          '<%= meta.destName %>.js': ['tmp/dep.js', 'modules/utils.js'],
          '<%= meta.destName %>-ieshiv.js' : ['modules/ie-shiv/*.js']
        }
      }
    },
    uglify: {
      options: {banner: '<%= meta.banner %>'},
      build: {
        files: {
          '<%= meta.destName %>.min.js': ['<%= meta.destName %>.js'],
          '<%= meta.destName %>-ieshiv.min.js': ['<%= meta.destName %>-ieshiv.js']
        }
      }
    },
    clean: {
      rm_tmp: {src: ['tmp']}
    },
    jshint: {
      files: ['modules/**/*.js', 'tasks/**/*.js'],
      options: {
        curly: true,
        eqeqeq: true,
        immed: true,
        latedef: true,
        newcap: true,
        noarg: true,
        sub: true,
        boss: true,
        eqnull: true,
        globals: {}
      }
    }
  });

};