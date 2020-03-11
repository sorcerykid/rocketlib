--------------------------------------------------------------------------------
-- This is a command-line script to locate specific items that are placed or 
-- stored anywhere in the world. It is particularly helpful for server operators 
-- that are planning to uninstall a mod, but first want to determine how many 
-- items from that mod are actually in-use.
--
-- At the head of the script are six variables that will need to be set 
-- accordingly:
--
--  * source_path = full path of the map.sqlite database to be opened in read-
--    only mode
--  * search_area = the mapblock boundaries in which to limit the search (set to 
--    nil to search the entire map)
--  * search_items = hash of nodes, tools, or craftitems to find (each element 
--    must be set to 0, as these are counters)
--  * is_placed = whether to check for search items placed as a nodes
--  * is_stored = whether to check for search items stored in node inventories
--    containers = set of inventory nodes to include in search
--
-- The script is optimized so it will automatically skip mapblocks in which 
-- containers (in the case of storage search) or search_items (in the case of 
-- placement search) are not immediately found in the content ID lookup table. 
-- This saves valuable CPU cycles by only parsing and caching the nodemeta_map 
-- and node_list as necessary.
--------------------------------------------------------------------------------

package.path = "/home/minetest/maplib/?.lua;" .. package.path

local maplib = require "maplib"

local source_path = "/home/minetest/.minetest/worlds/test/map.sqlite"
local search_area = MapArea( { x = -10, y = -5, z = -10 }, { x = 10, y = 2, z = 10 } )
local search_items = {
	["default:pick_diamond"] = 0,
	["default:mese"] = 0,
	["default:goldblock"] = 0,
	["default:steelblock"] = 0,
	["default:steel_ingot"] = 0,
	["default:gold_ingot"] = 0,
	["nyancat:nyancat"] = 0,
}
local is_placed = false
local is_stored = true
local containers = {
	["bones:bones"] = true,
	["default:chest"] = true,
	["default:chest_locked"] = true,
	["protector:chest"] = true,
}

---------------------------------------

local decode_node_pos = maplib.decode_node_pos
local pos_to_string = maplib.pos_to_string

local function has_containers( block )
	if is_stored then
		for i, n in pairs( block.nodename_map ) do
			if containers[ n ] then
				return true
			end
		end
	end
	return false
end

local function has_search_items( block )
	if is_placed then
		for i, n in pairs( block.nodename_map ) do
			if search_items[ n ] then
				return true	-- there is at least one, so confirm!
			end
		end
	end
	return false
end

local function stored_items_search( block, index, node_list, nodename_map )
	local is_found = false
	local nodemeta_map = block.get_nodemeta_map( )

        for pos, meta in pairs( nodemeta_map ) do
	        local node_name = nodename_map[ node_list[ pos ].id ]

		if containers[ node_name ] and meta.inventory.main then
			for idx, slot in ipairs( meta.inventory.main ) do
				local item_name = slot.name
				local item_count = slot.count

				if search_items[ item_name ] then
					is_found = true
					search_items[ item_name ] = search_items[ item_name ] + item_count

					if meta.fields.owner then
						print( string.format( "[%d] Found %d of item '%s' stored in slot %d of %s owned by %s at %s.",
							index, item_count, item_name, idx, node_name, meta.fields.owner, pos_to_string( decode_node_pos( pos, index ) )
						) )
					else
						print( string.format( "[%d] Found %d of item '%s' stored in slot %d of %s at %s.",
							index, item_count, item_name, idx, node_name, pos_to_string( decode_node_pos( pos, index ) )
						) )
					end
				end
			end
		end
	end

	return is_found
end

local function placed_items_search( block, index, node_list, nodename_map )
	local is_found = false

	for pos, node in ipairs( node_list ) do
		local node_name = nodename_map[ node.id ]

		if search_items[ node_name ] then
			is_found = true
			search_items[ node_name ] = search_items[ node_name ] + 1

			print( string.format( "[%d] Found item '%s' placed at %s.",
				index, node_name, pos_to_string( decode_node_pos( pos, index ) )
			) )
		end
	end

	return is_found
end

-----------------------------------------

local map_db = MapDatabase( source_path, false )

if search_area then
	print( "Creating cache..." )
	map_db.create_cache( false )
end

print( "Examining database..." )

local iterator = search_area and map_db.iterate_area( search_area ) or map_db.iterate( )
local mapblock_count = 0
local mapblock_total = 0

if not is_stored and not is_placed then
	error( "Nothing to search for, aborting." )
end

for index, block in iterator do
	local has_containers = has_containers( block )
	local has_search_items = has_search_items( block )

	if has_containers or has_search_items then
		local node_list = block.get_node_list( )
		local nodename_map = block.nodename_map
		local is_found = false

		if is_stored and has_containers then
			is_found = stored_items_search( block, index, node_list, nodename_map )
		end
		if is_placed and has_search_items then
			is_found = placed_items_search( block, index, node_list, nodename_map )
		end

		if is_found then
			mapblock_count = mapblock_count + 1
		end
	end
	mapblock_total = mapblock_total + 1
end

print( string.format( "%d of %d mapblocks have %s search items.",
	mapblock_count,
	mapblock_total,
	not is_stored and "placed" or not is_placed and "stored" or "placed and stored"
) )

for i, v in pairs( search_items ) do
	print( string.format( "Found %d of item '%s'.", v, i ) )
end
