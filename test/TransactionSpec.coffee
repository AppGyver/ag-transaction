chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
Transaction = require('../src/transaction')(Promise)

never = new Promise (resolve, reject) ->
  # Never resolve or reject

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

    describe "done", ->
      it "is a rejection by default", ->
        (new Transaction).done.should.be.rejected

    describe "rollback()", ->
      it "is a function", ->
        Transaction.empty.rollback.should.be.a 'function'

      it "returns a rejection by default", ->
        Transaction.empty.rollback().should.be.rejected

      it "returns a rejection if the transaction does not complete", ->
        new Transaction(
          done: Promise.reject()
          rollback: ->
        )
        .rollback()
        .should.be.rejected

      it "is not run if the transaction did fail", (done) ->
        rollback = sinon.stub()
        new Transaction(
          done: Promise.reject()
          rollback: rollback
        )
        .rollback()
        .error ->
          done asserting ->
            rollback.should.not.have.been.called

      it "can be enabled by initializing with a rollback function", ->
        new Transaction(
          done: Promise.resolve()
          rollback: -> 'success!'
        )
        .rollback()
        .should.eventually.equal 'success!'

      it "receives the value from done", ->
        new Transaction(
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
        new Transaction(
          done: Promise.resolve()
          abort: ->
        )
        .abort()
        .should.be.rejected

      it "returns a rejection if the transaction did fail", ->
        t = new Transaction(
          done: Promise.reject()
          abort: ->
        )
        t.done.should.be.rejected
        t.abort().should.be.rejected

      it "can be enabled by initializing with an abort function", ->
        new Transaction(
          done: never
          abort: -> 'value'
        )
        .abort()
        .should.eventually.equal 'value'
