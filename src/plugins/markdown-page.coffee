
{Highlight} = require 'highlight'
marked = require 'marked';
async = require 'async'
path = require 'path'
url = require 'url'
fs = require 'fs'
Page = require './page'
yaml = require 'yaml'
util = require 'util'

is_relative = (uri) ->
  ### returns true if *uri* is relative; otherwise false ###
  (url.parse(uri).protocol == undefined)

parseMetadata = (header, filename, callback) ->
  # Parse header as yaml document
  try
    callback() if header
    meta = yaml.eval(header)
    callback null, yaml.eval(header)
  catch error
    console.log "#{filename} header parse error: #{error}"
    callback()

extractMetadata = (content, filename, callback) ->
  header = null
  body = content
  match = /^([\-]+)\s*/.exec(content)
  if match
    separator = match[0]
    a = separator.length
    b = content.indexOf separator
    c = content.indexOf("\n#{separator}", b)
    d = c + separator.length

    header = content.substring(a,c)
    header = "#{separator}" + header.replace(/^/gm, '  ') + "\n"
    body = content.substring(d)
  header or= {}

  async.parallel
    metadata: (callback) ->
      parseMetadata header, filename, callback
    markdown: (callback) ->
      callback null, body
  , callback

parseMarkdownSync = (content, baseUrl) ->
  ### takes markdown *content* and returns html using *baseUrl* for any relative urls
      returns html ###

  marked.inlineLexer.formatUrl = (uri) ->
    if is_relative uri
      return url.resolve baseUrl, uri
    else
      return uri

  tokens = marked.lexer content

  for token in tokens
    switch token.type
      when 'code'
        # token.lang is set since this is github markdown, but highlight has no way to manually set lang
        token.text = Highlight token.text, '  ' # string is tab replacement
        token.escaped = true

  return marked.parser tokens

class MarkdownPage extends Page

  getLocation: (base) ->
    uri = @getUrl base
    return uri[0..uri.lastIndexOf('/')]

  getHtml: (base) ->
    ### parse @markdown and return html. also resolves any relative urls to absolute ones ###
    @_html ?= parseMarkdownSync @_content, @getLocation(base) # cache html
    return @_html

MarkdownPage.fromFile = (filename, base, callback) ->
  async.waterfall [
    (callback) ->
      fs.readFile path.join(base, filename), callback
    (buffer, callback) ->
      extractMetadata buffer.toString(), filename, callback
    (result, callback) =>
      {markdown, metadata} = result
      page = new this filename, markdown, metadata
      callback null, page
  ], callback

module.exports = MarkdownPage
