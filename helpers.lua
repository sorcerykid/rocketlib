-----------------------------------------------------
-- Minetest :: RocketLib Toolkit (rocketlib)
--
-- See README.txt for licensing and release notes.
-- Copyright (c) 2018-2020, Leslie E. Krause
-----------------------------------------------------

-----------------------------
-- Conversion Routines
-----------------------------

local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local byte = string.byte
local match = string.match
local find = string.find
local sub = string.sub

local function to_signed( val )
	return val < 2048 and val or val - 2 * 2048
end

local function decode_pos( idx )
	local x = to_signed( idx % 4096 )
	idx = floor( ( idx - x ) / 4096 )
	local y = to_signed( idx % 4096 )
	idx = floor( ( idx - y ) / 4096 )
	local z = to_signed( idx % 4096 )
	return { x = x, y = y, z = z }
end

local function encode_pos( pos )
	return pos.x + pos.y * 4096 + pos.z * 16777216
end

local function decode_node_pos( node_idx, idx )
	local pos = idx and decode_pos( idx ) or { x = 0, y = 0, z = 0 }
	local node_pos = { }

	node_idx = node_idx - 1		-- correct for one-based indexing of node_list

	node_pos.x = ( node_idx % 16 ) + pos.x * 16
	node_idx = floor( node_idx / 16 )
	node_pos.y = ( node_idx % 16 ) + pos.y * 16
	node_idx = floor( node_idx / 16 )
	node_pos.z = ( node_idx % 16 ) + pos.z * 16

	return node_pos
end

local function encode_node_pos( node_pos )
	local pos = {
		x = floor( node_pos.x / 16 ),
		y = floor( node_pos.y / 16 ),
		z = floor( node_pos.z / 16 )
	}
	local x = node_pos.x % 16
	local y = node_pos.y % 16
	local z = node_pos.z % 16
	return x + y * 16 + z * 256 + 1, encode_pos( pos )	-- correct for one-based indexing of node_list
end

local function hash_node_pos( node_pos )
	return ( node_pos.z + 32768 ) * 65536 * 65536 + ( node_pos.y + 32768 ) * 65536 +  node_pos.x + 32768
end

local function unhash_node_pos( node_hash )
	local node_pos = { }
	node_pos.x = ( node_hash % 65536 ) - 32768
	node_hash  = math.floor( node_hash / 65536 )
	node_pos.y = ( node_hash % 65536 ) - 32768
	node_hash  = math.floor( node_hash / 65536 )
	node_pos.z = ( node_hash % 65536 ) - 32768
	return node_pos
end

-----------------------------
-- Debugging Routines
-----------------------------

local function pos_to_string( pos )
	return string.format( "(%d,%d,%d)", pos.x, pos.y, pos.z )
end

local function hex_dump( buffer )
	for i = 1, ceil( #buffer / 16 ) * 16 do
		if ( i - 1 ) % 16 == 0 then io.write( string.format( '%08X   ', i - 1 ) ) end
		io.write( i > #buffer and '   ' or string.format( '%02x ', buffer:byte( i ) ) )
		if i % 8 == 0 then io.write( ' ' ) end
		if i % 16 == 0 then io.write( buffer:sub( i - 16 + 1, i ):gsub( '%c', '.' ), '\n' ) end
	end
end

-----------------------------

return {
	decode_pos = decode_pos,
	encode_pos = encode_pos,
	decode_node_pos = decode_node_pos,
	encode_node_pos = encode_node_pos,
	hash_node_pos = hash_node_pos,
	unhash_node_pos = unhash_node_pos,
	pos_to_string = pos_to_string,
	hex_dump = hex_dump,
}
