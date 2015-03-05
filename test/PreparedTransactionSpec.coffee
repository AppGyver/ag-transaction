chai = require('chai')
chai.should()
chai.use require 'chai-as-promised'

asserting = require './asserting'

Promise = require 'bluebird'
RunningTransaction = require('../src/running-transaction')(Promise)
PreparedTransaction = require('../src/prepared-transaction')(Promise, RunningTransaction)

describe "ag-transaction.PreparedTransaction", ->
  it "is a class", ->
    PreparedTransaction.should.be.a 'function'
