module.exports = (grunt) ->
  grunt.registerTask 'travis', [
    'mochacov:travis'
  ]
