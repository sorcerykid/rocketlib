-----------------------------------------------------
-- Minetest :: RocketLib Toolkit (rocketlib)
--
-- See README.txt for licensing and release notes.
-- Copyright (c) 2018-2020, Leslie E. Krause
-----------------------------------------------------

package.cpath = package.cpath .. ";/usr/local/lib/lua/5.1/?.so"

local zlib = require( "zlib" )				-- https://luarocks.org/modules/brimworks/lua-zlib
local sqlite3 = require( "lsqlite3complete" )		-- https://luarocks.org/modules/dougcurrie/lsqlite3
local helpers = require( "helpers" )

-----------------------------

local decode_pos = helpers.decode_pos

local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local byte = string.byte
local match = string.match
local find = string.find
local sub = string.sub
local _ = { }

local function is_match( text, glob )
	-- use array for captures
	_ = { match( text, glob ) }
	return #_ > 0 and _ or nil
end

-----------------------------
-- BlobReader Class
-----------------------------

function BlobReader( input )
	local idx = 1
	local self = { }

	-- private methods

	local function u16_to_signed( val )
		return val < 32767 and val or val - 2 * 32767
	end
	local function u32_to_signed( val )
		return val < 2147483647 and val or val - 2 * 2147483647
	end

	-- public methods

	self.read_u8 = function ( )
		local output = byte( input, idx )
		idx = idx + 1
		return output
	end
	self.read_u16 = function ( )
		-- 16-bit unsigned integer
		local output = byte( input, idx ) * 256 + byte( input, idx + 1 )
		idx = idx + 2
		return output
	end
	self.read_u32 = function ( )
		-- 32-bit unsigned integer
		local output = byte( input, idx ) * 16777216 + byte( input, idx + 1 ) * 65536 + byte( input, idx + 2 ) * 256 + byte( input, idx + 3 )
		idx = idx + 4
		return output
	end
	self.read_s16 = function ( )
		-- 16-bit signed integer
		local output = u16_to_signed( byte( input, idx ) * 256 + byte( input, idx + 1 ) )
		idx = idx + 2
		return output
	end
	self.read_s32 = function ( )
		-- 32-bit signed integer
		local output = u32_to_signed( byte( input, idx ) * 16777216 + byte( input, idx + 1 ) * 65536 + byte( input, idx + 2 ) * 256 + byte( input, idx + 3 ) )
		idx = idx + 4
		return output
	end
	self.read_f1000 = function ( )
		local output = self.read_s32( ) / 1000
		return output
	end
	self.read_v3f10000 = function ( )
		local output = { x = self.read_s32( ) / 10000, y = self.read_s32( ) / 10000, z = self.read_s32( ) / 10000 }
		return output
	end
	self.read_zlib = function ( )
		output, is_eof, bytes_in, bytes_out = zlib.inflate( )( sub( input, idx ) )
		idx = idx + bytes_in
		return output
	end
	self.read_string = function ( len )
		if not len then
			-- multiline string
			local len = find( input, "\n", idx ) - idx
			local output = sub( input, idx, idx + len - 1 )
			idx = idx + len + 1
			return output
		else
			-- non-terminated string
			local output = sub( input, idx, idx + len - 1 )
			idx = idx + len
			return output
		end
	end
	return self
end

-----------------------------
-- Deserializer Routines
-----------------------------

local function parse_node_list( blob )
	local p = BlobReader( blob )
	local this = { }

	for idx = 1, 4096 do
		this[ idx ] = { id = p.read_s16( ) }
	end
	for idx = 1, 4096 do
		this[ idx ].param1 = p.read_u8( )
	end
	for idx = 1, 4096 do
		this[ idx ].param2 = p.read_u8( )
	end

	return this
end

