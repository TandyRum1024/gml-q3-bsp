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
global.BSPLumpNames = -1; var _idx = 0;
global.BSPLumpNames[_idx++] = "entities";
global.BSPLumpNames[_idx++] = "textures";
global.BSPLumpNames[_idx++] = "planes";
global.BSPLumpNames[_idx++] = "nodes";
global.BSPLumpNames[_idx++] = "leafs";
global.BSPLumpNames[_idx++] = "leaffaces";
global.BSPLumpNames[_idx++] = "leafbrushes";
global.BSPLumpNames[_idx++] = "models";
global.BSPLumpNames[_idx++] = "brushes";
global.BSPLumpNames[_idx++] = "brushsides";
global.BSPLumpNames[_idx++] = "vertices";
global.BSPLumpNames[_idx++] = "meshverts";
global.BSPLumpNames[_idx++] = "effects";
global.BSPLumpNames[_idx++] = "faces";
global.BSPLumpNames[_idx++] = "lightmaps";
global.BSPLumpNames[_idx++] = "lightvols";
global.BSPLumpNames[_idx++] = "visdata";

// data related variables
var bspdata = ds_map_create(); // map containing the bsp data
var _filetype = string_delete(filename_ext(argument0), 1, 1);
var _filename = string_copy(filename_name(argument0), 1, string_pos(".", argument0) - 1);

// setup values
bspdata[? "success"] = true;
bspdata[? "error"] = "";
bspdata[? "type"] = _filetype;
bspdata[? "name"] = _filename;
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
var _datafolder = "data";
var _mapfolder = _datafolder + "\map\" + _filename;
var _assetfolder = _datafolder + "\res";
var _bspfile = "";

if (!directory_exists(_assetfolder))
{
    zbsp_append_log(bspdata, "UNPACKING BASE ASSETS...");
    show_debug_message("UNPACKING BASE ASSETS...");
    
    zip_unzip("oa_assets.pk3", _assetfolder);
}

zbsp_append_log(bspdata, "UNPACKING LEVEL...");
zbsp_append_log(bspdata, "FILETYPE : " + _filetype);
show_debug_message("UNPACKING LEVEL...");

// create directory if needed
if (!directory_exists(_datafolder))
{
    directory_create(_datafolder);
    zbsp_append_log(bspdata, "MAKING DATA FOLDER");
}
if (!directory_exists(_mapfolder))
{
    directory_create(_mapfolder);
    zbsp_append_log(bspdata, "MAKING MAP FOLDER");
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
        show_debug_message("DIRECTORY : " + _texdir);
        
        // Enqueue all possible directories first
        var _subdir = file_find_first(_texdir + "\*", fa_directory);
        while (_subdir != "")
        {
            if (directory_exists(_texdir + "\" + _subdir))
            {
                zbsp_append_log(bspdata, "> SUBDIRECTORY : " + _subdir);
                show_debug_message("> SUBDIRECTORY : " + _subdir);
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
                show_debug_message("+ FILE : " + _dirimg);
                ds_list_add(_texdirlist, _texdir + "\" + _dirimg);
            }
            
            _dirimg = file_find_next();
        }
        file_find_close();
        
        show_debug_message("=====");
    }
}

bspdata[? "data-textures-dir"] = _texdirlist;

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
zbsp_load_entities(_filebuffer, bspdata);
var _file = file_text_open_write(_mapfolder + "\entities-dump.txt");
file_text_write_string(_file, bspdata[? "entities"]);
file_text_close(_file);

// Load textures data
zbsp_load_textures(_filebuffer, bspdata);

// Free buffer from leaking the memory
buffer_delete(_filebuffer);

zbsp_append_log(bspdata, "ZBSP_LOAD_MAP() END");
return bspdata;
