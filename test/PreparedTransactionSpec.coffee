chai = require('chai')
chai.should()
chai.use require 'chai-as-promised'

asserting = require './asserting'

Promise = require 'bluebird'
RunningTransaction = require('../src/running-transaction')(Promise)
PreparedTransaction = require('../src/prepared-transaction')(Promise, RunningTransaction)

describe "ag-transaction.PreparedTransaction", ->
  it "is a class", ->
    PreparedTransaction.should.be.a 'function'

  describe "empty", ->
    it "is a PreparedTransaction", ->
      PreparedTransaction.empty.should.be.an.instanceof PreparedTransaction

    it "runs with an empty transaction", ->
      PreparedTransaction.empty.run((t) -> t.done).should.be.fulfilled

