chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
promises = require('../src/promises')(Promise)
Transaction = require('../src/transaction')(promises)
PreparedTransaction = require('../src/prepared-transaction')(promises, Transaction)
TransactionRunner = require('../src/transaction-runner')(Promise, Transaction, PreparedTransaction)

transactions = require('./transactions')(Promise, Transaction)
runners = require('./runners')(transactions, Promise, TransactionRunner)

describe "ag-transaction.TransactionRunner", ->
  it "is a class", ->
    TransactionRunner.should.be.a 'function'

  describe "empty", ->
    it "is a TransactionRunner", ->
      TransactionRunner.empty.should.be.an.instanceof TransactionRunner

    it "runs an empty transaction", ->
      TransactionRunner.empty.run (t) ->
        t.done.should.be.fulfilled

  describe "unit()", ->
    it "is a function", ->
      TransactionRunner.unit.should.be.a 'function'

    it "returns a TransactionRunner", ->
      TransactionRunner.unit().should.be.an.instanceof TransactionRunner

    it "runs a transaction with the given value", ->
      TransactionRunner.unit('value').run (t) ->
        t.done.should.eventually.equal 'value'

  describe "step()", ->
    it "is a function", ->
      TransactionRunner.step.should.be.a 'function'

    it "accepts a function and returns a TransactionRunner", ->
      TransactionRunner.step(->).should.be.an.instanceof TransactionRunner

    it "runs a transaction with a value from the given function", ->
      TransactionRunner.step(-> 'value').run (t) ->
        t.done.should.eventually.equal 'value'

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

    describe "arguments to function", ->
      it "provides abort for defining abort handler", ->
        runners.abortsWith('aborted')
          .run (t) ->
            t.done.should.be.rejected
            t.abort()
          .should.eventually.equal 'aborted'

      it "provides rollback for defining rollback handler", ->
        runners.rollsbackWith('rolled back value')
          .run (t) ->
            t.done.then ->
              t.rollback()
          .should.eventually.equal 'rolled back value'

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

      describe "rollback()", ->
        it "combines rollbacks", ->
          runners.rollsbackWith('one rolled back')
            .flatMapDone ->
              runners.rollsbackWith('two rolled back')
            .run((t) ->
              t.rollback()
            )
            .should.eventually.equal 'one rolled back'

        it "combines rollbacks in reverse sequence", ->
          one = sinon.stub().returns 'one rolled back'
          two = sinon.stub().returns 'two rolled back'
          runners.rollsbackWith(one)
            .flatMapDone ->
              runners.rollsbackWith(two)
            .run((t) ->
              t.rollback()
            )
            .then ->
              two.should.have.been.calledOnce
              one.should.have.been.calledOnce

        it "halts on the first rollback that cannot be completed", ->
          runners.rollsbackWith('one')
            .flatMapDone ->
              runners.failsRollbackWith 'two fails'
            .flatMapDone ->
              runners.rollsbackWith 'three'
            .run((t) ->
              t.rollback()
            )
            .should.be.rejectedWith 'two fails'

      describe "abort()", ->

        it "aborts an ongoing transaction when there is one", ->
          runners.abortsWith('one aborted')
            .flatMapDone ->
              TransactionRunner.empty
            .run (t) ->
              t.done.should.be.rejected
              t.abort()
            .should.eventually.equal 'one aborted'

        it "leaves the transaction in a rollbackable state", ->
          runners.rollsbackWith('one rolled back')
            .flatMapDone ->
              runners.abortsWith 'two aborted'
            .run (t) ->
              t.done.should.be.rejected
              t.abort().then ->
                t.rollback()
            .should.eventually.equal 'one rolled back'

        it "ignores states that did not begin when rolling back", ->
          three = sinon.stub().returns 'three rolled back'
          runners.rollsbackWith('one rolled back')
            .flatMapDone ->
              runners.abortsWith 'two aborted'
            .flatMapDone ->
              runners.rollsbackWith three
            .run (t) ->
              t.done.should.be.rejected
              t.abort().then ->
                t.rollback().then (v) ->
                  three.should.not.have.been.called
                  v.should.equal 'one rolled back'
