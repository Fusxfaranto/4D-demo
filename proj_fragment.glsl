#version 330 core

in vec3 color_f;

out vec4 color;

float max3(vec3 v) {
  return max(max(v.x, v.y), v.z);
}

void main()
{
    //color = vec4(color_f, 1.0);
    // TODO
    color = vec4(color_f, max3(color_f));
}
