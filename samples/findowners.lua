--------------------------------------------------------------------------------
-- Here is a handy Lua command line script for listing all nodes that are owned 
-- by specific players (like steel doors, locked chests, etc.) in your map 
-- database. Just change the following variables at the head of the script:
--
--  * path - the path of the map.sqlite database to be read
--  * area - the region of the map to be searched, specified as minimum and 
--    maximum mapblock positions
--  * owner_name- the name of the owner to search for (nil will search for all 
--    owners)
--  * node_name- the name of the owned nodes to search for (nil will search for 
--    all owned nodes)
--
-- Keep in mind, this script can take some time to process very large databases, 
-- so it is strongly recommended to limit the search area to no more than ~50 
-- cubic mapblocks at a time.
--------------------------------------------------------------------------------

dofile( "../maplib.lua" )

local path = "/home/minetest/.minetest/worlds/world/map.sqlite"
local area = MapArea( { x = -25, y = -10, z = -25 }, { x = 25, y = 5, z = 25 } )
local node_name = nil
local node_owner = "sorcerykid"

local map_db = MapDatabase( path, false )
print( "Creating cache..." )
map_db.create_cache( false )
print( "Examining database..." )

local block_total = 0
local node_count = 0

for index, block in map_db.iterate_area( area ) do
        local nodemeta_map = block.get_nodemeta_map( )
        local nodename_map = block.nodename_map
        local node_list

        -- don't waste cpu cycles getting nodes unless there is meta
        if next( nodemeta_map ) then
                node_list = block.get_node_list( )
        end

        block_total = block_total + 1

        for i, m in pairs( nodemeta_map ) do
                local name = nodename_map[ node_list[ i ].id ]
                local owner = m.fields.owner or m.fields.doors_owner

                if owner and ( not node_owner or owner == node_owner ) and ( not node_name or name == node_name ) then
                        node_count = node_count + 1

                        print( string.format( "%s owned by %s at (%s).",
                                name, owner, pos_to_string( decode_node_pos( i, index ) )
                        ) )
                end
        end
end

print( string.format( "Found %d owned nodes (scanned %d map blocks).", node_count, block_total ) )
