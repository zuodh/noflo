getParams = require 'get-function-params'
{Component} = require './Component'

exports.asComponent = (func, options) ->
  hasCallback = false
  params = getParams(func).filter (p) ->
    return true unless p.param is 'callback'
    hasCallback = true
    false

  c = new Component options
  for p in params
    c.inPorts.add p.param
    c.forwardBrackets[p.param] = ['out', 'error']
  unless params.length
    c.inPorts.add 'in',
      datatype: 'bang'

  c.outPorts.add 'out'
  c.outPorts.add 'error'
  c.process (input, output) ->
    if params.length
      for p in params
        return unless input.hasData p.param
      values = params.map (p) ->
        input.getData p.param
    else
      return unless input.hasData 'in'
      input.getData 'in'
      values = []

    if hasCallback
      values.push (err, res) ->
        return output.done err if err
        output.sendDone res
      res = func.apply null, values
      return

    res = func.apply null, values
    if typeof res is 'object' and typeof res.then is 'function'
      # Result is a Promise, resolve and handle
      res.then (val) ->
        output.sendDone val
      , (err) ->
        output.done err
      return
    output.sendDone res
  c
