#version 330 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 rel_corner;

out VertexData {
    vec4 rel_corner;
} vertex_data;



void main()
{
    vertex_data.rel_corner = rel_corner;
    gl_Position = position;
}
