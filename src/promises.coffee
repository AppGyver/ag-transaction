module.exports = (Promise) ->
  defer = ->
    deferred = {
      promise: null
      resolve: null
      reject: null
    }

    deferred.promise = new Promise (resolve, reject) ->
      deferred.resolve = resolve
      deferred.reject = reject

    deferred

  rollbackIfCompleted = (done, rollback) ->
    done.then(
      rollback
      ->
        Promise.reject new Error "Can't roll back a transaction that did not complete"
    )

  ifCompleted = (promise, thenDo, elseDo) ->
    Promise.race([
      promise.then(
        -> thenDo
        -> thenDo
      )
      Promise.resolve(elseDo).delay(0)
    ]).then((choice) ->
      choice()
    )

  abortAndRejectUnlessCompleted = (done, abort, rejectDone) ->
    ifCompleted done,
      ->
        Promise.reject new Error "Can't abort a transaction that did complete"
      ->
        rejectDone(new Error 'Transaction aborted')
        abort()

  {
    resolve: (v) -> Promise.resolve v
    reject: (v) -> Promise.reject v
    defer
    rollbackIfCompleted
    ifCompleted
    abortAndRejectUnlessCompleted
  }
