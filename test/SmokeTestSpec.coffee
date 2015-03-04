require('chai').should()

describe "ag-transaction root", ->
  it "should be defined", ->
    require('../src').should.exist