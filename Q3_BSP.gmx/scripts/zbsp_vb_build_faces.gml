///zbsp_vb_build_faces(mapdata)
/*
    Builds vertex buffer for every faces and stores it inside of the given bsp data ds_map.
    The list of buffers can be accessed from the given ds_map level data with key "vb-faces",
    And it's vertex format with "vb-format-face-tex".
    
    It includes (diffuse) texture & lightmap UVs, Using following format :
    vertex_format_begin();
    vertex_format_add_position_3d();
    vertex_format_add_colour();
    vertex_format_add_textcoord(); // Texture UV, Refered as "in_TextureCoord0" in shader
    vertex_format_add_custom(vertex_type_float2, vertex_usage_textcoord); // Lightmap UV, Refered as "in_TextureCoord1" in shader
    vertex_format_add_normal();
*/

var bspdata = argument0;

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_colour();
vertex_format_add_textcoord();
vertex_format_add_custom(vertex_type_float2, vertex_usage_textcoord);
vertex_format_add_normal();
var _debugVF = vertex_format_end();

// Vertex offset lookup table for indexing & weaving a bezier patch
var _patchidxlut = -1;
_patchidxlut[0, 0] = 0; _patchidxlut[0, 1] = 0;
_patchidxlut[1, 0] = 0; _patchidxlut[1, 1] = 1;
_patchidxlut[2, 0] = 1; _patchidxlut[2, 1] = 0;
_patchidxlut[3, 0] = 1; _patchidxlut[3, 1] = 0;
_patchidxlut[4, 0] = 0; _patchidxlut[4, 1] = 1;
_patchidxlut[5, 0] = 1; _patchidxlut[5, 1] = 1;

// Lightmap default uv
var _lmapdefaultu = texture_get_texel_width(bspdata[? "res-lightatlas-tex"]);
var _lmapdefaultv = texture_get_texel_height(bspdata[? "res-lightatlas-tex"]);

// Various level data
var _faces = bspdata[? "faces-data"];
var _vertices = bspdata[? "vertices-data"];
var _meshverts = bspdata[? "meshverts-data"];
var _lmapinfo = bspdata[? "lightmaps-data"];

bspdata[? "vb-faces"] = ds_list_create();

