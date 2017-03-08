#version 330 core

in vec2 tex_coords;

out vec4 color;

uniform sampler2D tex;

void main()
{ 
    color = texture(tex, tex_coords);
    //color = vec4(1, 1, 1, 1);
}