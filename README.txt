RocketLib Toolkit v1.3
By Leslie E. Krause

RocketLib Toolkit is a purely Lua-driven SQLite3 map reader with an extensive API for 
analysis of map databases. The library is intended primarily for use by server operators,
but anybody with Lua programming experience can develop their own command-line tools.

Just to showcase how easy it is to get started examining your map database, it takes only 
16 lines of Lua code to search for all mapblocks that have dropped items:

>  local maplib = require "maplib"
>  local map_db = MapDatabase( "/home/minetest/worlds/world/map.sqlite", false )
>
>  for index, block in map_db.iterate( ) do
>          local count = 0
>          for i, v in ipairs( block.object_list ) do
>                  if v.name == "__builtin:item" then
>                          count = count + 1
>                  end
>          end
>          if count > 0 then
>                  print( string.format( "%d dropped items in mapblock (%s)", 
>                          count, maplib.pos_to_string( maplib.decode_pos( index ) )
>                  ) )
>          end
>  end

Important: If your map database exceeds 1GB in size, then a RAM-disk (tmpfs on Linux) is 
strongly recommended for optimal performance. Based on personal experience, there can be
upwards of a ten-fold improvement in speed, particularly for intensive queries.

The map reader library provides a fully object-oriented API, so it is straightfoward to 
examine mapblocks and their contents without having to worry about the underlying 
database architecture.

Before you begin, you will need to extend the package path at the head of your script.
This way Lua will be able to locate the RocketLib modules:

>  package.path = "/home/minetest/rocketlib/?.lua;" .. package.path
>
>  local maplib = require "maplib"

Be sure to amend the path with the installation directory of RocketLib on your system.

The available class constructors are as follows:

 * BlobReader( input )
   Provides an interface to serially parse a BLOB with a variety of known datatypes.

    * "input" is the BLOB to parse, typically the raw mapblock data obtained from the 
      "data" field of the "blocks" table

   The BlobReader class defines the following public methods:

    * BlobReader::read_u8( )
      Read an 8-bit unsigned integer and advance the pointer by one byte.

    * BlobReader::read_u16( )
      Read a 16-bit unsigned integer and advance the pointer by two bytes.

    * BlobReader::read_u32( )
      Read a 32-bit unsigned integer and advance the pointer by four bytes.

    * BlobReader::read_s16( )
      Read a 16-bit signed integer and advance the pointer by two bytes.

    * BlobReader::read_s32( )
      Read a 32-bit signed integer and advance the pointer by four bytes.

    * BlobReader::read_f1000( )
      Read a floating point and advance the pointer by four bytes.

    * BlobReader::read_v3f1000( )
      Read a 3-dimensional floating point array and advance the pointer by 12 bytes.

    * BlobReader::read_zlip( )
      Slurp a zlib compressed data stream and advance the pointer accordingly.

    * BlobReader::read_string( len )
      Read a non-terminated text string of len bytes and then advance the pointer 
      accordingly to len. If len is not provided, slurp a multiline terminated text 
      string and advance the pointer accordingly.

 * MapArea( pos1, pos2 )
   Delineates a mapblock area to be examined, while also providing various area 
   calculation methods.

    * "pos1" is lowest boundary mapblock position to iterate
    * "pos2" is the highest boundary mapblock position to iterate

   The MapArea class provides the following public methods:

    * MapArea::get_min_pos( )
      Return the lowest boundary mapblock position of the area as a table {x,y,z}

    * MapArea::get_max_pos( )
      Return the highest boundary mapblock position of the area as a table {x,y,z}

    * MapArea::get_volume( )
      Calculate the volume of the area in cubic mapblocks and return the result

    * MapArea::has_index( idx )
      Returns true if the specified mapblock index is contained within the area

    * MapArea::has_pos( pos )
      Returns true if the specified mapblock position is contained within the area

    * MapArea::iterate( )
      Returns an iterator for looping through the area by mapblock index

 * MapBlock( blob, is_preview, get_checksum )
   Parses the mapblock data and calculates the associated checksum. For efficiency, the 
   nodemeta map and the node list are not parsed automatically, but they can be obtained 
   using the corresponding methods.

    * "blob" is the raw mapblock data obtained from "data" field of the "blocks" table
    * "is_preview" is a boolean indicating whether to parse the BLOB
    * "get_checksum" is the function to calculate the checksum and length of the BLOB

   The MapBlock class defines the following public methods:

    * MapBlock::get_node_list( )
      Parses the raw node list of the mapblock and returns a node_list table.

      The node_list table is an ordered array of exactly 4096 elements corresponding to the 
      16x16x16 matrix of nodes comprising the mapblock. The position of a node can be 
      obtained using the decode_node_pos( ) helper function. Each entry of the node_list 
      table is a subtable with three fields: id, param1, and param2.

      Note that the id refers to the content ID which varies between mapblocks. You must 
      cross-reference the content ID to determine the actual registered node name.

    * MapBlock::get_nodemeta_map( )
      Parses the raw nodemeta map and returns a nodemata_map table.

      The nodemeta_map table is an associative array of node indexes mapped to node metadata. 
      Each entry of the nodemeta_map table is a subtable with the following fields:

       * "fields" is an associative array of user-defined metadata for the node
       * "privacy" is an ordered array of node metadata keys that have been marked as private
       * "inventory" is an associative array of inventory lists for the node, each containing 
         an ordered array of subtables with four fields: name, count, wear, and metadata

   The MapBlock class defines the following public read-only properties:

    * MapBlock::version
      The version of the mapblock.

    * MapBlock::flags
      The flags of the mapblock.

    * MapBlock::content_width
      The size of the content_ids in bytes. This is either 1 or 2, based on the version.

    * MapBlock::params_width
      The size of param1 and param2 in bytes. This is always 2.

    * MapBlock::object_list
      An ordered array of objects stored in the mapblock. Each entry contains a subtable with 
      seven fields: type, pos, version, name, staticdata, hp, velocity, and yaw.

    * MapBlock::nodename_map
      An associative array of contend IDs mapped to registered node names.

    * MapBlock::timestamp
      The timetamp when the mapblock was last modified by the engine. Note that this 
      value is not necessarily a reliable means to determine if a mapblock was changed or 
      not. For that you should perform a checksum comparison.

 * MapDatabase( path, is_preview, is_summary, algorithm )
   Opens an existing map.sqlite database from disk and prepares the necessary SQL statements.

    * "path" is the path to the sqlite3 map database to be opened in read-only mode
    * "is_preview" is a boolean indicating whether mapblocks are to be parsed by default 
      (optional)
    * "is_summary" is a boolean indicating whether checksums apply to all mapblocks by 
      default (optional)
    * "algorithm" specifies which checksum algorithm to use, either "adler32" or "crc32"
      (optional)

   The MapDatabase class defines the following public methods:

    * MapDatabase::enable_preview( )
      Enable parsing of mapblocks by default

    * MapDatabase::disable_preview( )
      Disable parsing of mapblocks by default, only calculate checksum and length

    * MapDatabase::enable_summary( )
      Enable cumulative checksum and length calculations by default

    * MapDatabase::disable_summary( )
      Disable cumulative checksum and length calculations by default

    * MapDatabase::create_cache( use_memory, on_step )
      Create a cache database storing cross-references of mapblock indexes to positions, 
      thereby speeding up successive queries. If use_memory is true, the cache database 
      will be memory resident. Otherwise a file named "map.sqlite-cache" will be created 
      in the same directory as the map database. The optional on_step hook can be used to 
      update a progress bar for lengthy operations.

    * MapDatabase::get_length( )
      Returns the total number of existing mapblocks. If the cache is available, then it 
      will be used.

    * MapDatabase::get_area_length( area )
      Returns the total number of mapblocks inside the given area. The cache is required 
      for this operation.

    * MapDatabase::iterate( on_step )
      Returns an iterator function for looping over all existing mapblocks. The optional 
      on_step hook can be used to update a progress bar for length operations

    * MapDatabase::iterate_area( area, on_step )
      Returns an iterator function, for looping over all existing mapblocks inside the 
      given area. The optional on_step hook can be used to update a progress bar for 
      lengthy operations. The cache is required for this operation.

    * MapDatabase::select( on_step )
      Returns an array of indexes for all existing mapblocks. The optional on_step 
      hook can be used to update a progress bar for lengthy operations. The cache is not 
      used for this operation (but I will consider making it optional)

    * MapDatabase::select_area( area, on_step )
      Returns an array of indexes for all existing mapblocks inside the given area. The 
      optional on_step hook can be used to update a progress bar for lengthy operations. 
      The cache is required for this operation.

    * MapDatabase::has_index( index )
      Returns a boolean indicating whether a mapblock exists with the given index

    * MapDatabase::get_mapblock( index )
      Returns the mapblock with the given index as a MapBlock object.

    * MapDatabase::get_mapblock_raw( index, get_checksum )
      Returns the raw mapblock data as a BLOB without calculating the checksum and length

    * MapDatabase::close( index, get_checksum )
      Closes the map database and the cache database

