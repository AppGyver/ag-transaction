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

transactions = require('./transactions')(Promise, Transaction)

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
        TransactionRunner
          .step ({abort}) ->
            abort ->
              'aborted'
            transactions.never
          .run (t) ->
            t.done.should.be.rejected
            t.abort()
          .should.eventually.equal 'aborted'

      it "provides rollback for defining rollback handler", ->
        TransactionRunner
          .step ({rollback}) ->
            rollback (v) ->
              "rolled back #{v}"
            Promise.resolve 'value'
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
          TransactionRunner
            .step ({rollback}) ->
              rollback ->
                'one rolled back'
              Promise.resolve()
            .flatMapDone ->
              TransactionRunner.step ({rollback}) ->
                rollback ->
                  'two rolled back'
                Promise.resolve()
            .run((t) ->
              t.rollback()
            )
            .should.eventually.equal 'one rolled back'

        it "combines rollbacks in reverse sequence", ->
          one = sinon.stub().returns 'one rolled back'
          two = sinon.stub().returns 'two rolled back'
          TransactionRunner
            .step ({rollback}) ->
              rollback one
              Promise.resolve()
            .flatMapDone ->
              TransactionRunner.step ({rollback}) ->
                rollback two
                Promise.resolve()
            .run((t) ->
              t.rollback()
            )
            .then ->
              two.should.have.been.calledOnce
              one.should.have.been.calledOnce

        it "halts on the first rollback that cannot be completed", ->
          TransactionRunner
            .step ({rollback}) ->
              rollback ->
                'one'
              Promise.resolve()
            .flatMapDone ->
              TransactionRunner.step ({rollback}) ->
                rollback ->
                  Promise.reject new Error 'two fails'
                Promise.resolve()
            .flatMapDone ->
              TransactionRunner.step ({rollback}) ->
                rollback ->
                  'three'
                Promise.resolve()
            .run((t) ->
              t.rollback()
            )
            .should.be.rejectedWith 'two fails'

      describe "abort()", ->

        it "aborts an ongoing transaction when there is one", ->
          TransactionRunner
            .step ({abort}) ->
              abort ->
                'one aborted'
              transactions.never
            .flatMapDone ->
              TransactionRunner.empty
            .run (t) ->
              t.done.should.be.rejected
              t.abort()
            .should.eventually.equal 'one aborted'

        it "leaves the transaction in a rollbackable state", ->
          TransactionRunner
            .step ({rollback}) ->
              rollback ->
                'one rolled back'
              Promise.resolve()
            .flatMapDone ->
              TransactionRunner.step ({abort}) ->
                abort ->
                  'two aborted'
                transactions.never
            .run (t) ->
              t.done.should.be.rejected
              t.abort().then ->
                t.rollback()
            .should.eventually.equal 'one rolled back'

