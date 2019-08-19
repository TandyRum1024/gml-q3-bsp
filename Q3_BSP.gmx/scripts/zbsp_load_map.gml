///zbsp_load_map(filename)
/*
    Loads Quake 3 map from zip/pk3 file, And returns ds_map containing the map information.
*/

// ==================================================================
/// define variables
// ==================================================================
// helper variables that will help you (& me) to index the bsp map data structure
enum eBSPLUMP
{
    ENTITIES = 0,
    TEXTURES,
    PLANES,
    NODES,
    LEAFS,
    LEAFFACES,
    LEAFBRUSHES,
    MODELS,
    BRUSHES,
    BRUSHSIDES,
    VERTICES,
    MESHVERTS,
    EFFECTS,
    FACES,
    LIGHTMAPS,
    LIGHTVOLS,
    VISDATA
}
var _idx = 0;
global.BSPLumpNames = -1; // Lump names in string
global.BSPLumpSizes = -1; // Each lumps size in bytes
global.BSPLumpNames[_idx] = "entities"; global.BSPLumpSizes[_idx++] = 1;
global.BSPLumpNames[_idx] = "textures"; global.BSPLumpSizes[_idx++] = 72;
global.BSPLumpNames[_idx] = "planes"; global.BSPLumpSizes[_idx++] = 16;
global.BSPLumpNames[_idx] = "nodes"; global.BSPLumpSizes[_idx++] = 36;
global.BSPLumpNames[_idx] = "leafs"; global.BSPLumpSizes[_idx++] = 48;
global.BSPLumpNames[_idx] = "leaffaces"; global.BSPLumpSizes[_idx++] = 4;
global.BSPLumpNames[_idx] = "leafbrushes"; global.BSPLumpSizes[_idx++] = 4;
global.BSPLumpNames[_idx] = "models"; global.BSPLumpSizes[_idx++] = 40;
global.BSPLumpNames[_idx] = "brushes"; global.BSPLumpSizes[_idx++] = 12;
global.BSPLumpNames[_idx] = "brushsides"; global.BSPLumpSizes[_idx++] = 8;
global.BSPLumpNames[_idx] = "vertices"; global.BSPLumpSizes[_idx++] = 44;
global.BSPLumpNames[_idx] = "meshverts"; global.BSPLumpSizes[_idx++] = 4;
global.BSPLumpNames[_idx] = "effects"; global.BSPLumpSizes[_idx++] = 72;
global.BSPLumpNames[_idx] = "faces"; global.BSPLumpSizes[_idx++] = 104;
global.BSPLumpNames[_idx] = "lightmaps"; global.BSPLumpSizes[_idx++] = 49152;
global.BSPLumpNames[_idx] = "lightvols"; global.BSPLumpSizes[_idx++] = 8;
global.BSPLumpNames[_idx] = "visdata"; global.BSPLumpSizes[_idx++] = 1;

// data related variables
var bspdata = ds_map_create(); // map containing the bsp data
var _filetype = string_delete(filename_ext(argument0), 1, 1);
var _filename = string_copy(filename_name(argument0), 1, string_pos(".", argument0) - 1);

// setup values
bspdata[? "success"] = true;
bspdata[? "error"] = "";
bspdata[? "filetype"] = _filetype;
bspdata[? "filename"] = _filename;
bspdata[? "map-name"] = _filename;
bspdata[? "debug_log"] = "ZBSP_LOAD_MAP() BEGIN... FILE : [" + string(argument0) + "]#===#";

if (!file_exists(argument0))
{
    /// file doesn't exist : bail out
    zbsp_append_log(bspdata, "FILE NOT EXISTS... ABORT");
    
    bspdata[? "success"] = false;
    bspdata[? "error"] = "NOFILE";
    zbsp_append_log(bspdata, "ZBSP_LOAD_MAP() END");
    return bspdata;
}

// ==================================================================
/// unpack zip/pk3 file before processing
// ==================================================================
var _datafolder = "bspdata";
var _mapfolder = _datafolder + "\map\" + _filename;
var _assetfolder = _datafolder + "\res";
var _bspfile = "";

