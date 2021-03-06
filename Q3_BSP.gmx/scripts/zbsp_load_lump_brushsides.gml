///zbsp_load_lump_brushsides(buffer, map)
/*
    Loads brushsides lump data from given buffer into the given map
    ==========================================================
    The data can be accessed from the given map with the key "brushsides-data", Which referes to a ds_grid,
    with height same as the value from the map's "brushsides-num" value.
    Each row contains a data for each brushside, With following indices:
    data[# 0, row] : Plane index
    data[# 1, row] : Texture index
*/

var _off = argument1[? "brushsides-diroff"], _len = argument1[? "brushsides-dirlen"];
var _num = _len / global.BSPLumpSizes[@ eBSP_LUMP.BRUSHSIDES], _data;
buffer_seek(argument0, buffer_seek_start, _off);

_data = ds_grid_create(2, _num);
for (var i=0; i<_num; i++)
{
    // plane idx
    _data[# 0, i] = buffer_read(argument0, buffer_s32);
    
    // texture idx
    _data[# 1, i] = buffer_read(argument0, buffer_s32);
}

argument1[? "brushsides-num"] = _num;
argument1[? "brushsides-data"] = _data;
