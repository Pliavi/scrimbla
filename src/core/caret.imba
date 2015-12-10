import './util' as util
import Region from '../region'

class RowCol

	prop row
	prop col
	prop caret

	def view
		caret.view

	def initialize row = 0, col = 0, caret = null
		@row = row
		@col = col
		@caret = caret
		self

	def normalize
		@col = realCol
		self

	def set row, col
		if row isa RowCol
			col = row.col
			row = row.row

			# return set(row.row,row.col)

		if row isa Region
			[row,col] = util.rowcol(view.@buffer, row.start)

		var lc = view.@buffer.linecount

		if row >= lc
			row = lc - 1
			col = 1000

		@row = row
		@col = col
		return self


	def move offset
		normalize

		var col = realCol + offset
		var llen = linelen

		var lloc = lineloc
		# find the real offset in characters (not columns)


		# if offset < 0
		# 	# normalize?
		# 	@col = Math.min(@col,llen)

		if col < 0
			if @row > 0
				moveUp
				@col = linelen
			else
				@row = 0
				@col = 0
			return self

		elif col > llen
			if @row >= (view.@buffer.linecount - 1)
				return self

			moveDown
			let rest = Math.max(0,col - llen - 1)
			let moves = util.colsForLine(linestr.substr(0,rest))
			@col = moves
			return self

		# this should work
		@col = util.colsForLine(linestr.substr(0,lloc + offset))
		# @col += offset
		self

	def moveUp len
		@row = Math.max(0,@row - 1)
		self

	def moveDown len
		console.log 'moveDown'
		var lc = view.@buffer.linecount # split('\n')[:length]
		@row = @row + 1
		if @row >= lc
			console.log 'out of bounds'
			loc = view.@buffer.len
		self

	def clone
		RowCol.new(row,col,caret)

	def linelen
		util.colsForLine(linestr)

	def lineloc
		util.colToLoc(linestr,realCol)

	def realCol
		var rc = util.colToViewCol(linestr,@col)
		return rc

	def linestr
		view.linestr(row)

	def peekbehind
		var str = linestr
		str.substr(0,util.colToLoc(str,realCol))

	def peekahead
		var str = linestr
		str.slice(util.colToLoc(str,realCol))

	def loc= loc
		var [row,col] = util.rowcol(view.@buffer, loc)
		set(row,col)
		self

	def loc
		# should cache(!)
		var lines = view.@buffer.lines
		# var lines = view.buffer.split('\n')
		var loc = 0
		for line,i in lines
			var ln = line:length
			if i < @row
				loc += ln + 1 # include newline
			elif i == @row
				var viewcol = util.colToViewCol(line,@col)
				var offset = util.colToLoc(line,viewcol)
				loc += Math.min(ln,offset)
		return loc

	def tab
		# wrong - need to round instead?

		var lft = col % 4
		col = col + (4 - lft) # Math.floor(col / 4) * 4 + 4
		console.log 'marker tab',lft,col,realCol
		self

	def untab
		console.log 'untab',col
		var rest = 4 - col % 4
		col = Math.ceil(col / 4) * 4 - 4
		self

	def alter mode, dir
		var nodes = caret.view.nodesInRegion(loc, no)
		var node = nodes[0]
		var mid = node and node:node
		var lft = nodes:prev and nodes:prev:node
		var rgt = nodes:next and nodes:next:node
		var part

		# log 'move',offset,mode,nodes
		if mode == IM.WORD_START
			var el = mid or lft
			if lft?.matches(%imclose)
				self.loc = lft.parent.region.start
			elif lft?.matches(%imstr)
				self.loc = lft.region.start
			else
				let loc = self.loc
				# let buf = view.buffer
				# console.log 'peekbehind',peekbehind,loc,str
				let str = peekbehind.split('').reverse().join('')
				loc -= str.match(/^([\s\t\.]*.+?|)(\b|$)/)[1][:length]
				self.loc = loc

		elif mode == IM.WORD_END
			var el = mid or rgt
			if rgt?.matches(%imopen)
				self.loc = rgt.parent.region.end
			elif rgt?.matches(%imstr)
				self.loc = rgt.region.end
			else
				let loc = self.loc
				# let buf = view.buffer


				# console.log 'peekahead',peekahead,loc
				loc += peekahead.match(/^([\s\.]*.+?|)(\b|$)/)[1][:length]
				# loc++ until buf[loc].match(/[\n\]/)
				self.loc = loc

		elif mode == IM.LINE_END
			self.set(row,1000)

		elif mode == IM.LINE_START
			# FIXME tabs-for-spaces
			let tabs = linestr.match(/^\t*/)[0][:length]
			let newcol = tabs * view.tabSize
			self.col = col > newcol ? newcol : 0

		else
			if dir < 0 and lft?.matches('._imtab')
				# head.col = head.col - 4
				# caret.view.log 'right is tab',lft.region
				loc = lft.region.start
				# head.untab

			elif dir > 0 and rgt?.matches('._imtab')

				# use tab instead
				tab
				# head.col = head.col + 4
			else
				# ...
				move dir

		return self

