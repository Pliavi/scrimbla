extern postMessage, hljs

var compiler = require 'imba/src/compiler/compiler'

import ImbaParseError from 'imba/src/compiler/errors'
var api = {}

importScripts('/highlight.pack.js')
hljs.configure classPrefix: ''

def normalizeError e, o
	unless e isa ImbaParseError
		if e:lexer
			e = ImbaParseError.new(e, tokens: e:lexer:tokens, pos: e:lexer:pos)
		else
			e = {message: e:message}
	
	if e:toJSON # isa ImbaParseError
		# console.log 'converting error to json'
		e = e.toJSON
	
	if e isa Error
		e = {message: e:message}

	return e

def api.compile code, o = {}
	try
		var res = compiler.compile(code,o)
		# console.log "returned from compiler"
		var ret = {sourcemap: res:sourcemap, js: {body: res.toString}}
		if o:highlight
			console.log 'highlighting'
			ret:js:html = hljs.highlightAuto(res.toString)[:value]
		return ret
	catch e
		return {error: normalizeError(e,o)}

def api.analyze code, o = {}
	var meta
	try
		var ast = compiler.parse(code,o)
		meta = ast.analyze(loglevel: 0)
	catch e
		# console.log "something wrong {e:message}",o.@tokens,e:toJSON
		e = normalizeError(e,o)
		meta = {warnings: [e]}
	return {meta: meta}

global def onmessage e
	# console.log 'message to webworker',e:data
	var params = e:data
	var id = params:id
	var start = Date.new

	if api[params[0]] isa Function
		let fn = api[params[0]]
		var result = fn.apply(api,params.slice(1))

		result:worker = {
			ref: id
			action: params[0]
			elapsed: Date.new - start
		}

		postMessage(result)
