
module.exports = (Promise) ->
  RunningTransaction = require('./running-transaction')(Promise)
  PreparedTransaction = require('./prepared-transaction')(Promise, RunningTransaction)
  return PreparedTransaction
