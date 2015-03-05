chai = require 'chai'
sinon = require 'sinon'

chai.should()
chai.use require 'chai-as-promised'
chai.use require 'sinon-chai'

asserting = require './asserting'

Promise = require 'bluebird'
Transaction = require('../src/transaction')(Promise)
PreparedTransaction = require('../src/prepared-transaction')(Promise, Transaction)

transactions = require('./transactions')(Promise, Transaction)

describe "ag-transaction.PreparedTransaction", ->
  it "is a class", ->
    PreparedTransaction.should.be.a 'function'

  it "is created with a start function that returns a Transaction", ->
    new PreparedTransaction(->
      Transaction.empty
    ).should.include.keys ['done']

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

    describe 'abort()', ->
      it "resolves if the transaction's abort resolves", ->
        new PreparedTransaction(->
          transactions.abort('value')
        )
        .abort()
        .should.eventually.equal 'value aborted'

      it "rejects if the transaction's abort rejects", ->
        new PreparedTransaction(->
          Transaction.empty
        )
        .abort()
        .should.be.rejected

    describe 'rollback()', ->
      it "resolves if the transaction's rollback resolves", ->
        new PreparedTransaction(->
          transactions.rollback('value')
        )
        .rollback()
        .should.be.fulfilled

      it "rejects if the transaction's rollback rejects", ->
        new PreparedTransaction(->
          transactions.abort('value')
        )
        .rollback()
        .should.be.rejected

    describe "flatMapDone()", ->
      it "is a function", ->
        PreparedTransaction.empty.flatMapDone.should.be.a 'function'

      it "accepts a function that returns a PreparedTransaction and returns a PreparedTransaction", ->
        PreparedTransaction.empty.flatMapDone(->
          PreparedTransaction.empty
        ).should.be.an.instanceof PreparedTransaction

      it "should have PreparedTransaction.unit as identity", ->
        PreparedTransaction.unit('value')
          .flatMapDone(PreparedTransaction.unit)
          .done
          .should.eventually.equal 'value'

      describe "rollback()", ->

        it "combines rollbacks", ->
          new PreparedTransaction(->
            transactions.rollback 'one'
          ).flatMapDone(->
            new PreparedTransaction ->
              transactions.rollback 'two'
          )
          .rollback()
          .should.be.fulfilled

        it "combines rollbacks with their corresponding inputs", ->
          new PreparedTransaction(->
            transactions.rollback 'one'
          ).flatMapDone(->
            new PreparedTransaction ->
              transactions.rollback 'two'
          )
          .rollback()
          .should.eventually.equal 'one rolled back'

        it "combines rollbacks in reverse sequence", ->
          one = sinon.stub().returns 'one rolled back'
          two = sinon.stub().returns 'two rolled back'
          new PreparedTransaction(->
            new Transaction {
              done: Promise.resolve()
              rollback: one
            }
          ).flatMapDone(->
            new PreparedTransaction ->
              new Transaction {
                done: Promise.resolve()
                rollback: two
              }
          )
          .rollback()
          .then ->
            two.should.have.been.calledOnce
            one.should.have.been.calledOnce

        it "halts on the first rollback that cannot be completed", ->
          new PreparedTransaction(->
            transactions.rollback 'one'
          ).flatMapDone(->
            new PreparedTransaction ->
              transactions.failsRollback 'two fails'
          ).flatMapDone(->
            new PreparedTransaction ->
              transactions.rollback 'three'
          )
          .rollback()
          .should.be.rejectedWith 'two fails'

      describe "abort()", ->

        it "aborts an ongoing transaction when there is one", ->
          new PreparedTransaction(->
            transactions.abort 'one'
          ).flatMapDone(->
            new PreparedTransaction ->
              Transaction.empty
          )
          .abort()
          .should.eventually.equal 'one aborted'

        it "leaves the PreparedTransaction in a rollbackable state", ->

          t = new PreparedTransaction(->
            transactions.rollback 'one'
          ).flatMapDone(->
            new PreparedTransaction ->
              transactions.abort 'two'
          )

          t.abort().then ->
            t.rollback().should.be.fulfilled()
