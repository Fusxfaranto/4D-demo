#version 330 core
  
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 color;

out VertexData {
    vec3 color;
//    float width;
} vertex_data;


void main()
{
    //gl_Position = projection * view * vec4(position, 1.0);
    gl_Position = vec4(position, 1.0);
    vertex_data.color = color;
//    vertex_data.width = width;
}
