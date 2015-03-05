chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
RunningTransaction = require('../src/running-transaction')(Promise)
TransactionHandle = require('../src/transaction-handle')(Promise)

describe "ag-transaction.TransactionHandle", ->
  it "is a class", ->
    TransactionHandle.should.be.a 'function'

  it "is created with a start function that returns a RunningTransaction", ->
    new TransactionHandle(->
      RunningTransaction.empty
    ).should.include.keys ['done', 'retry']

  it "guarantees that the start function is not called at construction", ->
    start = sinon.stub().returns RunningTransaction.empty
    new TransactionHandle(start)
    start.should.not.have.been.called

  describe 'instance', ->
    describe 'done', ->
      it "yields the done from the transaction when it succeeds", ->
        new TransactionHandle(->
          RunningTransaction.unit 'value'
        )
        .done
        .should.eventually.equal 'value'

      it "yields the done from the transaction when it fails", ->
        new TransactionHandle(->
          new RunningTransaction {
            done: Promise.reject()
          }
        )
        .done
        .should.be.rejected

