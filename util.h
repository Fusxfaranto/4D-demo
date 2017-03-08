
#ifndef UTIL_H__IDG
#define UTIL_H__IDG


#define GLEW_STATIC
#include <GL/glew.h>

#include <GLFW/glfw3.h>

#include "include/SOIL.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <assert.h>


#define CHECK_RES(x)                            \
    {                                           \
        int __res;                              \
        if ((__res = (x)))                      \
            return __res;                       \
    }
#define ARRAY_LEN(x) (sizeof(x) / sizeof(x[0]))


int create_shader(GLuint *shader_program, const char *vs_filename,
                  const char* gs_filename, const char *fs_filename)
{
    GLint success;
    GLchar buffer[1024];
    const GLchar *buffer_p = buffer;

    FILE *f = fopen(vs_filename, "r");
    int l = fread(buffer, sizeof(buffer[0]), ARRAY_LEN(buffer) - 1, f);
    buffer[l] = '\0';
    fclose(f);

    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, 1, &buffer_p, NULL);
    glCompileShader(vs);
    glGetShaderiv(vs, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vs, ARRAY_LEN(buffer), NULL, buffer);
        fprintf(stderr, "vertex shader compilation error:\n%.*s\n", (int)ARRAY_LEN(buffer), buffer);
        return EXIT_FAILURE;
    }


    f = fopen(fs_filename, "r");
    l = fread(buffer, sizeof(buffer[0]), ARRAY_LEN(buffer) - 1, f);
    buffer[l] = '\0';
    fclose(f);

    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, 1, &buffer_p, NULL);
    glCompileShader(fs);
    glGetShaderiv(fs, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        fputs(buffer, stderr);
        glGetShaderInfoLog(fs, ARRAY_LEN(buffer), NULL, buffer);
        fprintf(stderr, "fragment shader compilation error:\n%.*s\n", (int)ARRAY_LEN(buffer), buffer);
        return EXIT_FAILURE;
    }


    GLuint gs = 0;
    if (gs_filename)
    {
        f = fopen(gs_filename, "r");
        l = fread(buffer, sizeof(buffer[0]), ARRAY_LEN(buffer) - 1, f);
        buffer[l] = '\0';
        fclose(f);

        gs = glCreateShader(GL_GEOMETRY_SHADER);
        glShaderSource(gs, 1, &buffer_p, NULL);
        glCompileShader(gs);
        glGetShaderiv(gs, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            fputs(buffer, stderr);
            glGetShaderInfoLog(gs, ARRAY_LEN(buffer), NULL, buffer);
            fprintf(stderr, "geometry shader compilation error:\n%.*s\n", (int)ARRAY_LEN(buffer), buffer);
            return EXIT_FAILURE;
        }
    }


    *shader_program = glCreateProgram();
    glAttachShader(*shader_program, vs);
    if (gs_filename)
    {
        glAttachShader(*shader_program, gs);
    }
    glAttachShader(*shader_program, fs);
    glLinkProgram(*shader_program);
    glGetProgramiv(*shader_program, GL_LINK_STATUS, &success);
    if (!success)
    {
        glGetProgramInfoLog(*shader_program, ARRAY_LEN(buffer), NULL, buffer);
        fprintf(stderr, "shader linking error:\n%.*s\n", (int)ARRAY_LEN(buffer), buffer);
        return EXIT_FAILURE;
    }

    glDeleteShader(vs);
    if (gs_filename)
    {
        glDeleteShader(gs);
    }
    glDeleteShader(fs);

    return 0;
}


#endif
