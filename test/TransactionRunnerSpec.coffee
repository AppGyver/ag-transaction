chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
Transaction = require('../src/transaction')(Promise)
PreparedTransaction = require('../src/prepared-transaction')(Promise, Transaction)
TransactionRunner = require('../src/transaction-runner')(Promise, Transaction, PreparedTransaction)

describe "ag-transaction.TransactionRunner", ->
  it "is a class", ->
    TransactionRunner.should.be.a 'function'

  describe "empty", ->
    it "is a TransactionRunner", ->
      TransactionRunner.empty.should.be.an.instanceof TransactionRunner

    it "runs an empty transaction", ->
      TransactionRunner.empty.run((t) -> t.done).should.be.fulfilled

  describe "unit()", ->
    it "is a function", ->
      TransactionRunner.unit.should.be.a 'function'

    it "returns a TransactionRunner", ->
      TransactionRunner.unit('value').should.be.an.instanceof TransactionRunner

    it "runs a transaction with the given value", ->
      TransactionRunner.unit('value').run((t) -> t.done).should.eventually.equal 'value'

  describe "step()", ->
    it "is a function", ->
      TransactionRunner.step.should.be.a 'function'

    it "accepts a function and returns a TransactionRunner", ->
      TransactionRunner.step(->).should.be.an.instanceof TransactionRunner

    it "runs a transaction with a value from the given function", ->
      TransactionRunner.step(-> 'value').run((t) -> t.done).should.eventually.equal 'value'

    it "guarantees that the transaction step is ran after the run handler", ->
      startTransaction = sinon.stub().returns 'value'
      TransactionRunner
        .step(startTransaction)
        .run((t) ->
          startTransaction.should.not.have.been.called
          t.done
        )
        .then (v) ->
          startTransaction.should.have.been.called
          v.should.equal 'value'

  describe "instance", ->
    describe "run()", ->
      it "is a function", ->
        TransactionRunner.empty.run.should.be.a 'function'

      it "accepts a function that receives a PreparedTransaction", (done) ->
        TransactionRunner.empty.run (th) ->
          done asserting ->
            th.should.be.an 'object'
            th.should.have.property('done').be.an.instanceof Promise

      it "returns the asynchronous value from the passed function", ->
        TransactionRunner.empty.run(-> 'value')
          .should.eventually.equal 'value'

      it "allows the passed function to rely on done for the return value", ->
        TransactionRunner.empty.run((th) ->
          th.done.then ->
            'value'
        ).should.eventually.equal 'value'

    describe "flatMapDone()", ->
      it "is a function", ->
        TransactionRunner.empty.flatMapDone.should.be.a 'function'

      it "accepts a function that must return a TransactionRunner and returns a TransactionRunner", ->
        TransactionRunner.unit('value')
          .flatMapDone(TransactionRunner.unit)
          .should.be.an.instanceof TransactionRunner

      it "should have TransactionRunner.unit as identity", ->
        TransactionRunner.unit('value')
          .flatMapDone(TransactionRunner.unit)
          .run((t) -> t.done)
          .should.eventually.equal 'value'

