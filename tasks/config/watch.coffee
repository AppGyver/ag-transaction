module.exports =
  test:
    files: [
      '<%= files.src %>'
      '<%= files.test %>'
    ]
    tasks: [
      'test'
    ]

  compile:
    files: [
      '<%= files.src %>'
    ]
    tasks: [
      'compile'
    ]
