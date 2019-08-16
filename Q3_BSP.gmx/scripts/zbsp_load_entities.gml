///zbsp_load_entities(buffer, map)
/*
    Loads entities data from given buffer into the given map
*/
var _off = argument1[? "entities-diroff"], _len = argument1[? "entities-dirlen"];
buffer_seek(argument0, buffer_seek_start, _off);

argument1[? "entities"] = zbsp_read_str(argument0, _len);
