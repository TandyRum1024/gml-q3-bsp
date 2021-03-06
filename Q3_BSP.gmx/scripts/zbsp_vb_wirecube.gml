///zbsp_wb_wirecube(vb, x1, y1, z1, x2, y2, z2, colour, diagonal)
/*
    Appends wireframe cube vertices in given vertex buffer with format [position3d, colour]
*/

var _vb = argument0;
var _minx = argument1, _miny = argument2, _minz = argument3;
var _maxx = argument4, _maxy = argument5, _maxz = argument6;
var _col = argument7, _diagonal = argument8;

// side 1
vertex_position_3d(_vb, _minx, _miny, _minz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _maxx, _miny, _minz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _minx, _miny, _minz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _minx, _maxy, _minz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _minx, _miny, _minz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _minx, _miny, _maxz); vertex_colour(_vb, _col, 1);

// side 2
vertex_position_3d(_vb, _maxx, _maxy, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _minx, _maxy, _maxz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _maxx, _maxy, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _maxx, _miny, _maxz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _maxx, _maxy, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _maxx, _maxy, _minz); vertex_colour(_vb, _col, 1);

// side 3
vertex_position_3d(_vb, _minx, _miny, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _maxx, _miny, _maxz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _minx, _miny, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _minx, _maxy, _maxz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _maxx, _miny, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _maxx, _miny, _minz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _minx, _maxy, _maxz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _minx, _maxy, _minz); vertex_colour(_vb, _col, 1);

// side 4
vertex_position_3d(_vb, _maxx, _maxy, _minz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _maxx, _miny, _minz); vertex_colour(_vb, _col, 1);

vertex_position_3d(_vb, _maxx, _maxy, _minz); vertex_colour(_vb, _col, 1);
vertex_position_3d(_vb, _minx, _maxy, _minz); vertex_colour(_vb, _col, 1);

// diagonal line
if (_diagonal)
{
    vertex_position_3d(_vb, _minx, _miny, _minz); vertex_colour(_vb, _col, 1);
    vertex_position_3d(_vb, _maxx, _maxy, _minz); vertex_colour(_vb, _col, 1);
    
    vertex_position_3d(_vb, _minx, _miny, _maxz); vertex_colour(_vb, _col, 1);
    vertex_position_3d(_vb, _maxx, _maxy, _maxz); vertex_colour(_vb, _col, 1);
}
