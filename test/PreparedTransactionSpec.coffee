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

    it "runs an empty transaction", ->
      PreparedTransaction.empty.run((t) -> t.done).should.be.fulfilled

  describe "unit()", ->
    it "is a function", ->
      PreparedTransaction.unit.should.be.a 'function'

    it "returns a PreparedTransaction", ->
      PreparedTransaction.unit('value').should.be.an.instanceof PreparedTransaction

    it "runs a transaction with the given value", ->
      PreparedTransaction.unit('value').run((t) -> t.done).should.eventually.equal 'value'

  describe "step()", ->
    it "is a function", ->
      PreparedTransaction.step.should.be.a 'function'

    it "accepts a function and returns a PreparedTransaction", ->
      PreparedTransaction.step(->).should.be.an.instanceof PreparedTransaction

    it "runs a transaction with a value from the given function", ->
      PreparedTransaction.step(-> 'value').run((t) -> t.done).should.eventually.equal 'value'

