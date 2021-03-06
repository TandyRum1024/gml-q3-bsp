///zbsp_load_lump_leafbrushes(buffer, map)
/*
    Loads leafbrushes lump data from given buffer into the given map
    ==========================================================
    The data can be accessed from the given map with the key "leafbrushes-data", Which refers to a ds_list,
    with length same as the value from the map's "leafbrushes-num" value.
    The list contains the brush index.
*/

var _off = argument1[? "leafbrushes-diroff"], _len = argument1[? "leafbrushes-dirlen"];
var _num = _len / global.BSPLumpSizes[@ eBSP_LUMP.LEAFBRUSHES], _data;
buffer_seek(argument0, buffer_seek_start, _off);

_data = ds_list_create();
for (var i=0; i<_num; i++)
{
    // brush idx
    ds_list_add(_data, buffer_read(argument0, buffer_s32));
}

argument1[? "leafbrushes-num"] = _num;
argument1[? "leafbrushes-data"] = _data;
