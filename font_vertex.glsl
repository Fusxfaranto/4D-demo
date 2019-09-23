#version 330 core
  
layout (location = 0) in vec2 position;
layout (location = 1) in vec2 tex_coords_in;

out vec2 tex_coords;

void main()
{
    tex_coords = tex_coords_in;
    //tex_coords = position;
    gl_Position = vec4(position, 0.0, 1.0);
    //color_f = color_in;
}
