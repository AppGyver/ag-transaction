ag-transaction
========

[![Build Status](http://img.shields.io/travis/AppGyver/ag-transaction/master.svg)](https://travis-ci.org/AppGyver/ag-transaction)
[![NPM version](http://img.shields.io/npm/v/ag-transaction.svg)](https://www.npmjs.org/package/ag-transaction)
[![Dependency Status](http://img.shields.io/david/AppGyver/ag-transaction.svg)](https://david-dm.org/AppGyver/ag-transaction)
[![Coverage Status](https://img.shields.io/coveralls/AppGyver/ag-transaction.svg)](https://coveralls.io/r/AppGyver/ag-transaction)

Provides a type for asynchronous, reversible transactions

## Usage

### Installation

    npm install ag-transaction

### Creating and running transactions

```coffeescript
Transaction = require 'ag-transaction'

# Build a transaction sequence step by step
# This step is rollbackable but not abortable
Transaction.step ({rollback}) ->
    rollback (foo) ->
      foo.delete()
    # Returns a Promise Foo
    createFoo()

  # Combine with a next step
  .flatMapDone (foo) ->
    # This step is abortable
    Transaction.step ({abort}) ->
      # Returns { abort, done }
      upload = startUpload foo
      abort ->
        upload.abort()
      upload.done

  # When we run the transaction we've built, we get a handle to the results
  .run (t) ->
    # done signals completion
    t.done.then ->
      alert 'All done with uploading Foo!'

    # We can send a signal to abort the transaction
    t.abort().then ->
      # Let's also clean up after ourselves
      t.rollback().then ->
        alert "Didn't upload Foo"

```

### API signatures

#### Transaction.step

    Transaction.step :: (f: ({
      abort: (() -> Promise) -> ()
      rollback: ((a) -> Promise) -> ()
    }) -> Promise a) -> TransactionRunner a

Declare a transaction step.

Accepts a function `f` that accepts functions for declaring `abort` and `rollback` instructions, and starts a process that returns a Promise of `a`.

Returns a `TransactionRunner a` that will start the process after run.

#### TransactionRunner

    TransactionRunner a = {
      flatMapDone: (f: (a) -> TransactionRunner b) -> TransactionRunner b
      run: (f: (Transaction a) -> Promise b) -> Promise b
    }

Represents a step or steps to run to complete a transaction. Can be chained with other steps using `flatMapDone` or ran by calling `run`.

#### Transaction

    Transaction a = {
      done: Promise a
      abort: () -> Promise
      rollback: () -> Promise
    }

A running process that can be instructed to `abort` until `done` has completed, in which case it can be instructed to `rollback`. The underlying process steps need to support these instructions in the specific phases of the process the transaction might be aborted or rolled back at.

## Design document

### Prerequisites

Assuming a familiarity with [Bluebird](https://github.com/petkaantonov/bluebird/) Promises and [Bacon.js](https://github.com/baconjs/bacon.js/) Streams.

### Use case

Assume we have a multi-part asynchronous process.

    model("files").create(data).then (file) ->
      model("fileversions").create(data).then (uploadAdvice) ->
        uploadFile(file, uploadAdvice).then ->
          model("files").findAll(filters).then parseFiles

In addition to what's already afforded by the Promise type, we would like to:

- observe progress (because the file upload may take a very long while)
- be able to abort (in case it's taking too long)

This needs to be done such that the resulting API is as chainable as the original.

### The `Transaction` type

The `Transaction` type is essentially a pair of `{ progress, done }`, where `progress` is a Stream of progress notifications and `done` is a Promise of the eventual result.

    progress: Stream p
    done: Promise d

We additionally require that we can signal abortion of the process,

    abort: () -> Promise

being able to continue off the result of the next step,

    flatMapDone: ((d) -> Transaction p e) -> Transaction p e

and being able to affect the `progress` stream,

    mapProgress: ((Stream p) -> (Stream q)) -> Transaction q d

The full type is therefore:

    Transaction p d = {
      progress: Stream p
      done: Promise d
      abort: () -> Promise
      flatMapDone: ((d) -> Transaction p e) -> Transaction p e
      mapProgress: ((Stream p) -> (Stream q)) -> Transaction q d
    }

### Creating a Transaction with `Transaction.step`

Transaction.step is a function that allows us to lift `Promise`-yielding processes into `Transaction`.

    Transaction.step :: ((
      rollback: () -> Promise
      progress: (p) -> ()
    ) -> Promise d) -> Transaction p d

Let's take a procedure and bake it into a `Transaction`.

    model("files").create(data).then (file) ->
      model("fileversions").create(data).then (fileVersion) ->
        {file, fileVersion}

We use `Transaction.step` to provide the `progress`, `abort` and `flatMapDone` and our procedure for the `done`.

    Transaction.step ->
      model("files").create(data).then (file) ->
        model("fileversions").create(data).then (fileVersion) ->
          {file, fileVersion}

You'll observe that there are two parts that we may wish to reverse later on in case something in the rest of the transaction fails. Let's provide rollback instructions.

    Transaction.step (rollback) ->
      model("files").create(data).then (file) ->
        rollback ->
          file.delete()
        model("fileversions").create(data).then (fileVersion) ->
          rollback ->
            fileVersion.delete()
          {file, fileVersion}

`Transaction.step` will collect the instructions and knows what to do in case we call `abort` or a step fails.

We can also provide progress notifications. Ignoring the rollback instructions for sake of example, we get:

    Transaction.step (rollback, progress) ->
      model("files").create(data).then (file) ->
        progress "halfway there!"
        model("fileversions").create(data).then (fileVersion) ->
          {file, fileVersion}

The example provides a string as the notification, but it can be whatever the consumer should be able to process.

### Chaining `Transaction` steps with `flatMapDone`

Let's imagine we wanted to split the two asynchronous steps we had before.

    createFile = Transaction.step (rollback, progress) ->
      model("files").create(data).then (file) ->
        rollback ->
          file.delete()
        progress "file created"
        file

If we wanted to continue off the value in `done` after this step, we could of course do this:

    createFile.done.then (file) ->
      model("fileversions").create(data).then (fileVersion) ->
        {file, fileVersion}

The result of this operation, however, is not a `Transaction` but a `Promise`. The consumer of this value would not be able to abort the process or inspect its progress - what's done is done and what's not done is not done.

We often want to perform a transaction as multiple sequential steps, where a step depends on the output of a previous one. We achieve this with `flatMapDone`, which accepts the value from the previous step's `done` and returns a new `Transaction`.

    createFileVersion = createFile.flatMapDone (file) ->
      Transaction.step (rollback, progress) ->
        model("fileversions").create(data).then (fileVersion) ->
          rollback ->
            fileVersion.delete()
          progress "fileversion created"
          {file, fileVersion}

In terms of our type it means we take a `Transaction`, add another step and get a bigger `Transaction` back. `flatMapDone` will take care to retain the rollback instructions and progress events for us.

### Manipulating transaction `progress` with `mapProgress`

Basing on the previous example, events in `createFileVersion.progress` will be:

    "file created"
    "fileversion created"

Imagine we didn't care for the strings much at all and would prefer to see an incrementing counter. We need to switch out the `progress` stream's contents.

    createFileVersion.mapProgress (events) ->
      events.scan(0, (count, event) -> count + 1)

Resulting events in `progress` are:

    0
    1
    2

This becomes especially relevant if we wish to aggregate multiple parallel transactions.

### Parallel transactions with `Transaction.all`

Careful observation reveals the `createFile` and `createFileVersion` steps do not in fact depend on each other. What we have instead are distinct steps we wish to execute in parallel.

    createFileAndFileVersion = Transaction.all([
      Transaction.step (rollback, progress) ->
        model("files").create(data).then (file) ->
          rollback ->
            file.delete()
          progress "file created"
          file
      Transaction.step (rollback, progress) ->
        model("fileversions").create(data).then (fileVersion) ->
          rollback ->
            fileVersion.delete()
          progress "fileversion created"
          fileVersion
    ])

`Transaction.all` accepts an array of `Transactions`. The resulting `Transaction` will have a `done` populated with an array of the corresponding values.

    createFileAndFileVersion.flatMapDone ([file, fileVersion]) ->
      Transaction.unit { file, fileVersion }

This step would return the pair in an array back into an object as before. `Transaction.unit` yields a `Transaction` with nothing but the end result. It's the same as using `Transaction.step` and `Promise.resolve` in conjunction, so could have been expressed like this.

    createFileAndFileVersion.flatMapDone ([file, fileVersion]) ->
      Transaction.step ->
        Promise.resolve { file, fileVersion }
