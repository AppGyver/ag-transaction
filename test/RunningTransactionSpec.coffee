chai = require('chai')
chai.should()
chai.use require 'chai-as-promised'

asserting = require './asserting'

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
