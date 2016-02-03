local readme = [[
usage:
lua dump_backup.lua <backup> [domain]
]]

local decode_mbdb = require "decode_mbdb"
local lfs = require "lfs"


local function wraper_decode(backup_path)
	local mbdb_path = backup_path.."/Manifest.mbdb"
	local handle = io.open(mbdb_path, "rb")
	local s = handle:read("a")
	handle:close()
	local data = decode_mbdb(s)

	for i,item in ipairs(data) do
		local backup_filename = item.backup_filename
		item.backup_filepath = backup_path.."/"..backup_filename
	end
	return data
end


local function process_source(data)
	local map = {}
	for i,v in ipairs(data) do
		local domain = v.domain
		local backup_filepath = v.backup_filepath
		local item = map[domain] or {}
		local filename = v.filename
		local filelen  = v.filelen 
		if filename and filename ~= "" and filelen and filelen>0 then
			table.insert(item, v)
		end
		map[domain] = item
	end

	for k, item in pairs(map) do
		table.sort(item, function (a, b) return a.filename < b.filename end)
	end

	return map
end

local function copy(s, d)
	local cmd = string.format('cp "%s" "%s"', s, d)
	local ok = os.execute(cmd)
	if not ok then
		error(cmd)
	end
end


local function recurison_copy(s, d)
	local part = {}
	for v in string.gmatch(d, "[^/\\]+") do 
		part[#part+1] = v
	end

	local path
	for i=1,#part-1 do
		local v = part[i]
		path = path and path.."/"..v or v
		lfs.mkdir(path)
	end

	print("[copy]:", d)
	copy(s, d)
end

----------------------------------------
local  backup, domain = ...
if not backup then
	print(readme)
	os.exit()
end

local source = wraper_decode(backup)
source = process_source(source)

if not domain then
	print("domain list:")
	for k,v in pairs(source) do
		print(k)	
	end
else
	local item = source[domain]
	assert(item)
	for i,v in ipairs(item) do
		local s = v.backup_filepath
		local d = domain.."/"..v.filename
		recurison_copy(s, d)
	end
end