local function parse_nodemeta_map( blob )
	local p = BlobReader( blob )
	local this = { }

	local version = p.read_u8( )
	if version == 0 then
		return this, 0
	elseif version > 3 then
		error( "Unsupported node_metadata version, aborting!" )
	end

	local node_total = p.read_u16( )
	for node_count = 1, node_total do
		local pos = p.read_u16( ) + 1		-- use one-based indexing to correspond with node_list array
		local var_total = p.read_u32( )

		this[ pos ] = { fields = { }, inventory = { }, privacy = { } }

		for var_count = 1, var_total do
			local key = p.read_string( p.read_u16( ) )	-- 16-bit length string
			local value = p.read_string( p.read_u32( ) )	-- 32-bit length string
			local is_private = version >= 2 and ( p.read_u8( ) == 1 ) or false

			this[ pos ].fields[ key ] = value
			if is_private then
				table.insert( this[ pos ].privacy, key )
			end
		end

		local list
		for inv_count = 1, 127 do
			local text = p.read_string( )

			if is_match( text, "^List (%S+) %d+" ) then
				list = { }
				this[ pos ].inventory[ _[ 1 ] ] = list
			elseif text == "Empty" then
				table.insert( list, { } )
			elseif is_match( text, "^Item (%S+)$" ) or is_match( text, "^Item (%S+) (%d+)$" ) or is_match( text, "^Item (%S+) (%d+) (%d+)$" ) or is_match( text, "^Item (%S+) (%d+) (%d+) (.+)$" ) then
				table.insert( list, {
					name = _[ 1 ],
					count = tonumber( _[ 2 ] ) or 1,
					wear = tonumber( _[ 3 ] ) or 0,
					metadata = _[ 4 ] or "",
				} )
			elseif text == "EndInventoryList" then
				list = nil
			elseif text == "EndInventory" then
				break
			end
		end
	end

	return this, node_total
end

local function parse_object( blob )
	local p = BlobReader( blob )
	local this = { }

	this.version = p.read_u8( )
	this.name = p.read_string( p.read_u16( ) )
	this.staticdata = p.read_string( p.read_u32( ) )

	if this.version == 1 then
		this.hp = p.read_s16( )
		this.velocity = p.read_f1000( ) / 10
		this.yaw = p.read_f1000( ) / 10		
	end

	return this
end

------------------------
-- MapBlock Class
------------------------

function MapBlock( blob, is_preview, get_checksum )
	local self = { }

	self.checksum, self.length = get_checksum( blob )

	if is_preview then return self end

	----------

	local p = BlobReader( blob )

	self.version = p.read_u8( )
	self.flags = p.read_u8( )
	if self.version >= 27 then
		self.lighting_complete = p.read_u16( )
	end
	self.content_width = p.read_u8( )
	self.params_width = p.read_u8( )
	if self.params_width ~= 2 then
		error( "Invalid params_width, aborting!" )
	end
	if self.content_width ~= 1 and self.version < 24 or self.content_width ~= 2 and self.version >= 24 then
		error( "Invalid params_width, aborting!" )
	end

	----------

	local node_list_raw = p.read_zlib( )
	if #node_list_raw ~= 4096 * self.content_width * self.params_width then
		error( "Invalid node_list, aborting!" )
	end

	----------

	local nodemeta_list_raw = p.read_zlib( )

	----------

	if self.version == 23 then
		p.read_u8( )	-- unused
	end

	----------

	self.object_list = { }

	local obj_version = p.read_u8( )
	local obj_total = p.read_u16( )
	for obj_count = 1, obj_total do
		local type = p.read_u8( )
		local pos = p.read_v3f10000( )
		local blob =  p.read_string( p.read_u16( ) )

		local object = parse_object( blob )
		object.type = type
		object.pos = pos

		table.insert( self.object_list, object )
	end

	self.timestamp = p:read_u32( )

	----------

	self.nodename_map = { }

	local map_version = p.read_u8( )
	local map_total = p.read_u16( )
	for map_total = 1, map_total do
		local id = p.read_s16( )
		local name = p.read_string( p.read_u16( ) )
		self.nodename_map[ id ] = name
	end

	----------

	-- TODO: parse timers

	----------

	self.get_node_list = function ( ) 
		return parse_node_list( node_list_raw )
	end
	self.get_nodemeta_map = function ( )
		return parse_nodemeta_map( nodemeta_list_raw )
	end

	return self
end

-----------------------------
-- NodeMetaRef Class
-----------------------------

