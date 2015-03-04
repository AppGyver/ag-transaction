module.exports = (grunt) ->
  grunt.registerTask 'dev', [
    'test'
    'watch:test'
  ]
