require('chai').should()
Promise = require 'bluebird'
RunningTransaction = require('../src')(Promise)

describe "ag-transaction.RunningTransaction", ->
  it "is a class", ->
    RunningTransaction.should.be.a 'function'

