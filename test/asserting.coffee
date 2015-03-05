# Evaluates a function. Returns null if the function is successful, or an Error otherwise.
# Usage:
#   it "lols", (done) ->
#     done asserting ->
#       "lol".should.equal "lol"
#
module.exports = asserting = (f) ->
  try
    f()
    null
  catch e
    e
