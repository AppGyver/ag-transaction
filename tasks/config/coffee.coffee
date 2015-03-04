module.exports =
  compile:
    src: '**/*.coffee'
    cwd: '<%= dir.src %>'
    dest: '<%= dir.dist %>'
    expand: true
    ext: '.js'