// add map resource direction to the map so we can access those later
bspdata[? "res-dir"] = _mapfolder;

if (!directory_exists(_assetfolder))
{
    zbsp_append_log(bspdata, "Unpacking base assets... this might take a while");
    show_debug_message("Unpacking base assets... this might take a while");
    
    zip_unzip("hires_assets.pk3", _assetfolder);
}

zbsp_append_log(bspdata, "Unpacking level...");
zbsp_append_log(bspdata, "FILETYPE : " + _filetype);
show_debug_message("Unpacking level...");

// create directory if needed
if (!directory_exists(_datafolder))
{
    directory_create(_datafolder);
    zbsp_append_log(bspdata, "Data folder not found; Making one...");
}
if (!directory_exists(_mapfolder))
{
    directory_create(_mapfolder);
    zbsp_append_log(bspdata, "Map folder not found; Making one...");
}

zbsp_append_log(bspdata, "DATA FOLDER : " + _datafolder);

// Do appropriate processings for each given file types
var _result = 0;
switch (_filetype)
{
    case "zip": // zip files - contains pk3 which contains the bsp file and textures
        if (!directory_exists(_mapfolder + "\unzip")) directory_create(_mapfolder + "\unzip");
        
        _result |= zip_unzip(argument0, _mapfolder + "\unzip"); // unzip contents (normally map preview pictures and info)
        _result |= zip_unzip(_mapfolder + "\unzip\" + _filename + ".pk3", _mapfolder); // unzip pk3 contents (normally bsp file and textures, etc)
        _result |= file_exists(_mapfolder + "\maps\" + _filename + ".bsp");
        _bspfile = _mapfolder + "\maps\" + _filename + ".bsp";
        break;

    default:
    case "pk3": // various pk files that contains bsp files and stuff
        _result |= zip_unzip(argument0, _mapfolder); // unzip pk3 contents (normally bsp file and textures, etc)
        _result |= file_exists(_mapfolder + "\maps\" + _filename + ".bsp");
        _bspfile = _mapfolder + "\maps\" + _filename + ".bsp";
        break;
        
    case "bsp":
        _result = 1;
        _bspfile = argument0;
        break;
}
if (_result == 0)
{
    /// possibly wrong file type
    zbsp_append_log(bspdata, "INVALID FILE... ABORT");
    
    bspdata[? "success"] = false;
    bspdata[? "error"] = "FILEINVALID";
    zbsp_append_log(bspdata, "ZBSP_LOAD_MAP() END");
    return bspdata;
}

// Read map related data
// map description
var _mapscriptdir = _mapfolder + "\scripts";
if (directory_exists(_mapscriptdir))
{
    var _arenadir = _mapscriptdir + "\" + _filename + ".arena";
    
    if (file_exists(_arenadir))
    {
        show_debug_message("Reading map .arena file..");
        
        var _arenafile = file_text_open_read(_arenadir);
        while (!file_text_eof(_arenafile))
        {
            var _ln = file_text_readln(_arenafile);
            
            if (string_pos("longname", _ln) != 0)
            {
                var _quotebegin = string_pos('"', _ln);
                var _quoteend = string_pos('"', string_delete(_ln, 1, _quotebegin));
                bspdata[? "map-name"] = string_copy(_ln, _quotebegin + 1, _quoteend - 1);
                break;
            }
        }
        file_text_close(_arenafile);
    }
    else
    {
        show_debug_message("Can't find / read .arena file.. :(");
    }
}
// map textures
var _maptexdir = _mapfolder + "\textures";
if (directory_exists(_maptexdir))
{
    var _dirqueue = ds_queue_create();
    var _texdirlist = ds_list_create();
    
    ds_queue_enqueue(_dirqueue, _maptexdir);
    while (!ds_queue_empty(_dirqueue)) // Search all sub-directory for files/image
    {
        var _texdir = ds_queue_dequeue(_dirqueue);
        
        zbsp_append_log(bspdata, "DIRECTORY : " + _texdir);
        
        // Enqueue all possible directories first
        var _subdir = file_find_first(_texdir + "\*", fa_directory);
        while (_subdir != "")
        {
            if (directory_exists(_texdir + "\" + _subdir))
            {
                zbsp_append_log(bspdata, "> SUBDIRECTORY : " + _subdir);
                ds_queue_enqueue(_dirqueue, _texdir + "\" + _subdir);
            }
            
            _subdir = file_find_next();
        }
        file_find_close();
        
        // And find all files after that
        var _dirimg = file_find_first(_texdir + "\*.*", 0);
        while (_dirimg != "")
        {
            if (file_exists(_texdir + "\" + _dirimg))
            {
                zbsp_append_log(bspdata, "+ FILE : " + _dirimg);
                ds_list_add(_texdirlist, _texdir + "\" + _dirimg);
            }
            
            _dirimg = file_find_next();
        }
        file_find_close();
    }
}

bspdata[? "res-tex-dir"] = _texdirlist;

// ==================================================================
/// (Finally) Begin loading from BSP file
// ==================================================================
var _filebuffer = buffer_load(_bspfile);
buffer_seek(_filebuffer, buffer_seek_start, 0);

// Header
zbsp_append_log(bspdata, "[HEADER] ===================");
var _magic = zbsp_read_str(_filebuffer, 4); zbsp_append_log(bspdata, "MAGIC STRING : " + _magic);
var _version = buffer_read(_filebuffer, buffer_s32); zbsp_append_log(bspdata, "BSP VERSION : " + string(_version));
if (_magic != "IBSP" || _version != $2e)
{
    /// possibly wrong file type
    zbsp_append_log(bspdata, "INVALID FILE... ABORT");
    
    bspdata[? "success"] = false;
    bspdata[? "error"] = "FILEINVALID";
    zbsp_append_log(bspdata, "ZBSP_LOAD_MAP() END");
    return bspdata;
}

// Lumps data
zbsp_load_lump_directory(_filebuffer, bspdata);

// Load entities data
zbsp_load_lump_entities(_filebuffer, bspdata);
var _file = file_text_open_write(_mapfolder + "\entities-dump.txt");
file_text_write_string(_file, bspdata[? "entities"]);
file_text_close(_file);

// Load textures data
show_debug_message("Loading textures..");
zbsp_load_lump_textures(_filebuffer, bspdata);

// Load plane data
show_debug_message("Loading planes..");
zbsp_load_lump_planes(_filebuffer, bspdata);

// Load node data
show_debug_message("Loading nodes..");
zbsp_load_lump_nodes(_filebuffer, bspdata);

// Load leaf data
show_debug_message("Loading leafs..");
zbsp_load_lump_leafs(_filebuffer, bspdata);

// Load leaffaces data
show_debug_message("Loading leaffaces..");
zbsp_load_lump_leaffaces(_filebuffer, bspdata);

// Load leafbrushes data
show_debug_message("Loading leafbrushes..");
zbsp_load_lump_leafbrushes(_filebuffer, bspdata);

// Load models data
show_debug_message("Loading models..");
zbsp_load_lump_models(_filebuffer, bspdata);

// Load brushes data
show_debug_message("Loading brushes..");
zbsp_load_lump_brushes(_filebuffer, bspdata);

// Load brushsides data
show_debug_message("Loading brushsides..");
zbsp_load_lump_brushsides(_filebuffer, bspdata);

// Load vertices data
show_debug_message("Loading vertices..");
zbsp_load_lump_vertices(_filebuffer, bspdata);

// Load meshverts data
show_debug_message("Loading meshverts..");
zbsp_load_lump_meshverts(_filebuffer, bspdata);

// Load effects data
show_debug_message("Loading effects..");
zbsp_load_lump_effects(_filebuffer, bspdata);

// Load faces data
show_debug_message("Loading faces..");
zbsp_load_lump_faces(_filebuffer, bspdata);

// Load lightmaps data
show_debug_message("Loading lightmaps..");
zbsp_load_lump_lightmaps(_filebuffer, bspdata);

// Load lightvols data
show_debug_message("Loading lightvols..");
zbsp_load_lump_lightvols(_filebuffer, bspdata);

// Load visdata
show_debug_message("Loading visdata..");
zbsp_load_lump_visdata(_filebuffer, bspdata);

// Build texture atlases
show_debug_message("Building texture atlases..");
show_debug_message(string(bspdata[? "textures-num"]) + " textures..");
bspdata[? "textures-list"] = ds_list_create();
bspdata[? "textures-sprites"] = ds_list_create();

image_system_init();
bspdata[? "textures-indexer"] = ds_list_create();
var _textures = bspdata[? "textures-data"];

var _ig = image_group_create("texture");
image_stream_start(_ig, 2048, 2048, 1, false, false);
image_stream_add(_ig, "texDefault", "texDefault.png", 1, 0, 0);
for (var i=0; i<bspdata[? "textures-num"]; i++)
{
    var _asset = zbsp_fetch_asset_dir(bspdata, _textures[# 0, i] + ".jpg");
    
    if (_asset != "")
    {
        var _spr = sprite_add(_asset, 1, false, false, 0, 0);
        show_debug_message("Adding texture [" + _asset + "] to the mix...");
        image_stream_add(_ig, "tex" + string(i), _asset, 1, 0, 0);
        ds_list_add(bspdata[? "textures-indexer"], "tex" + string(i));
        
        ds_list_add(bspdata[? "textures-sprites"], _spr);
        ds_list_add(bspdata[? "textures-list"], sprite_get_texture(_spr, 0));
    }
    else
    {
        show_debug_message("Can't find [" + _textures[# 0, i] + "]!");
        ds_list_add(bspdata[? "textures-indexer"], "texDefault");
        ds_list_add(bspdata[? "textures-list"], sprite_get_texture(sprNotexture, 0));
    }
}
image_stream_finish(_ig);
bspdata[? "res-texatlas"] = image_group_find_image(_ig, "texDefault");

show_debug_message("BUILDING LIGHTMAP ATLAS (" + string(bspdata[? "lightmaps-num"]) + " TEXTURES)");
var _lmspr = bspdata[? "lightmaps-sprites"];
var _lightinfos = bspdata[? "lightmaps-data"];

var _npower = 10;
var _surfwid = 1 << _npower, _surfhei = (1 << _npower) + 10;
var _cols = _surfhei div 130;
var _rows = (_surfwid - 10) div 130;

while (_cols * _rows < bspdata[? "lightmaps-num"])
{
    _npower++;
    _surfwid = 1 << _npower;
    _surfhei = (1 << _npower) + 10;
    _cols = _surfhei div 130;
    _rows = (_surfwid - 10) div 130;
}

bspdata[? "res-lightatlas"] = surface_create(_surfwid, _surfhei);
surface_set_target(bspdata[? "res-lightatlas"]);
draw_clear(c_white);
for (var i=0; i<bspdata[? "lightmaps-num"]; i++)
{
    var _wx = (i % _cols) * 130;
    var _wy = (i div _cols) * 130 + 10;
    draw_sprite(_lmspr[| i], 0, _wx, _wy);
    
    _lightinfos[# 1, i] = _wx / _surfwid;
    _lightinfos[# 2, i] = 1 - (_wy / _surfhei);
    _lightinfos[# 3, i] = (_wx + 128) / _surfwid;
    _lightinfos[# 4, i] = 1 - ((_wy + 128) / _surfhei);
}
surface_reset_target();

// (DEBUG) Build wireframe vertex buffer of leaf bounding box
show_debug_message("Building Wireframe VB..");
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
zbspDebugVF = vertex_format_end();
zbspDebugBboxVB = vertex_create_buffer();

vertex_begin(zbspDebugBboxVB, zbspDebugVF);
var _models = bspdata[? "models-data"];
var _leafs = bspdata[? "leafs-data"];
var _nodes = bspdata[? "nodes-data"];
for (var i=0; i<bspdata[? "models-num"]; i++)
{
    var _minx = _models[# 0, i], _miny = _models[# 1, i], _minz = _models[# 2, i];
    var _maxx = _models[# 3, i], _maxy = _models[# 4, i], _maxz = _models[# 5, i];
    
    // side 1
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 2
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 3
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 4
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
}

for (var i=0; i<bspdata[? "nodes-num"]; i++)
{
    var _minx = _nodes[# 3, i], _miny = _nodes[# 4, i], _minz = _nodes[# 5, i];
    var _maxx = _nodes[# 6, i], _maxy = _nodes[# 7, i], _maxz = _nodes[# 8, i];
    
    // side 1
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 2
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 3
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 4
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
}

for (var i=0; i<bspdata[? "leafs-num"]; i++)
{
    var _minx = _leafs[# 2, i], _miny = _leafs[# 3, i], _minz = _leafs[# 4, i];
    var _maxx = _leafs[# 5, i], _maxy = _leafs[# 6, i], _maxz = _leafs[# 7, i];
    
    // side 1
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 2
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 3
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _maxz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    // side 4
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _maxx, _miny, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    
    vertex_position_3d(zbspDebugBboxVB, _maxx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
    vertex_position_3d(zbspDebugBboxVB, _minx, _maxy, _minz); vertex_colour(zbspDebugBboxVB, c_lime, 1);
}
vertex_end(zbspDebugBboxVB);
vertex_freeze(zbspDebugBboxVB);

// (DEBUG) Build vertex buffer of faces
show_debug_message("Building Faces VB..");
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_colour();
vertex_format_add_textcoord();
vertex_format_add_textcoord();
zbspLevelVF = vertex_format_end();
zbspDebugMeshVB = vertex_create_buffer();

//vertex_begin(zbspDebugMeshVB, zbspDebugVF2);
var _faces = bspdata[? "faces-data"];
var _vertices = bspdata[? "vertices-data"];
var _meshverts = bspdata[? "meshverts-data"];
var _lmapinfo = bspdata[? "lightmaps-data"];
var _texindexer = bspdata[? "textures-indexer"];

bspdata[? "faces-buffers"] = ds_list_create();
for (var i=0; i<bspdata[? "faces-num"]; i++)
{
    var _type = _faces[# 2, i];
            var _buff = vertex_create_buffer();
            vertex_begin(_buff, zbspDebugVF2);
    
    switch (_type)
    {
        case 3: // Mesh
        case 1: // Polygon (Thankfully they already triangulated the polygons)
            // fetch meshverts idx and number
            var _meshvertidx = _faces[# 5, i], _meshvertnum = _faces[# 6, i];
            
            // fetch first vertex idx
            var _vertidx = _faces[# 3, i];
            
            // fetch texture index
            var _texidx = image_group_find_image(_ig, _texindexer[| _faces[# 0, i]]);
            var _texuv = image_get_uvs(_texidx, 0);
            
            // fetch lightmap index
            var _lmapidx = _faces[# 7, i];
            
            if (_lmapidx >= 0)
            {
                var _lmapminu = _lmapinfo[# 1, _lmapidx];
                var _lmapminv = _lmapinfo[# 2, _lmapidx];
                var _lmapmaxu = _lmapinfo[# 3, _lmapidx];
                var _lmapmaxv = _lmapinfo[# 4, _lmapidx];
            }
            else
            {
                var _lmapminu = 0.0;
                var _lmapminv = 0.0;
                var _lmapmaxu = 0.0;
                var _lmapmaxv = 0.0;
            }
            
            for (var j=0; j<_meshvertnum; j++)
            {
                // calculate current vertex index from meshvert offset & first vertex index
                if (_meshvertidx + j > bspdata[? "meshverts-num"])
                {
                    show_debug_message("MESHVERTS INDEX OUT OF BOUNDS : " + string(_meshvertidx + j) + " / " + string(bspdata[? "meshverts-num"]));
                    show_debug_message("MESHVERT IDX  : " + string(_meshvertidx) + " / NUM " + string(_meshvertnum));
                    show_debug_message("TEXIDX : " + string(_faces[# 0, i]));
                    zbsp_free_map(bspdata);
                    game_end();
                    break;
                }
                var _cvertex = _vertidx + _meshverts[| _meshvertidx + j];
                
                // append vertex data to buffer
                vertex_position_3d(_buff, _vertices[# 0, _cvertex], _vertices[# 1, _cvertex], _vertices[# 2, _cvertex]);
                vertex_colour(_buff, _vertices[# 10, _cvertex], _vertices[# 11, _cvertex]);
                //vertex_texcoord(zbspDebugMeshVB, lerp(_texuv[0], _texuv[2], _vertices[# 3, _cvertex]), lerp(_texuv[3], _texuv[1], _vertices[# 4, _cvertex]));
                vertex_texcoord(_buff, _vertices[# 3, _cvertex], _vertices[# 4, _cvertex]);
                vertex_texcoord(_buff, lerp(_texuv[0], _texuv[2], _vertices[# 5, _cvertex]), lerp(_texuv[3], _texuv[1], _vertices[# 6, _cvertex]));
                vertex_normal(_buff, _vertices[# 7, _cvertex], _vertices[# 8, _cvertex], _vertices[# 9, _cvertex]);
            }
            
            break;
            
        case 2: // Bezier patch (Draw control points for now)
            
            break;
    }
            vertex_end(_buff);
            // vertex_freeze(_buff);
            ds_list_add(bspdata[? "faces-buffers"], _buff);
}

// vertex_end(zbspDebugMeshVB);
// vertex_freeze(zbspDebugMeshVB);

// (DEBUG) Build lightvol visualizations
// http://www.mralligator.com/q3/#Lightvols
show_debug_message("Building Lightvol VB..");
zbspDebugLightvolVB = vertex_create_buffer();

var _lightvols = bspdata[? "lightvols-data"];
var _lightvolcellsizeh = 64;
var _lightvolcellsizev = 128;
var _lightvolnx = floor(_models[# 3, 0] / 64) - ceil(_models[# 0, 0] / 64) + 1;
var _lightvolny = floor(_models[# 4, 0] / 64) - ceil(_models[# 1, 0] / 64) + 1;
var _lightvolnz = floor(_models[# 5, 0] / 128) - ceil(_models[# 2, 0] / 128) + 1;

show_debug_message("Lightvol size calculated : " + string(_lightvolnx * _lightvolny * _lightvolnz));
show_debug_message("Lightvol actual size : " + string(bspdata[? "lightvols-num"]));

vertex_begin(zbspDebugLightvolVB, zbspDebugVF);
var _boxsz = 8;
for (var _x=0; _x<_lightvolnx; _x++)
{
    for (var _y=0; _y<_lightvolny; _y++)
    {
        for (var _z=0; _z<_lightvolnz; _z++)
        {
            var _lvolidx = _z * (_lightvolnx * _lightvolny) + _y * (_lightvolnx) + _x;
            var _wpx = _models[# 0, 0] + _x * _lightvolcellsizeh, _wpy = -_models[# 1, 0] - _y * _lightvolcellsizeh, _wpz = _models[# 2, 0] + _z * _lightvolcellsizev;
            
            zbsp_vb_lightmapcube(zbspDebugLightvolVB, _wpx, _wpy, _wpz, _boxsz, _lightvols[# 0, _lvolidx], _lightvols[# 1, _lvolidx], _lightvols[# 2, _lvolidx], _lightvols[# 3, _lvolidx]);
        }
    }
}

vertex_end(zbspDebugLightvolVB);
vertex_freeze(zbspDebugLightvolVB);

// Free buffer from leaking the memory
buffer_delete(_filebuffer);

zbsp_append_log(bspdata, "ZBSP_LOAD_MAP() END");
return bspdata;
