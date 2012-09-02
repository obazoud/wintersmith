
async = require 'async'
{extend, logger, rfc822, readJSON} = require './common'
{ContentTree, ContentPlugin, registerContentPlugin} = require './content'
{TemplatePlugin, loadTemplates, registerTemplatePlugin} = require './templates'
renderer = require './renderer'
_ = require 'underscore'
fs = require 'fs'
path = require 'path'

defaultPlugins =
  Page: require('./plugins/markdown-page')
  MarkdownPage: require('./plugins/markdown-page')
  JsonPage: require('./plugins/json-page')
  JadeTemplate: require('./plugins/jade-template')

# register default plugins
registerContentPlugin 'pages', '**/*.*(markdown|md)', defaultPlugins.MarkdownPage
registerContentPlugin 'pages', '**/*.json', defaultPlugins.JsonPage
registerTemplatePlugin '**/*.jade', defaultPlugins.JadeTemplate

loadContents = (location, callback) ->
  ### traverse *location* and return a tree of contents ###
  logger.verbose "loading contents in #{ location }"
  ContentTree.fromDirectory location, callback

loadPlugins = (plugins, callback) ->
  # load coffeescript so that we can load .coffee files as plugins directly
  if plugins?.length then require 'coffee-script'
  async.forEach plugins, (pluginPath, callback) ->
    logger.verbose "loading plugin: #{ pluginPath }"
    try
      plugin = require pluginPath
    catch error
      callback error
      return
    plugin module.exports, callback
  , callback

defaultOptions =
  plugins: []
  ignore: []
  locals: {}

module.exports = (options, callback) ->
  ### build all contents and templates
      *options*:
        contents: path to contents
        ignore: list of files/pattern in contents directory to ignore
        plugins: array of paths to plugins to load
        templates: path to templates
        output: path to output directory
        locals: optional extra data to send to templates ###

  # default options
  for key of defaultOptions
    options[key] ?= defaultOptions[key]

  logger.verbose 'running with options:', {options: options}

  # options passed to ContentTree.fromDirectory
  contentOptions =
    ignore: options.ignore

  # load templates & contents then render
  async.waterfall [
    async.apply loadPlugins, options.plugins
    (callback) ->
      async.parallel
        contents: async.apply ContentTree.fromDirectory, options.contents, contentOptions
        templates: async.apply loadTemplates, options.templates
      , callback
    (result, callback) ->
      tags = _.chain(result.contents.articles._.directories).map((item) ->
        item.index
      ).compact().filter((article) ->
        article.metadata.ignored isnt true
      ).map((article) ->
        article.metadata.tags
      ).flatten().compact().uniq().value()

      for tag in tags
        stream = fs.createWriteStream(path.join(options.contents, "tag", tag + ".md"), encoding: "utf8")
        stream.on 'error', (err) ->
          console.log err
        stream.write("---\ntemplate: tag.jade\ncurrentTag: " + tag + "\n---\n")
        stream.end()

      categories = _.chain(result.contents.articles._.directories).map((item) ->
        item.index
      ).compact().filter((article) ->
        article.metadata.ignored isnt true
      ).map((article) ->
        article.metadata.categories
      ).flatten().compact().uniq().value()

      for category in categories
        stream = fs.createWriteStream(path.join(options.contents, "category", category + ".md"), encoding: "utf8")
        stream.on 'error', (err) ->
          console.log err
        stream.write("---\ntemplate: category.jade\ncurrentCategory: " + category + "\n---\n")
        stream.end()

      archives = _.chain(result.contents.articles._.directories).map((item) ->
        item.index
      ).compact().filter((article) ->
        article.metadata.ignored isnt true
      ).map((article) ->
        article.date.getFullYear()
      ).flatten().compact().uniq().value()

      for archive in archives
        stream = fs.createWriteStream(path.join(options.contents, "archive", archive + ".md"), encoding: "utf8")
        stream.on 'error', (err) ->
          console.log err
        stream.write("---\ntemplate: year.jade\ncurrentYear: " + archive + "\n---\n")
        stream.end()

      renderer result.contents, result.templates, options.output, options.locals, callback
  ], callback

# expose api
module.exports.renderer = renderer
module.exports.loadTemplates = loadTemplates
module.exports.loadContents = loadContents
module.exports.loadPlugins = loadPlugins
module.exports.ContentTree = ContentTree
module.exports.ContentPlugin = ContentPlugin
module.exports.TemplatePlugin = TemplatePlugin
module.exports.defaultPlugins = defaultPlugins
module.exports.registerContentPlugin = registerContentPlugin
module.exports.registerTemplatePlugin = registerTemplatePlugin
module.exports.extend = extend
module.exports.rfc822 = rfc822
module.exports.logger = logger
module.exports.readJSON = readJSON
