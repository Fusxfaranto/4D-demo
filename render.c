
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


typedef struct
{
    size_t l;
    float *p;
} FloatDarray;

GLFWwindow *w;
#define MAX_OBJECTS 1000
GLuint VBOs[MAX_OBJECTS];
GLuint VAOs[MAX_OBJECTS];
FloatDarray objects[MAX_OBJECTS];
int object_count;
//GLuint EBO;
GLuint base_shader;
GLuint texture1, texture2;
GLuint view_loc, model_loc, projection_loc;

int width, height;
const char *title;
float *view, *projection;
float *models[MAX_OBJECTS];


void cleanup(void)
{
    glfwDestroyWindow(w);
    for (int i = 0; i < object_count; i++)
    {
        glDeleteVertexArrays(1, &VAOs[i]);
        glDeleteBuffers(1, &VBOs[i]);
    }
    //glDeleteBuffers(1, &EBO);
    glfwTerminate();
}

static void error_callback(int error, const char *description)
{
    fputs(description, stderr);
}

static int create_shader(const char *vs_filename, const char *fs_filename, GLuint *shader_program)
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
        cleanup();
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
        cleanup();
        return EXIT_FAILURE;
    }


    *shader_program = glCreateProgram();
    glAttachShader(*shader_program, vs);
    glAttachShader(*shader_program, fs);
    glLinkProgram(*shader_program);
    glGetProgramiv(*shader_program, GL_LINK_STATUS, &success);
    if (!success)
    {
        glGetProgramInfoLog(*shader_program, ARRAY_LEN(buffer), NULL, buffer);
        fprintf(stderr, "shader linking error:\n%.*s\n", (int)ARRAY_LEN(buffer), buffer);
        cleanup();
        return EXIT_FAILURE;
    }

    glDeleteShader(vs);
    glDeleteShader(fs);

    return 0;
}

int init()
{
    glfwSetErrorCallback(error_callback);

    if (!glfwInit())
    {
        return EXIT_FAILURE;
    }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);
    glfwWindowHint(GLFW_SAMPLES, 4);


    w = glfwCreateWindow(width, height, title, NULL, NULL);
    if (!w)
    {
        glfwTerminate();
        return EXIT_FAILURE;
    }

    glfwMakeContextCurrent(w);

    // TODO: figure out cross-platform shit for vsync and shit
    glfwSwapInterval(1);


    glewExperimental = GL_TRUE;
    glewInit();


    CHECK_RES(create_shader("vertex.glsl", "fragment.glsl", &base_shader));


    /* int width, height; */
    /* unsigned char* image = SOIL_load_image("cake.png", &width, &height, 0, SOIL_LOAD_RGB); */
    /* assert(image); */
    /* glGenTextures(1, &texture1); */
    /* glActiveTexture(GL_TEXTURE0); */
    /* glBindTexture(GL_TEXTURE_2D, texture1); */
    /* glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, image); */
    /* glGenerateMipmap(GL_TEXTURE_2D); */
    /* SOIL_free_image_data(image); */

    /* image = SOIL_load_image("bee.png", &width, &height, 0, SOIL_LOAD_RGB); */
    /* assert(image); */
    /* glGenTextures(1, &texture2); */
    /* glActiveTexture(GL_TEXTURE1); */
    /* glBindTexture(GL_TEXTURE_2D, texture2); */
    /* glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, image); */
    /* glGenerateMipmap(GL_TEXTURE_2D); */
    /* SOIL_free_image_data(image); */

    /* glBindTexture(GL_TEXTURE_2D, 0); */


    glGenBuffers(MAX_OBJECTS, VBOs);
    //glGenBuffers(1, &EBO);
    glGenVertexArrays(MAX_OBJECTS, VAOs);

    for (int i = 0; i < MAX_OBJECTS; i++)
    {
        glBindVertexArray(VAOs[i]);

        //glBindBuffer(GL_ARRAY_BUFFER, VBOs[i]);
        //glBufferData(GL_ARRAY_BUFFER, object_lens[i] * 36 * sizeof(objects[0]), objects[i], GL_DYNAMIC_DRAW);

        //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
        //glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

        // position
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)0);
        glEnableVertexAttribArray(0);
        // color
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(1);
        // texture
        //glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
        //glEnableVertexAttribArray(2);
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    model_loc = glGetUniformLocation(base_shader, "model");
    view_loc = glGetUniformLocation(base_shader, "view");
    projection_loc = glGetUniformLocation(base_shader, "projection");

    glEnable(GL_DEBUG_OUTPUT);
    glEnable(GL_DEPTH_TEST);
    //glEnable(GL_CULL_FACE);
    glEnable(GL_MULTISAMPLE);

    return 0;
}

void render(void)
{
    glfwSetWindowTitle(w, title);

    float ratio;
    glfwGetFramebufferSize(w, &width, &height);
    ratio = width / (float) height;
    glViewport(0, 0, width, height);
    glClearColor(0.1f, ratio / 5, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(base_shader);

    /* GLint vertexColorLocation = glGetUniformLocation(base_shader, "foo"); */
    /* assert(vertexColorLocation != -1); */
    /* glUniform4f(vertexColorLocation, 1.0f, sin(glfwGetTime()) / 2.0f + 0.5f, 1.0f, 1.0f); */

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture1);
    glUniform1i(glGetUniformLocation(base_shader, "tex1"), 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, texture2);
    glUniform1i(glGetUniformLocation(base_shader, "tex2"), 1);

    glUniformMatrix4fv(view_loc, 1, GL_FALSE, view);
    // TODO don't update every frame
    glUniformMatrix4fv(projection_loc, 1, GL_FALSE, projection);

    for (int i = 0; i < object_count; i++)
    {
        glBindVertexArray(VAOs[i]);

        glBindBuffer(GL_ARRAY_BUFFER, VBOs[i]);
        // TODO:  shouldn't this be 6 not 36
        //        or rather nothing at all
        glBufferData(GL_ARRAY_BUFFER, objects[i].l * sizeof(float), objects[i].p, GL_STREAM_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(1);

        glUniformMatrix4fv(model_loc, 1, GL_FALSE, models[i]);

        //glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        //printf("%p\n", (void*)objects[i].p);
        //printf("%zu\n", objects[i].l);
        glDrawArrays(GL_TRIANGLES, 0, objects[i].l / 6);
    }

    glBindVertexArray(0);

    glfwSwapBuffers(w);

    // TODO: this might be bad/suboptimal for sub-60 refresh rate monitors, do those even exist???
    const double frame_time = 1.0 / 59.95;
    while (glfwGetTime() < frame_time) {}
    glfwSetTime(0);
}
