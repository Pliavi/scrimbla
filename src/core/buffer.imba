
import Region from '../region'

export class Buffer

	prop view

	def initialize view
		@view = view
		@buffer = ''
		@cache = {}
		self

	def set buffer
		if buffer == @buffer
			return self

		@buffer = buffer
		@cache = {}
		@lines = null
		self

	def refresh
		set view.root.code

	def lines
		@lines ||= if true
			@buffer.split('\n')

	def split
		@buffer.split(*arguments)

	def linecount
		lines:length

	def line nr
		if nr isa Number
			lines[nr] or ''
		else
			''

	def len
		@buffer:length

	# location to 
	def loc-to-rc
		self

	def location
		self

	def locToRow loc
		var ln = 0
		var len = 0
		for ln,i in lines
			len += ln:length + 1
			return i if loc < len
		return lines:length

	def locToCell loc
		if @cache[loc]
			return @cache[loc]

		var pos = loc
		var col = 0
		var row = 0
		var char

		var buf = @buffer
		var tabsize = @view.tabSize

		# go back to start of line
		# goes through the whole
		while char = buf[pos - 1]
			if char == '\n'
				break
			pos--

		# get column for slice
		while (pos < loc) and char = buf[pos]
			if char == '\t'
				var rest = tabsize - (col % tabsize)
				col += rest
			else
				col += 1
			pos++

		while char = buf[pos - 1]
			if char == '\n'
				row++
			pos--

		return @cache[loc] = [row,col]
		
	def substr region, len
		if region isa Region
			@buffer.substr(region.start,region.size)

		elif region isa Number
			@buffer.substr(region,len or 1)
		else
			throw 'must be region or number'

	def toString
		@buffer or ''

	# analysis should happen in the buffer, not in the view?