tag imcarethead

# should move into Marker (like Atom)
tag imcaret

	prop region
	prop view
	prop lines
	prop ranges
	prop mode watch: yes
	prop col default: 0, watch: :dirty # the real column of the caret
	prop row default: 0, watch: :dirty
	prop input

	prop tail # rowcol
	prop head
	prop hash

	def expand lft = 0, rgt = 0
		log 'imcaret expand',lft,rgt
		decollapse
		var [a,b] = ends
		a.move(lft)
		b.move(rgt)
		self

	def toArray
		if isCollapsed
			return [head.row,head.col]
		else
			return [head.row,head.col,tail.row,tail.col]

	def toHash
		'[' + toArray.join(',') + ']'

	def set val
		if val isa IM.Types.Tok
			return set(val.region)

		if val isa Region
			return region = val

		if val isa Array
			head.row = val[0]
			head.col = val[1]

			if val:length == 4
				decollapse
				tail.row = val[2]
				tail.col = val[3]
			else
				tail = head
		dirty
		self

	def expandToLines
		selectable
		var [a,b] = ends
		a.col = 0
		b.col = 1000
		dirty

	def selectAll
		decollapse
		tail.loc = 0
		head.loc = view.@buffer.len # :length
		dirty
		self

	def selectable
		decollapse
		self

	def decollapse
		tail = head.clone if tail == head
		self

	def collapse
		tail = head
		dirty
		self

	def collapseToStart
		if isReversed
			tail = head
		else
			head = tail
		dirty
		self

	def orientation
		isReversed ? 'reversed' : 'normal'

	def isCollapsed
		tail == head

	def isReversed
		head.row < tail.row or (tail.row == head.row and head.col < tail.col)

	def indent
		var str = head.linestr
		var ind = str.match(/^(\t*)/)[0]
		return ind

	def peekbehind val
		var str = ends[0].peekbehind
		return str.match(val) if val isa RegExp
		return str

	def move offset = 1, mode = 0
		head.alter(mode,offset)
		return dirty

	# what if we 
	def moveDown len = 1
		head.moveDown
		dirty

	def moveUp len = 1
		head.moveUp
		dirty

	def ends
		isReversed ? [head,tail] : [tail,head]

	def text
		region.text

	def region
		# get the actual region based on head and tail
		# getting the code might be expensive if done
		# too many times -- but easy to cache
		# send this to util instead
		var code = view.code
		var lines = code.split('\n')
		var [a,b] = ends

		var start = 0
		var end = 0
		var ln = 0

		var ar = a.row, ac = a.col, br = b.row, bc = b.col
		var char

		for line,i in lines
			var ln = line:length
			if i < ar
				start += ln + 1 # include newline
			elif i == ar
				var offset = util.colToLoc(line,ac)
				start += Math.min(ln,offset)

			if i < br
				end += ln + 1 # include newline
			elif i == br
				var offset = util.colToLoc(line,bc)
				end += Math.min(ln,offset)
			else
				break
			
		return Region.new(start,end,view.root,view)

	def region= reg
		var buf = view.code
		var a = util.rowcol(buf,reg.a)
		var b = util.rowcol(buf,reg.b)

		head = RowCol.new(b[0],b[1],self)

		if reg.size == 0
			tail = head
		else
			tail = RowCol.new(a[0],a[1],self)
		dirty

	def nodes reg = region
		view.nodesInRegion(reg,isCollapsed)

	# should rather move this to region itself
	def target reg = region
		var nodes = nodes(reg)
		if nodes:length > 2
			return util.commonAncestor(nodes.map(|n| n:node))
		return nodes[0]:node

	def insert text, edit

		var sub = ''
		view.history.mark('action')

		if !isCollapsed
			let reg = region
			sub = reg.text
			view.erase(reg)
			collapseToStart

		let move = 0
		let sel

		# need a different syntax for $0 -- can be in regular pasted code
		# should have a separate command for insertSnippet probably.
		if text.indexOf('$0') >= 0
			sel = region.clone(0,sub:length).move(text.indexOf('$0'))
			text = text.replace('$0',sub)

		edit ||= {size: text:length}

		head.normalize
		var res = view.insert(region.start, text, edit)
		view.log 'inserted -- now move',edit:size

		if sel
			self.region = sel
		else
			# move locations
			head.loc = head.loc + edit:size
			# head.move(edit:size)

		dirty

		return self


	def erase mode
		view.history.mark('action')

		if isCollapsed
			log 'isCollapsed',mode
			decollapse
			head.alter(mode,-1) # 

			# dirty
			# return erase # call again now
		console.log 'erasing region',region
		view.erase(region)
		# log 'now collapse region to start',region
		collapseToStart
		# log region
		return self

		var target = target(reg)
		region = reg

		view.edit(
			text: ''
			target: target
			region: reg
			caret: reg.clone.collapse(no)
		)

	def dirty
		@timestamp = Date.new
		# var hash = toArray.join("")

		if @hash != toHash
			# the realCol values could have changed though?
			view.history.oncaret(@hash,toHash,self)
			@hash = toHash
			# console.log 'caret has actually changed',@hash

		var rev = isReversed
		var a = tail
		var b = head

		[a,b] = [b,a] if rev

		var lc = b.row - a.row
		var row = a.row

		var ac = a.realCol # Math.min( a.col, util.colsForLine(view.linestr(a.row) ) )
		var bc = b.realCol # Math.min( b.col, util.colsForLine(view.linestr(b.row) ) )
		var hc,tc

		if isReversed
			hc = ac
			tc = bc
		else
			hc = bc
			tc = ac
		
		# log 'dirty',region,a.row,a.col,b.row,b.col,hc,tc,head,tail,rev

		css transform: "translate(0px,{a.row * 100}%)"
		# convert the row and column to a region (should go both ways)
		@caret.css transform: "translate({hc}ch,{(head.row - row) * 100}%)"
		@start.css marginLeft: "{ac}ch", width: "auto"
		@end.css width: "{bc}ch"

		if isCollapsed
			mode = 'collapsed'

		elif lc == 0
			mode = 'single'
			@start.css width: (bc - ac) + "ch"
		else
			@mid.text = lc > 1 ? ('\n').repeat(lc - 1) : ''
			mode = 'multi'
		self

	def render
		var elapsed = (Date.new - @timestamp)
		var flip = Math.round(elapsed / 500) % 2

		if flip != @flip
			@caret.flag('blink',flip)
			@flip = flip

		self

	def build
		tail = head = RowCol.new(0,0,self)

		<self>
			# <imcaptor@input value='x'>
			<span.dim> 'x'
			<imcarethead@caret>
			<div@lines>
				<div@start> " "
				<div@mid>
				<div@end> " "

	def normalize
		head.normalize
		self

	def modeDidSet new, old
		unflag(old)
		flag(new)