Several helper functions are also available for debugging and conversion purposes.

 * maplib.decode_pos( index )
   Converts the given mapblock index to a mapblock position.

 * maplib.encode_pos( pos )
   Converts the given mapblock position to a mapblock index.

 * maplib.decode_node_pos( node_index, index )
   Converts the given node index within the given mapblock to a node 
   position in world coordinates. If the mapblock index is not provided, then the 
   result will be relative to a mapblock at (0,0,0). Note: For consistency with Lua 
   conventions, node indexes are always 1-based even though mapblock indexes are not.

 * maplib.encode_node_pos( node_pos )
   Converts the given node position in world coordinates to both a node index and a 
   mapblock index.

 * maplib.hash_node_pos( node_pos )
   Returns the equivalent of minetest.hash_node_position( ).

 * maplib.unhash_node_pos( node_hash )
   Returns the equivalent of minetest.get_position_from_hash( ).

 * maplib.pos_to_string( pos )
   Returns a string representing the given position as "(x,y,z)".

 * maplib.dump( buffer )
   Returns a string representing a memory dump of the given buffer

For simplicity, you may wish to localize these functions at the head of your script. Also
note that you can use these helper functions without loading the entire RocketLib API:

>  local maplib = require "helpers"	-- just the minimal API
>  
>  print( maplib.pos_to_string( { x = 0, y = 10, z = 0 } ) )

This can be useful in post-processing scripts, when you need to perform conversions but
without directly accessing the map database.


Repository
----------------------

Browse source code...
  https://bitbucket.org/sorcerykid/rocketlib

Download archive...
  https://bitbucket.org/sorcerykid/rocketlib/get/master.zip
  https://bitbucket.org/sorcerykid/rocketlib/get/master.tar.gz

Installation
----------------------

RocketLib Toolkit depends on the Lua modules lsqlite3 and zblip, which can be installed 
using Luarocks.

Luarocks itself can be obtained from
https://github.com/luarocks/luarocks/wiki/Download


License of source code
----------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2020, Leslie Krause (leslie@searstower.org)

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

For more details:
https://opensource.org/licenses/MIT