function NodeMetaRef( block )
	local self = { }
	local nodemeta_map, length = block.get_nodemeta_map( )

	self.length = length

	self.is_private = function ( idx, key )
		for i, v in ipairs( nodemeta_map[ idx ].privacy ) do
			if v == key then return true end
		end
		return false
	end
	self.contains = function ( idx, key )
		return nodemeta_map[ idx ].fields[ key ] ~= nil
	end
	self.get_raw = function ( idx, key )
		local this = nodemeta_map[ idx ]
		return this and this.fields[ key ]
	end
	self.get_string = function ( idx, key )
		return self.get_raw( idx, key ) or ""
	end
	self.get_float = function ( idx, key )
		return tonumber( self.get_raw( idx, key ) ) or 0
	end
	self.get_int = function ( idx, key )
		local val = tonumber( self.get_raw( idx, key ) ) or 0
		return val > 0 and math.floor( val ) or math.ceil( val )
	end
	self.to_table = function ( idx )
		local this = nodemeta_map[ idx ]
		return this and { fields = this.fields, inventory = this.inventory } or { fields = { }, inventory = { } }
	end
	self.iterate = function ( )
		return next, nodemeta_map, nil
	end

	return self
end

-----------------------------
-- MapArea Class
-----------------------------

function MapArea( pos1, pos2 )
	local self = { }

	-- presort positions and clamp to designated boundaries
	local x1 = max( min( pos1.x, pos2.x ), -2048 )
	local y1 = max( min( pos1.y, pos2.y ), -2048 )
	local z1 = max( min( pos1.z, pos2.z ), -2048 )
	local x2 = min( max( pos1.x, pos2.x ), 2048 )
	local y2 = min( max( pos1.y, pos2.y ), 2048 )
	local z2 = min( max( pos1.z, pos2.z ), 2048 )

	self.get_min_pos = function ( )
		return { x = x1, y = y1, z = z1 }
	end

	self.get_max_pos = function ( )
		return { x = x2, y = y2, z = z2 }
	end

	self.get_volume = function ( )
		return ( z2 - z1 + 1 ) * ( y2 - y1 + 1 ) * ( x2 - x1 + 1 )
	end

	self.has_index = function ( idx )
		local x = to_signed( idx % 4096 )
		if x < x1 or x > x2 then return false end

		idx = floor( ( idx - x ) / 4096 )
		local y = to_signed( idx % 4096 )
		if y < y1 or y > y2 then return false end

		idx = floor( ( idx - y ) / 4096 )
		local z = to_signed( idx % 4096 )
		if z < z1 or z > z2 then return false end

		return true
	end

	self.has_pos = function ( pos )
		if pos.x < x1 or pos.x > x2 or pos.y < y1 or pos.y > y2 or pos.z < z1 or pos.z > z2 then
			return false
		end
		return true
	end

	self.iterator = function ( )
		local x
		local y = y1
		local z = z1
		return function ( )
			if not x then
				x = x1
			elseif x < x2 then
				x = x + 1 
			elseif y < y2 then
				x = x1
				y = y + 1
			elseif z < z2 then
				x = x1
				y = y1
				z = z + 1
			else
				return nil
			end
			return x + y * 4096 + z * 16777216
		end
	end

	return self
end

-----------------------------
-- MapDatabase Class
-----------------------------

