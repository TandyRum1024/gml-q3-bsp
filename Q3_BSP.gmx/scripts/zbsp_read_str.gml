///zbsp_read_str(buff, num)
/*
    Reads string with given length from buffer
*/

var _char = 0, _str = "";

for (var i=0; i<argument1; i++)
{
    _char = buffer_read(argument0, buffer_u8);
    _str += chr(_char);
}

return _str;
