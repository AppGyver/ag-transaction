chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
Transaction = require('../src/transaction')(Promise)
PreparedTransaction = require('../src/prepared-transaction')(Promise)

transactions = require('./transactions')(Promise, Transaction)

describe "ag-transaction.PreparedTransaction", ->
  it "is a class", ->
    PreparedTransaction.should.be.a 'function'

  it "is created with a start function that returns a Transaction", ->
    new PreparedTransaction(->
      Transaction.empty
    ).should.include.keys ['done', 'retry']

  it "guarantees that the start function is not called at construction", ->
    start = sinon.stub().returns Transaction.empty
    new PreparedTransaction(start)
    start.should.not.have.been.called

  describe 'instance', ->
    describe 'done', ->
      it "yields the done from the transaction when it succeeds", ->
        new PreparedTransaction(->
          Transaction.unit 'value'
        )
        .done
        .should.eventually.equal 'value'

      it "yields the done from the transaction when it fails", ->
        new PreparedTransaction(->
          new Transaction {
            done: Promise.reject()
          }
        )
        .done
        .should.be.rejected

    describe 'abort', ->
      it "resolves if the transaction's abort resolves", ->
        new PreparedTransaction(->
          transactions.abort('value')
        )
        .abort()
        .should.eventually.equal 'value'

      it "rejects if the transaction's abort rejects", ->
        new PreparedTransaction(->
          Transaction.empty
        )
        .abort()
        .should.be.rejected


