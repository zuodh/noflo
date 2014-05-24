#     NoFlo - Flow-Based Programming for JavaScript
#     (c) 2014 The Grid
#     NoFlo may be freely distributed under the MIT license
#
exports.MapComponent = (component, func, config) ->
  config = {} unless config
  config.inPort = 'in' unless config.inPort
  config.outPort = 'out' unless config.outPort

  inPort = component.inPorts[config.inPort]
  outPort = component.outPorts[config.outPort]
  groups = []
  inPort.process = (event, payload) ->
    switch event
      when 'connect' then outPort.connect()
      when 'begingroup'
        groups.push payload
        outPort.beginGroup payload
      when 'data'
        func payload, groups, outPort
      when 'endgroup'
        groups.pop()
        outPort.endGroup()
      when 'disconnect'
        groups = []
        outPort.disconnect()

exports.GroupComponent = (component, func, inPorts='in', outPort='out', config={}) ->
  unless Object.prototype.toString.call(inPorts) is '[object Array]'
    inPorts = [inPorts]
  # For async func
  config.async = false unless 'async' of config
  # Group requests by group ID
  config.group = false unless 'group' of config

  for name in inPorts
    unless component.inPorts[name]
      throw new Error "no inPort named '#{name}'"
  unless component.outPorts[outPort]
    throw new Error "no outPort named '#{outPort}'"

  groupedData = {}

  out = component.outPorts[outPort]

  for port in inPorts
    do (port) ->
      inPort = component.inPorts[port]
      inPort.groups = []
      inPort.process = (event, payload) ->
        switch event
          when 'begingroup'
            inPort.groups.push payload
          when 'data'
            key = if config.group then inPort.groups.toString() else ''
            groupedData[key] = {} unless key of groupedData
            groupedData[key][port] = payload
            # Flush the data if the tuple is complete
            if Object.keys(groupedData[key]).length is inPorts.length
              groups = inPort.groups
              out.beginGroup group for group in groups
              if config.async
                grps = groups.slice(0)
                func groupedData[key], groups, out, (err) ->
                  if err
                    component.error err, groups
                    # For use with MultiError trait
                    component.fail if typeof component.fail is 'function'
                  out.endGroup() for group in grps
                  out.disconnect()
                  delete groupedData[key]
              else
                func groupedData[key], inPort.groups, out
                out.endGroup() for group in inPort.groups
                out.disconnect()
                delete groupedData[key]
          when 'endgroup'
            inPort.groups.pop()