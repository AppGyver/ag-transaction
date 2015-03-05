require('chai').should()
Promise = require 'bluebird'
Transaction = require('../src')(Promise)

describe "ag-transaction root", ->
  it "should be defined", ->
    Transaction.should.exist
