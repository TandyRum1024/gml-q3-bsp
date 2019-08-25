///zbsp_calc_lightdot(x1, y1, z1, x2, y2, z2, x3, y3, z3, vx, vy, vz)
/*
    Calculates normal & returns result of dot product with given vector in 0..1 range
*/
var _x1 = argument0, _y1 = argument1, _z1 = argument2;
var _x2 = argument3, _y2 = argument4, _z2 = argument5;
var _x3 = argument6, _y3 = argument7, _z3 = argument8;
var _lx = argument9, _ly = argument10, _lz = argument11;

var _dx1 = _x2 - _x1, _dy1 = _y2 - _y1, _dz1 = _z2 - _z1;
var _dx2 = _x3 - _x1, _dy2 = _y3 - _y1, _dz2 = _z3 - _z1;
var _nx = _dy1 * _dz2 - _dz1 * _dy2;
var _ny = _dz1 * _dx2 - _dx1 * _dz2;
var _nz = _dx1 * _dy2 - _dy1 * _dx2;

var _mag = 1 / sqrt(_nx * _nx + _ny * _ny + _nz * _nz);
_nx *= _mag; _ny *= _mag; _nz *= _mag;

return dot_product_3d(_nx, _ny, _nz, _lx, _ly, _lz) * 0.5 + 0.5;
