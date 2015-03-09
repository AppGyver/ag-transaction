chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
promises = require('../src/promises')(Promise)
Transaction = require('../src/transaction')(promises)

transactions = require('./transactions')(Promise, Transaction)
{ never } = transactions

describe "ag-transaction.Transaction", ->
  it "is a class", ->
    Transaction.should.be.a 'function'

  describe "empty", ->
    it "is a Transaction", ->
      Transaction.empty.should.be.an.instanceof Transaction

    it "is always done", ->
      Transaction.empty.done.should.be.fulfilled

  describe "unit()", ->
    it "is a function", ->
      Transaction.unit.should.be.a 'function'

    it "returns a Transaction", ->
      Transaction.unit('value').should.be.an.instanceof Transaction

    it "is done with the value passed", ->
      Transaction.unit('value').done.should.eventually.equal 'value'

  describe "instance", ->

    describe "done", ->
      it "is a rejection by default", ->
        Transaction.create().done.should.be.rejected

    describe "rollback()", ->
      it "is a function", ->
        Transaction.empty.rollback.should.be.a 'function'

      it "returns a rejection by default", ->
        Transaction.empty.rollback().should.be.rejected

      it "returns a rejection if the transaction does not complete", ->
        Transaction.create(
          done: Promise.reject()
          rollback: ->
        )
        .rollback()
        .should.be.rejected

      it "is not run if the transaction did fail", (done) ->
        rollback = sinon.stub()
        Transaction.create(
          done: Promise.reject()
          rollback: rollback
        )
        .rollback()
        .error ->
          done asserting ->
            rollback.should.not.have.been.called

      it "can be enabled by initializing with a rollback function", ->
        Transaction.create(
          done: Promise.resolve()
          rollback: -> 'success!'
        )
        .rollback()
        .should.eventually.equal 'success!'

      it "receives the value from done", ->
        Transaction.create(
          done: Promise.resolve 'value'
          rollback: (v) -> v
        )
        .rollback()
        .should.eventually.equal 'value'

    describe 'abort()', ->
      it "is a function", ->
        Transaction.empty.abort.should.be.a 'function'

      it "returns a rejection by default", ->
        Transaction.empty.abort().should.be.rejected

      it "returns a rejection if the transaction did complete", ->
        Transaction.create(
          done: Promise.resolve()
          abort: ->
        )
        .abort()
        .should.be.rejected

      it "returns a rejection if the transaction did fail", ->
        t = Transaction.create(
          done: Promise.reject()
          abort: ->
        )
        t.done.should.be.rejected
        t.abort().should.be.rejected

      it "can be enabled by initializing with an abort function", ->
        t = Transaction.create(
          done: never
          abort: -> 'value'
        )
        t.abort().should.eventually.equal 'value'

      it "short-circuits done to reject", (done) ->
        t = Transaction.create(
          done: never
          abort: ->
        )
        t.abort().then ->
          done asserting ->
            t.done.should.be.rejectedWith 'aborted'

    describe "flatMapDone()", ->
      it "is a function", ->
        Transaction.empty.flatMapDone.should.be.a 'function'

      it "accepts a function that must return a Transaction and returns a Transaction", ->
        Transaction.unit('value')
          .flatMapDone(Transaction.unit)
          .should.be.an.instanceof Transaction

      it "should have Transaction.unit as identity", ->
        Transaction.unit('value')
          .flatMapDone(Transaction.unit)
          .done
          .should.eventually.equal 'value'

      it "receives a value from the transaction's done", (done) ->
        Transaction.unit('value').flatMapDone (v) ->
          done asserting ->
            v.should.equal 'value'
          Transaction.empty

      describe "rollback()", ->

        it "combines rollbacks with their corresponding inputs", ->
          transactions
            .rollback('one')
            .flatMapDone ->
              transactions.rollback('two')
            .rollback()
            .should.eventually.equal 'one rolled back'

        it "combines rollbacks in reverse sequence", ->
          one = sinon.stub().returns 'one rolled back'
          two = sinon.stub().returns 'two rolled back'
          Transaction.create({
              done: Promise.resolve()
              rollback: one
          }).flatMapDone(->
            Transaction.create {
              done: Promise.resolve()
              rollback: two
            }
          )
          .rollback()
          .then ->
            two.should.have.been.calledOnce
            one.should.have.been.calledOnce

        it "halts on the first rollback that cannot be completed", ->
          transactions.rollback('one')
            .flatMapDone ->
              transactions.failsRollback 'two fails'
            .flatMapDone ->
              transactions.rollback 'three'
            .rollback()
            .should.be.rejectedWith 'two fails'

      describe "abort()", ->

        it "aborts an ongoing transaction when there is one", ->
          t = transactions.abort('one')
            .flatMapDone ->
              Transaction.empty

          t.done.should.be.rejected
          t.abort().should.eventually.equal 'one aborted'

        it "leaves the transaction in a rollbackable state", ->
          t = transactions.rollback('one')
            .flatMapDone ->
              transactions.abort 'two'

          t.abort().then ->
            t.rollback().should.eventually.equal 'one rolled back'

        it "ignores states that did not begin when rolling back", ->
          three = sinon.stub().returns 'three rolled back'
          t = transactions.rollback('one')
            .flatMapDone ->
              transactions.abort 'two'
            .flatMapDone ->
              Transaction.create {
                done: transactions.never
                rollback: three
              }

          t.done.should.be.rejected
          t.abort().then ->
            t.rollback().then (v) ->
              three.should.not.have.been.called
              v.should.equal 'one rolled back'

