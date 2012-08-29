
async = require 'async'
jade = require 'jade'
runtime = require 'jade/lib/runtime'
fs = require 'fs'
path = require 'path'
spawn = require('child_process').spawn

{TemplatePlugin} = require './../templates'
{logger} = require './../common'

class JadeTemplate extends TemplatePlugin

  constructor: (@fn) ->

  render: (locals, callback) ->
    try
      callback null, new Buffer @fn(locals)
    catch error
      callback error

JadeTemplate.fromFile = (filename, base, callback) ->
  fullpath = path.join base, filename
  async.waterfall [
    (callback) ->
      fs.readFile fullpath, callback
    (buffer, callback) =>
      try
        logger.info "Compiling Jade file '#{fullpath}'"
        rv = jade.compile buffer.toString(),
          filename: fullpath
          compileDebug: true
          pretty: true
        callback null, new this rv
      catch error
        console.log "Unable to compile Jade file '#{fullpath}'"
        checkSyntax buffer.toString(), fullpath
        callback error
  ], callback

checkSyntax = (str, filename) ->
  fn = undefined
  err = undefined
  lineno = undefined
  fn = ["var __jade = [{ lineno: 1, filename: " + JSON.stringify(filename) + " }];", parse(str, filename)].join("\n")
  child = spawn(process.execPath, ["-e", fn])
  child.stderr.setEncoding "utf8"
  child.stderr.on "data", (data) ->
    errLines = data.split("\n")
    descLine = errLines[4]
    if /^SyntaxError: /.test(descLine)
      
      # Syntax error was found
      infoLine = errLines[1].split(":")
      fn = fn.split("\n").slice(0, infoLine[1])
      i = 0

      while i < fn.length
        fn[i] = ""  unless /__jade/.test(fn[i])
        i++
      fn = fn.join("\n") + "__jade[0].lineno"
      lineno = eval(fn)
      err = new SyntaxError(descLine.substr(13))
      rethrow err, filename, lineno

  child.on "exit", (code, signal) ->

parse = (str, filename) ->
  options =
    filename: filename
    compileDebug: true

  try
    
    # Parse
    parser = new jade.Parser(str, filename, options)
    compiler = new (jade.Compiler)(parser.parse(), options)
    js = compiler.compile()
    return "" + "var buf = [];\n" + js
  catch err
    parser = parser.context()
    rethrow err, parser.filename, parser.lexer.lineno

rethrow = (err, filename, lineno) ->
  throw err  unless filename
  context = 3
  str = require("fs").readFileSync(filename, "utf8")
  lines = str.split("\n")
  start = Math.max(lineno - context, 0)
  end = Math.min(lines.length, lineno + context)
  
  # Error context
  context = lines.slice(start, end).map((line, i) ->
    curr = i + start + 1
    ((if curr is lineno then "  > " else "    ")) + curr + "| " + line
  ).join("\n")
  
  # Alter exception message
  err.path = filename
  err.message = (filename or "Jade") + ":" + lineno + "\n" + context + "\n\n" + err.message
  
  console.log(err.message);
  #throw err

module.exports = JadeTemplate

