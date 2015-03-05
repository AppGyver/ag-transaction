chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

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

    it "guarantees that the transaction step is ran after the run handler", ->
      startTransaction = sinon.stub().returns 'value'
      PreparedTransaction
        .step(startTransaction)
        .run((t) ->
          startTransaction.should.not.have.been.called
          t.done
        )
        .then (v) ->
          startTransaction.should.have.been.called
          v.should.equal 'value'
