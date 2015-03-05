chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
RunningTransaction = require('../src/running-transaction')(Promise)

never = new Promise (resolve, reject) ->
  # Never resolve or reject

describe "ag-transaction.RunningTransaction", ->
  it "is a class", ->
    RunningTransaction.should.be.a 'function'

  describe "empty", ->
    it "is a RunningTransaction", ->
      RunningTransaction.empty.should.be.an.instanceof RunningTransaction

    it "is always done", ->
      RunningTransaction.empty.done.should.be.fulfilled

  describe "unit()", ->
    it "is a function", ->
      RunningTransaction.unit.should.be.a 'function'

    it "returns a RunningTransaction", ->
      RunningTransaction.unit('value').should.be.an.instanceof RunningTransaction

    it "is done with the value passed", ->
      RunningTransaction.unit('value').done.should.eventually.equal 'value'

  describe "instance", ->
    describe "flatMapDone()", ->
      it "is a function", ->
        RunningTransaction.empty.flatMapDone.should.be.a 'function'

      it "accepts a function that must return a RunningTransaction and returns a RunningTransaction", ->
        RunningTransaction.unit('value')
          .flatMapDone(RunningTransaction.unit)
          .should.be.an.instanceof RunningTransaction

      it "should have RunningTransaction.unit as identity", ->
        RunningTransaction.unit('value')
          .flatMapDone(RunningTransaction.unit)
          .done
          .should.eventually.equal 'value'

      it "receives a value from the transaction's done", (done) ->
        RunningTransaction.unit('value').flatMapDone (v) ->
          done asserting ->
            v.should.equal 'value'
          RunningTransaction.empty

    describe "done", ->
      it "is a rejection by default", ->
        (new RunningTransaction).done.should.be.rejected

    describe "rollback()", ->
      it "is a function", ->
        RunningTransaction.empty.rollback.should.be.a 'function'

      it "returns a rejection by default", ->
        RunningTransaction.empty.rollback().should.be.rejected

      it "returns a rejection if the transaction does not complete", ->
        new RunningTransaction(
          done: Promise.reject()
          rollback: ->
        )
        .rollback()
        .should.be.rejected

      it "is not run if the transaction did fail", (done) ->
        rollback = sinon.stub()
        new RunningTransaction(
          done: Promise.reject()
          rollback: rollback
        )
        .rollback()
        .error ->
          done asserting ->
            rollback.should.not.have.been.called

      it "can be enabled by initializing with a rollback function", ->
        new RunningTransaction(
          done: Promise.resolve()
          rollback: -> 'success!'
        )
        .rollback()
        .should.eventually.equal 'success!'

      it "receives the value from done", ->
        new RunningTransaction(
          done: Promise.resolve 'value'
          rollback: (v) -> v
        )
        .rollback()
        .should.eventually.equal 'value'

    describe 'abort()', ->
      it "is a function", ->
        RunningTransaction.empty.abort.should.be.a 'function'

      it "returns a rejection by default", ->
        RunningTransaction.empty.abort().should.be.rejected

      it "returns a rejection if the transaction did complete", ->
        new RunningTransaction(
          done: Promise.resolve()
          abort: ->
        )
        .abort()
        .should.be.rejected

      it "returns a rejection if the transaction did fail", ->
        t = new RunningTransaction(
          done: Promise.reject()
          abort: ->
        )
        t.done.should.be.rejected
        t.abort().should.be.rejected

      it "can be enabled by initializing with an abort function", ->
        new RunningTransaction(
          done: never
          abort: -> 'value'
        )
        .abort()
        .should.eventually.equal 'value'