function MapDatabase( path, is_preview, is_summary, algorithm )
	local self = { }
	local map_db = sqlite3.open( path, sqlite3.OPEN_READONLY )
	local cache_db
	local init_checksum = ( { crc32 = zlib.crc32, adler32 = zlib.alder32 } )[ algorithm or "crc32" ]

	if not map_db then
		error( "Cannot open map database, aborting!" )
	end

	local map_select_pos = map_db:prepare( "SELECT data FROM blocks WHERE pos = ?" )
	local map_select = map_db:prepare( "SELECT pos, data FROM blocks" )

	self.enable_preview = function ( )
		is_preview = true
	end

	self.disable_preview = function ( )
		is_preview = false
	end

	self.enable_summary = function ( )
		is_summary = true
	end

	self.disable_summary = function ( )
		is_summary = false
	end

	self.create_cache = function ( use_memory, on_step )
		cache_db = use_memory and sqlite3.open_memory( ) or sqlite3.open( path .. "-cache" )

		if not cache_db then
			error( "Cannot open cache database, aborting!" )
		end
		for _ in cache_db:rows( "SELECT * FROM sqlite_master WHERE name = 'catalog' and type = 'table'" ) do return end

		if cache_db:exec( "CREATE TABLE catalog (pos INTEGER PRIMARY KEY, x INTEGER, y INTEGER, z INTEGER)" ) ~= sqlite3.OK then
			error( "Cannot update cache database, aborting!" )
		end

		local stmt = cache_db:prepare( "INSERT INTO catalog VALUES (?, ?, ?, ?)" )

		cache_db:exec( "BEGIN" )	-- combine into single transaction
		for index in map_db:urows( "SELECT pos FROM blocks" ) do
			if on_step then on_step( ) end

			local pos = decode_pos( index )

			stmt:reset( )
			stmt:bind_values( index, pos.x, pos.y, pos.z )
			if stmt:step( ) ~= sqlite3.DONE then
				error( "Cannot update cache database, aborting!" )
			end
		end
		cache_db:exec( "END" )
	end

	self.get_length = function ( )
		if not cache_db then
			for total in map_db:urows( "SELECT count(*) FROM blocks" ) do
				return total
			end
		else
			for total in cache_db:urows( "SELECT count(*) FROM catalog" ) do
				return total
			end
		end
	end

	self.get_area_length = function ( area )
		if not cache_db then return end

		local stmt = cache_db:prepare( "SELECT count(*) FROM catalog WHERE x >= ? AND x <= ? AND y >= ? AND y <= ? AND z >= ? AND z <= ?" )
		local min_pos = area.get_min_pos( )
		local max_pos = area.get_max_pos( )

		stmt:bind_values( min_pos.x, max_pos.x, min_pos.y, max_pos.y, min_pos.z, max_pos.z )
		for total in stmt:urows( ) do
			return total
		end
	end

	self.iterate = function ( on_step )
		local get_checksum
		local stmt = map_select
		stmt:reset( )

		if is_summary then
			get_checksum = init_checksum( )
		end

		return function ( )
			if stmt:step( ) ~= sqlite3.ROW then return end

			if on_step then on_step( ) end

			local index = stmt:get_value( 0 )
			local block = MapBlock( stmt:get_value( 1 ), is_preview, get_checksum or init_checksum( ) )
			return index, block
		end
	end

	self.iterate_area = function ( area, on_step )
		if not cache_db then return end

		-- provided cache database, query indices of all mapblocks within
		-- area, then return each index and parsed block
		local stmt = cache_db:prepare( "SELECT pos FROM catalog WHERE x >= ? AND x <= ? AND y >= ? AND y <= ? AND z >= ? AND z <= ?" )

		local min_pos = area.get_min_pos( )
		local max_pos = area.get_max_pos( )

		stmt:bind_values( min_pos.x, max_pos.x, min_pos.y, max_pos.y, min_pos.z, max_pos.z )

		if is_summary then
			get_checksum = init_checksum( )
		end

		return function ( )
			if stmt:step( ) ~= sqlite3.ROW then
				stmt:finalize( )
				return
			end
			if on_step then on_step( ) end

			local index = stmt:get_value( 0 )
			local block = self.get_mapblock( index, get_checksum or init_checksum( ) )
			return index, block
		end
	end

	self.select = function ( on_step )
		for index in map_db:urows( "SELECT pos FROM blocks" ) do
			if on_step then on_step( ) end

			table.insert( index_list, index )
		end
		return index_list
	end

	self.select_area = function ( area, on_step )
		local index_list = { }

		local stmt = cache_db:prepare( "SELECT pos FROM catalog WHERE x >= ? AND x <= ? AND y >= ? AND y <= ? AND z >= ? AND z <= ?" )

		local min_pos = area.get_min_pos( )
		local max_pos = area.get_max_pos( )

		stmt:bind_values( min_pos.x, max_pos.x, min_pos.y, max_pos.y, min_pos.z, max_pos.z )
		for index in stmt:urows( ) do
			if on_step then on_step( ) end
			table.insert( index_list, index )
		end

		return index_list
	end

	self.has_index = function ( index )
		local stmt = map_select_pos

		stmt:reset( )
		stmt:bind_values( index )
		return stmt:step( ) == sqlite3.ROW
	end

	self.get_mapblock = function ( index )
		local stmt = map_select_pos

		stmt:reset( )
		stmt:bind_values( index )
		if stmt:step( ) == sqlite3.ROW then
			return MapBlock( stmt:get_value( 0 ), is_preview, init_checksum( ) )
		end
	end

	self.get_mapblock_raw = function ( index )
		local stmt = map_select_pos

		stmt:reset( )
		stmt:bind_values( index )
		if stmt:step( ) == sqlite3.ROW then
			return stmt:get_value( 0 )
		end
	end

	self.close = function ( )
		map_db:close( )
	end

	return self
end

-----------------------------

return helpers
