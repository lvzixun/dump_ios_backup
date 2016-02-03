local sf = string.format
local sb = string.byte
local tc = table.concat
local lsha1 = require "lsha1"

local ret = {}
local function sha1(msg)
	local d = lsha1.hex(msg)
	local l = #d
	for i=1,l do
		ret[i] = sf("%.2x", sb(d, i))
	end
	return tc(ret, "", 1, l)
end


local reader_mt = {}
local function create_reader(s)
	local raw = {
		buffer = s,
		cur_idx = 1,
	}

	return setmetatable(raw, {__index = reader_mt})
end

function reader_mt:is_end()
	local len = #self.buffer
	return self.cur_idx > len
end

function reader_mt:data(len)
	len = len or 1
	local begin_idx = self.cur_idx
	local end_idx   = begin_idx + len -1
	local value = string.sub(self.buffer, begin_idx, end_idx)
	self.cur_idx = end_idx + 1
	return value
end

local function read_number(self, n)
	local begin_idx = self.cur_idx
	local value, idx = string.unpack(">I"..(n), self.buffer, begin_idx)
	self.cur_idx = idx
	return value
end

function reader_mt:byte()
	return read_number(self, 1)
end

function reader_mt:short()
	return read_number(self, 2)
end

function reader_mt:int()
	return read_number(self, 4)
end

function reader_mt:long()
	return read_number(self, 8)
end

function reader_mt:string()
	local header = self:short(self)
	if header == 0xffff then
		return ""
	else
		local begin_idx = self.cur_idx
		local end_idx   = begin_idx + header - 1
		local value = string.sub(self.buffer, begin_idx, end_idx)
		self.cur_idx = end_idx + 1
		return value
	end
end 



local function decode_item(reader)
	local ret = {
		domain = reader:string(),
		filename = reader:string(),
		linktarget = reader:string(),
		datahash = reader:string(),
		unknown1 = reader:string(),
		mode = reader:short(),
		unknown2 = reader:int(),
		unknown3 = reader:int(),
		userid = reader:int(),
		groupid = reader:int(),
		mtime = reader:int(),
		atime = reader:int(),
		ctime = reader:int(),
		filelen = reader:long(),
		flag = reader:byte(),
		numprops = reader:byte(),
		properties = {},
		backup_filename = false,
	}

	local properties = ret.properties
	for i=1, ret.numprops do
		local name  = reader:string()
		local value = reader:string()
		properties[name] = value
	end

	local full_path = ret.domain.."-"..ret.filename
	ret.backup_filename = sha1(full_path)
	return ret
end


local function decode(s)
	local ret = {}
	local reader = create_reader(s)

	assert(reader:data(4)=="mbdb")
	assert(reader:short() == 0x0500)

	while not reader:is_end() do
		table.insert(ret, decode_item(reader))
	end
	return ret
end

return decode