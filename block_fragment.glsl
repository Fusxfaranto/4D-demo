#version 330 core

in FragData {
    vec3 color_f;
};

out vec4 color;

void main()
{
    color = vec4(color_f, 1.0);
}