var _vertctr = 0;
var _usevertexcolour = false;
for (var i=0; i<bspdata[? "faces-num"]; i++)
{
    // Fetch face type
    var _type = _faces[# eBSP_FACE.TYPE, i];
    
    // Create a vertexbuffer for face
    var _debugVB = vertex_create_buffer();
    vertex_begin(_debugVB, _debugVF);
    _vertctr = 0;
    
    // Fetch first meshverts idx and number
    var _meshvertidx = _faces[# eBSP_FACE.MESHVERT_IDX, i], _meshvertnum = _faces[# eBSP_FACE.MESHVERT_NUM, i];
    
    // Fetch first vertex idx and number
    var _vertidx = _faces[# eBSP_FACE.VERTEX_IDX, i], _vertnum = _faces[# eBSP_FACE.VERTEX_NUM, i];
    
    // Fetch texture index
    var _texidx = _faces[# eBSP_FACE.TEXTURE, i];
    
    // Fetch lightmap index
    var _lmapidx = _faces[# eBSP_FACE.LIGHTMAP, i];
    var _lmapu, _lmapv, _lmapusz, _lmapvsz;
    
    if (_lmapidx < 0)
    {
        // Not using lightmap? use default notexture uv instead..
        _lmapu = _lmapdefaultu;
        _lmapv = _lmapdefaultv;
        _lmapusz = _lmapdefaultu;
        _lmapvsz = _lmapdefaultv;
    }
    else
    {
        // UV starting coords
        _lmapu = _lmapinfo[# eBSP_LIGHTMAP.UV_MIN_X, _lmapidx];
        _lmapv = _lmapinfo[# eBSP_LIGHTMAP.UV_MIN_Y, _lmapidx];
        
        // UV size
        _lmapusz = _lmapinfo[# eBSP_LIGHTMAP.UV_MAX_X, _lmapidx] - _lmapu;
        _lmapvsz = _lmapinfo[# eBSP_LIGHTMAP.UV_MAX_Y, _lmapidx] - _lmapv;
    }
    
    // Default vertex colour when using lightmap
    // (vertex colour is mostly only used for lighting)
    var _vertexcol = c_white;
    
    /// Type dependant vertex building code
    switch (_type)
    {
        case eBSP_FACE_TYPE.MESH: // Mesh
        case eBSP_FACE_TYPE.POLYGON: // Polygon (Thankfully they've already triangulated the polygons)
            for (var j=0; j<_meshvertnum; j++)
            {
                // Calculate current vertex index from meshvert offset & first vertex index
                var _cvertex = _vertidx + _meshverts[| _meshvertidx + j];
                
                // Append vertex to buffer
                vertex_position_3d(_debugVB, _vertices[# eBSP_VERTEX.X, _cvertex], _vertices[# eBSP_VERTEX.Y, _cvertex], _vertices[# eBSP_VERTEX.Z, _cvertex]);
                
                //vertex_colour(_debugVB, _vertices[# eBSP_VERTEX.COLOUR, _cvertex], _vertices[# eBSP_VERTEX.ALPHA, _cvertex]);
                vertex_colour(_debugVB, _vertexcol, 1);
                
                vertex_texcoord(_debugVB, _vertices[# eBSP_VERTEX.TEX_U, _cvertex], _vertices[# eBSP_VERTEX.TEX_V, _cvertex]);
                
                vertex_float2(_debugVB, _lmapu + _lmapusz * _vertices[# eBSP_VERTEX.LMAP_U, _cvertex], _lmapv + _lmapvsz * _vertices[# eBSP_VERTEX.LMAP_V, _cvertex]);
                
                vertex_normal(_debugVB, _vertices[# eBSP_VERTEX.NORMAL_X, _cvertex], _vertices[# eBSP_VERTEX.NORMAL_Y, _cvertex], _vertices[# eBSP_VERTEX.NORMAL_Z, _cvertex]);
                
                _vertctr++;
            }
            break;
        
        case eBSP_FACE_TYPE.BILLBOARD: // Billboard
            
            break;
            
        case eBSP_FACE_TYPE.BEZIERPATCH: // Bezier patch (oh crap)
            // Fetch control points grid dimensions
            var _bezierw = _faces[# eBSP_FACE.BEZIERPATCH_W, i], _bezierh = _faces[# eBSP_FACE.BEZIERPATCH_H, i];
            
            // Calculate numbers of bezier patch in each axis
            var _beziernumx = floor((_bezierw - 1) / 2), _beziernumy = floor((_bezierh - 1) / 2);
            
            // Build list of patch
            var _patches = -1, _patchidx = 0;
            var _patchverts = -1;
            var _patchvertdata = -1;
            var _patchpoints = -1;
            
            for (var _px=0; _px<_beziernumx; _px++)
            {
                for (var _py=0; _py<_beziernumy; _py++)
                {
                    // get 3x3 control points for each patch
                    _patchpoints = -1;
                                            
                    var _pbeginx = _px * 2;
                    var _pbeginy = _py * 2;
                    
                    for (var _ox=0; _ox<3; _ox++)
                    {
                        for (var _oy=0; _oy<3; _oy++)
                        {
                            var _idx = _ox + _oy * 3;
                            _patchpoints[_idx] = _vertidx + (_pbeginx + _pbeginy * _bezierw) + (_ox + _oy * _bezierw);
                        }
                    }
                    
                    _patches[_patchidx++] = _patchpoints;
                }
            }
            
            // Tessellate bezier patch
            var _levels = 5;
            var _levelside = _levels + 1;
            for (var p=0; p<_patchidx; p++)
            {
                _patchpoints = _patches[@ p];
                _patchvertdata = -1;
                
                // Iterate columns
                for (var c=0; c<_levelside; c++)
                {
                    var _rowlerp = c / _levels;
                    var _rowlerpi = 1 - _rowlerp;
                    
                    // Cache 3x3 control points, We're gonna index them A LOT when we're interpolating for bezier curve
                    // Control points column 1, [0, 3, 6]
                    var _cpc1r1 = _patchpoints[@ 0];
                    var _cpc1r2 = _patchpoints[@ 3];
                    var _cpc1r3 = _patchpoints[@ 6];
                    
                    // Control points column 2, [1, 4, 7]
                    var _cpc2r1 = _patchpoints[@ 1];
                    var _cpc2r2 = _patchpoints[@ 4];
                    var _cpc2r3 = _patchpoints[@ 7];
                    
                    // Control points column 3, [2, 5, 8]
                    var _cpc3r1 = _patchpoints[@ 2];
                    var _cpc3r2 = _patchpoints[@ 5];
                    var _cpc3r3 = _patchpoints[@ 8];
                    
                    // Calculate coefficients
                    var _lerpi2 = _rowlerpi * _rowlerpi;
                    var _lerp2 = _rowlerp * _rowlerp;
                    var _2lil = 2 * _rowlerpi * _rowlerp;
                    
                    // Calculate & Bezier curve / Interpolate all 3 columns of control points attributes
                    // vertex xyz
                    var _cp1x = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.X, _cpc1r1], _vertices[# eBSP_VERTEX.X, _cpc1r2], _vertices[# eBSP_VERTEX.X, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2x = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.X, _cpc2r1], _vertices[# eBSP_VERTEX.X, _cpc2r2], _vertices[# eBSP_VERTEX.X, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3x = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.X, _cpc3r1], _vertices[# eBSP_VERTEX.X, _cpc3r2], _vertices[# eBSP_VERTEX.X, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    var _cp1y = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.Y, _cpc1r1], _vertices[# eBSP_VERTEX.Y, _cpc1r2], _vertices[# eBSP_VERTEX.Y, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2y = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.Y, _cpc2r1], _vertices[# eBSP_VERTEX.Y, _cpc2r2], _vertices[# eBSP_VERTEX.Y, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3y = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.Y, _cpc3r1], _vertices[# eBSP_VERTEX.Y, _cpc3r2], _vertices[# eBSP_VERTEX.Y, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    var _cp1z = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.Z, _cpc1r1], _vertices[# eBSP_VERTEX.Z, _cpc1r2], _vertices[# eBSP_VERTEX.Z, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2z = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.Z, _cpc2r1], _vertices[# eBSP_VERTEX.Z, _cpc2r2], _vertices[# eBSP_VERTEX.Z, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3z = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.Z, _cpc3r1], _vertices[# eBSP_VERTEX.Z, _cpc3r2], _vertices[# eBSP_VERTEX.Z, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    // texture uv
                    var _cp1tu = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.TEX_U, _cpc1r1], _vertices[# eBSP_VERTEX.TEX_U, _cpc1r2], _vertices[# eBSP_VERTEX.TEX_U, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2tu = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.TEX_U, _cpc2r1], _vertices[# eBSP_VERTEX.TEX_U, _cpc2r2], _vertices[# eBSP_VERTEX.TEX_U, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3tu = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.TEX_U, _cpc3r1], _vertices[# eBSP_VERTEX.TEX_U, _cpc3r2], _vertices[# eBSP_VERTEX.TEX_U, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    var _cp1tv = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.TEX_V, _cpc1r1], _vertices[# eBSP_VERTEX.TEX_V, _cpc1r2], _vertices[# eBSP_VERTEX.TEX_V, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2tv = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.TEX_V, _cpc2r1], _vertices[# eBSP_VERTEX.TEX_V, _cpc2r2], _vertices[# eBSP_VERTEX.TEX_V, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3tv = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.TEX_V, _cpc3r1], _vertices[# eBSP_VERTEX.TEX_V, _cpc3r2], _vertices[# eBSP_VERTEX.TEX_V, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    // lightmap uv
                    var _cp1lu = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.LMAP_U, _cpc1r1], _vertices[# eBSP_VERTEX.LMAP_U, _cpc1r2], _vertices[# eBSP_VERTEX.LMAP_U, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2lu = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.LMAP_U, _cpc2r1], _vertices[# eBSP_VERTEX.LMAP_U, _cpc2r2], _vertices[# eBSP_VERTEX.LMAP_U, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3lu = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.LMAP_U, _cpc3r1], _vertices[# eBSP_VERTEX.LMAP_U, _cpc3r2], _vertices[# eBSP_VERTEX.LMAP_U, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    var _cp1lv = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.LMAP_V, _cpc1r1], _vertices[# eBSP_VERTEX.LMAP_V, _cpc1r2], _vertices[# eBSP_VERTEX.LMAP_V, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2lv = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.LMAP_V, _cpc2r1], _vertices[# eBSP_VERTEX.LMAP_V, _cpc2r2], _vertices[# eBSP_VERTEX.LMAP_V, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3lv = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.LMAP_V, _cpc3r1], _vertices[# eBSP_VERTEX.LMAP_V, _cpc3r2], _vertices[# eBSP_VERTEX.LMAP_V, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    // normal
                    var _cp1nx = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_X, _cpc1r1], _vertices[# eBSP_VERTEX.NORMAL_X, _cpc1r2], _vertices[# eBSP_VERTEX.NORMAL_X, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2nx = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_X, _cpc2r1], _vertices[# eBSP_VERTEX.NORMAL_X, _cpc2r2], _vertices[# eBSP_VERTEX.NORMAL_X, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3nx = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_X, _cpc3r1], _vertices[# eBSP_VERTEX.NORMAL_X, _cpc3r2], _vertices[# eBSP_VERTEX.NORMAL_X, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    var _cp1ny = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_Y, _cpc1r1], _vertices[# eBSP_VERTEX.NORMAL_Y, _cpc1r2], _vertices[# eBSP_VERTEX.NORMAL_Y, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2ny = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_Y, _cpc2r1], _vertices[# eBSP_VERTEX.NORMAL_Y, _cpc2r2], _vertices[# eBSP_VERTEX.NORMAL_Y, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3ny = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_Y, _cpc3r1], _vertices[# eBSP_VERTEX.NORMAL_Y, _cpc3r2], _vertices[# eBSP_VERTEX.NORMAL_Y, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    var _cp1nz = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_Z, _cpc1r1], _vertices[# eBSP_VERTEX.NORMAL_Z, _cpc1r2], _vertices[# eBSP_VERTEX.NORMAL_Z, _cpc1r3], _lerpi2, _lerp2, _2lil);
                    var _cp2nz = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_Z, _cpc2r1], _vertices[# eBSP_VERTEX.NORMAL_Z, _cpc2r2], _vertices[# eBSP_VERTEX.NORMAL_Z, _cpc2r3], _lerpi2, _lerp2, _2lil);
                    var _cp3nz = zbsp_calc_bezier(_vertices[# eBSP_VERTEX.NORMAL_Z, _cpc3r1], _vertices[# eBSP_VERTEX.NORMAL_Z, _cpc3r2], _vertices[# eBSP_VERTEX.NORMAL_Z, _cpc3r3], _lerpi2, _lerp2, _2lil);
                    
                    // colour (unused since lightmap replaces the sole point of vertex colour; vertex baked lighting.)
                    // you can uncomment below comment block & _patchvertdata[] colour assigning code far below if you want to use vertex lighting model instead of lightmaps
                    var _colour = c_white;
                    /*
                    var _cpc1r1col = _vertices[# eBSP_VERTEX.COLOUR, _cpc1r1];
                    var _cpc1r2col = _vertices[# eBSP_VERTEX.COLOUR, _cpc1r2];
                    var _cpc1r3col = _vertices[# eBSP_VERTEX.COLOUR, _cpc1r3];
                    
                    var _cpc2r1col = _vertices[# eBSP_VERTEX.COLOUR, _cpc2r1];
                    var _cpc2r2col = _vertices[# eBSP_VERTEX.COLOUR, _cpc2r2];
                    var _cpc2r3col = _vertices[# eBSP_VERTEX.COLOUR, _cpc2r3];
                    
                    var _cpc3r1col = _vertices[# eBSP_VERTEX.COLOUR, _cpc3r1];
                    var _cpc3r2col = _vertices[# eBSP_VERTEX.COLOUR, _cpc3r2];
                    var _cpc3r3col = _vertices[# eBSP_VERTEX.COLOUR, _cpc3r3];
                    
                    var _cp1colr = zbsp_calc_bezier(colour_get_red(_cpc1r1col), colour_get_red(_cpc1r2col), colour_get_red(_cpc1r3col), _lerpi2, _lerp2, _2lil);
                    var _cp1colg = zbsp_calc_bezier(colour_get_green(_cpc1r1col), colour_get_green(_cpc1r2col), colour_get_green(_cpc1r3col), _lerpi2, _lerp2, _2lil);
                    var _cp1colb = zbsp_calc_bezier(colour_get_blue(_cpc1r1col), colour_get_blue(_cpc1r2col), colour_get_blue(_cpc1r3col), _lerpi2, _lerp2, _2lil);
                    
                    var _cp2colr = zbsp_calc_bezier(colour_get_red(_cpc2r1col), colour_get_red(_cpc2r2col), colour_get_red(_cpc2r3col), _lerpi2, _lerp2, _2lil);
                    var _cp2colg = zbsp_calc_bezier(colour_get_green(_cpc2r1col), colour_get_green(_cpc2r2col), colour_get_green(_cpc2r3col), _lerpi2, _lerp2, _2lil);
                    var _cp2colb = zbsp_calc_bezier(colour_get_blue(_cpc2r1col), colour_get_blue(_cpc2r2col), colour_get_blue(_cpc2r3col), _lerpi2, _lerp2, _2lil);
                    
                    var _cp3colr = zbsp_calc_bezier(colour_get_red(_cpc3r1col), colour_get_red(_cpc3r2col), colour_get_red(_cpc3r3col), _lerpi2, _lerp2, _2lil);
                    var _cp3colg = zbsp_calc_bezier(colour_get_green(_cpc3r1col), colour_get_green(_cpc3r2col), colour_get_green(_cpc3r3col), _lerpi2, _lerp2, _2lil);
                    var _cp3colb = zbsp_calc_bezier(colour_get_blue(_cpc3r1col), colour_get_blue(_cpc3r2col), colour_get_blue(_cpc3r3col), _lerpi2, _lerp2, _2lil);
                    */
                    
                    // Interpolate between 3 control points
                    for (var l=0; l<_levelside; l++)
                    {
                        var _lerp = l / _levels;
                        var _lerpinv = 1 - _lerp;
                        
                        // B = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
                        var _lerpi2 = _lerpinv * _lerpinv;
                        var _lerp2 = _lerp * _lerp;
                        var _2lil = 2 * _lerpinv * _lerp;
                        
                        var _idx = l + c * _levelside;
                        _patchvertdata[_idx, 0] = zbsp_calc_bezier(_cp1x, _cp2x, _cp3x, _lerpi2, _lerp2, _2lil); //_cp1x * _lerpi2 + _cp2x * _2lil + _cp3x * _lerp2;
                        _patchvertdata[_idx, 1] = zbsp_calc_bezier(_cp1y, _cp2y, _cp3y, _lerpi2, _lerp2, _2lil);
                        _patchvertdata[_idx, 2] = zbsp_calc_bezier(_cp1z, _cp2z, _cp3z, _lerpi2, _lerp2, _2lil);
                        
                        _patchvertdata[_idx, 3] = zbsp_calc_bezier(_cp1tu, _cp2tu, _cp3tu, _lerpi2, _lerp2, _2lil); //_cp1tu * _lerpi2 + _cp2tu * _2lil + _cp3tu * _lerp2;
                        _patchvertdata[_idx, 4] = zbsp_calc_bezier(_cp1tv, _cp2tv, _cp3tv, _lerpi2, _lerp2, _2lil); //_cp1tv * _lerpi2 + _cp2tv * _2lil + _cp3tv * _lerp2;
                        
                        _patchvertdata[_idx, 5] = zbsp_calc_bezier(_cp1lu, _cp2lu, _cp3lu, _lerpi2, _lerp2, _2lil); //_cp1lu * _lerpi2 + _cp2lu * _2lil + _cp3lu * _lerp2;
                        _patchvertdata[_idx, 6] = zbsp_calc_bezier(_cp1lv, _cp2lv, _cp3lv, _lerpi2, _lerp2, _2lil); //_cp1lv * _lerpi2 + _cp2lv * _2lil + _cp3lv * _lerp2;
                        
                        _patchvertdata[_idx, 7] = zbsp_calc_bezier(_cp1nx, _cp2nx, _cp3nx, _lerpi2, _lerp2, _2lil); //_cp1nx * _lerpi2 + _cp2nx * _2lil + _cp3nx * _lerp2;
                        _patchvertdata[_idx, 8] = zbsp_calc_bezier(_cp1ny, _cp2ny, _cp3ny, _lerpi2, _lerp2, _2lil); //_cp1ny * _lerpi2 + _cp2ny * _2lil + _cp3ny * _lerp2;
                        _patchvertdata[_idx, 9] = zbsp_calc_bezier(_cp1nz, _cp2nz, _cp3nz, _lerpi2, _lerp2, _2lil); //_cp1nz * _lerpi2 + _cp2nz * _2lil + _cp3nz * _lerp2;
                        
                        // uncomment below code and comment the [_patchvertdata[_idx, 10] = _colour;] part to change to vertex lighting model
                        // _patchvertdata[_idx, 10] = make_colour_rgb(zbsp_calc_bezier(_cp1colr, _cp2colr, _cp3colr, _lerpi2, _lerp2, _2lil), zbsp_calc_bezier(_cp1colg, _cp2colg, _cp3colg, _lerpi2, _lerp2, _2lil), zbsp_calc_bezier(_cp1colb, _cp2colb, _cp3colb, _lerpi2, _lerp2, _2lil));
                        _patchvertdata[_idx, 10] = _colour;
                    }
                }
                
                _patchverts[p] = _patchvertdata;
            }
            
            // Triangulate bezier patch
            for (var p=0; p<_patchidx; p++)
            {
                _patchvertdata = _patchverts[p];
                
                // iterate through all tessellated vertexes
                for (var _ox=0; _ox<_levels; _ox++)
                {
                    for (var _oy=0; _oy<_levels; _oy++)
                    {
                        // use triangulation offset LUT (_patchidxlut) for making the proccess of triangulating grids of vertices much easier
                        for (var o=0; o<6; o++)
                        {
                            var _x = _ox + _patchidxlut[o, 0];
                            var _y = _oy + _patchidxlut[o, 1];
                            var _cvertex = _x * _levelside + _y;
                            
                            vertex_position_3d(_debugVB, _patchvertdata[_cvertex, 0], _patchvertdata[_cvertex, 1], _patchvertdata[_cvertex, 2]);
                            
                            vertex_colour(_debugVB, _patchvertdata[_cvertex, 10], 1);
                            
                            vertex_texcoord(_debugVB, _patchvertdata[_cvertex, 3], _patchvertdata[_cvertex, 4]);
                            
                            vertex_float2(_debugVB, _lmapu + _lmapusz * _patchvertdata[_cvertex, 5], _lmapv + _lmapvsz * _patchvertdata[_cvertex, 6]);
                            
                            vertex_normal(_debugVB, _patchvertdata[_cvertex, 7], _patchvertdata[_cvertex, 8], _patchvertdata[_cvertex, 9]);
                            
                            _vertctr++;
                        }
                        
                    }
                }
                
            }
            break;
    }
    
    // Tidy up stuff & into the buffer list it goes
    vertex_end(_debugVB);
    if (_vertctr >= 1)
    {
        vertex_freeze(_debugVB);
    }
    
    ds_list_add(bspdata[? "vb-faces"], _debugVB);
}

bspdata[? "vb-format-face-tex"] = _debugVF;
