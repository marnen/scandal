_ = require 'underscore'
fs = require 'fs'
temp = require 'temp'
{EventEmitter} = require 'events'
{Transform} = require 'stream'
{EOL} = require 'os'

ChunkedLineReader = require './chunked-line-reader'

class ReplaceTransformer extends Transform
  constructor: (@regex, @replacementText) ->
    @replacements = 0
    super()

  _transform: (chunk, encoding, done) ->
    data = chunk.toString()

    matches = data.match(@regex)
    @replacements += matches.length if matches

    data = data.replace(@regex, @replacementText)
    @push(data, 'utf8')
    done()

module.exports =
class PathReplacer extends EventEmitter

  replacePaths: (regex, replacementText, paths, doneCallback) ->
    results = null
    pathsReplaced = 0

    for filePath in paths
      @replacePath regex, replacementText, filePath, (result) ->
        if result
          results ?= []
          results.push(result)

        doneCallback(results) if ++pathsReplaced == paths.length

  replacePath: (regex, replacementText, filePath, doneCallback) ->
    reader = new ChunkedLineReader(filePath)
    replacer = new ReplaceTransformer(regex, replacementText)
    output = temp.createWriteStream()

    output.on 'finish', =>
      result = null
      if replacements = replacer.replacements
        result = {filePath, replacements}
        @emit('path-replaced', result)

      fs.renameSync(output.path, filePath)
      doneCallback(result)

    reader.pipe(replacer).pipe(output)
