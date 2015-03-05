chai = require('chai')
chai.should()
chai.use require 'chai-as-promised'

Promise = require 'bluebird'
RunningTransaction = require('../src/running-transaction')(Promise)

describe "ag-transaction.RunningTransaction", ->
  it "is a class", ->
    RunningTransaction.should.be.a 'function'

  describe "empty", ->
    it "is a RunningTransaction", ->
      RunningTransaction.empty.should.be.an.instanceof RunningTransaction

    it "is always done", ->
      RunningTransaction.empty.done.should.be.fulfilled
