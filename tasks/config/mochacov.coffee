module.exports =
  dev:
    options:
      compilers: ['coffee:coffee-script/register']

    src: ['<%= files.test %>']
  travis:
    options:
      compilers: ['coffee:coffee-script/register']
      coveralls:
        serviceName: 'travis-ci'

    src: ['<%= files.test %>']