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

prepare = (f) ->
  new PreparedTransaction f

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
        prepare(->
          Transaction.unit 'value'
        )
        .done
        .should.eventually.equal 'value'

      it "yields the done from the transaction when it fails", ->
        prepare(->
          Transaction.create {
            done: Promise.reject()
          }
        )
        .done
        .should.be.rejected

    describe 'abort()', ->
      it "resolves if the transaction's abort resolves", (done) ->
        t = prepare(->
          transactions.abort('value')
        )
        t.abort().then (v) ->
          done asserting ->
            v.should.equal 'value aborted'
            t.done.should.be.rejected

      it "rejects if the transaction's abort rejects", ->
        prepare(->
          Transaction.empty
        )
        .abort()
        .should.be.rejected

    describe 'rollback()', ->
      it "resolves if the transaction's rollback resolves", ->
        prepare(->
          transactions.rollback('value')
        )
        .rollback()
        .should.be.fulfilled

      it "rejects if the transaction's rollback rejects", ->
        prepare(->
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
          prepare(->
            transactions.rollback 'one'
          ).flatMapDone(->
            prepare ->
              transactions.rollback 'two'
          )
          .rollback()
          .should.be.fulfilled

        it "combines rollbacks with their corresponding inputs", ->
          prepare(->
            transactions.rollback 'one'
          ).flatMapDone(->
            prepare ->
              transactions.rollback 'two'
          )
          .rollback()
          .should.eventually.equal 'one rolled back'

        it "combines rollbacks in reverse sequence", ->
          one = sinon.stub().returns 'one rolled back'
          two = sinon.stub().returns 'two rolled back'
          prepare(->
            Transaction.create {
              done: Promise.resolve()
              rollback: one
            }
          ).flatMapDone(->
            prepare ->
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
          prepare(->
            transactions.rollback 'one'
          ).flatMapDone(->
            prepare ->
              transactions.failsRollback 'two fails'
          ).flatMapDone(->
            prepare ->
              transactions.rollback 'three'
          )
          .rollback()
          .should.be.rejectedWith 'two fails'

      describe "abort()", ->

        it "aborts an ongoing transaction when there is one", ->
          t = prepare(->
            transactions.abort 'one'
          ).flatMapDone(->
            prepare ->
              Transaction.empty
          )

          t.done.should.be.rejected
          t.abort().should.eventually.equal 'one aborted'

        it "leaves the PreparedTransaction in a rollbackable state", ->

          t = prepare(->
            transactions.rollback 'one'
          ).flatMapDone(->
            prepare ->
              transactions.abort 'two'
          )

          t.done.should.be.rejected
          t.abort().then ->
            t.rollback().should.be.fulfilled
