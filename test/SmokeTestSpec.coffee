require('chai').should()
global.Promise = require 'bluebird'

describe "ag-transaction root", ->
  it "should be defined", ->
    require('../src').should.exist
