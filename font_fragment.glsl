#version 330 core

in vec2 tex_coords;

out vec4 color;

uniform sampler2D tex;

//uniform float font_start;
//uniform float font_end;

void main()
{
    //color = vec4(tex_coords.y * -5, tex_coords.xx, 1);
    color = texture(tex, tex_coords);
    if(color.a < 0.1)
        discard;
    //color = texture2D(tex, vec2(tex_coords.x, tex_coords.y));
    //color = texture2D(tex, vec2(tex_coords.x + font_start, tex_coords.y));
    //color = vec4(1.0, 1.0, 1.0, 1.0);
}
