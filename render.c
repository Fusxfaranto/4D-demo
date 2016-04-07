
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
} FloatDArray;


const float UNSPECF = 37.0;

enum
{
    DisplayMode__NORMAL = 0,
    DisplayMode__SPLIT = 1,
};

GLFWwindow *w;
int width, height;
const char *title;
int display_mode;

GLuint fb_shader;
GLuint fb_rectangle_vbo;
GLuint fb_rectangle_vao;

#define MAX_OBJECTS 1000
GLuint VBOs[MAX_OBJECTS];
GLuint VAOs[MAX_OBJECTS];
FloatDArray objects[MAX_OBJECTS];
int object_count;
//GLuint EBO;
GLuint base_shader;
GLuint texture1, texture2;
GLuint view_loc, projection_loc;
GLuint main_fb;
GLuint main_tex;
GLuint main_rbo;

float *compass_base;
float *compass;
float *compass_projection;
GLuint compass_projection_location;
GLuint compass_VBO;
GLuint compass_VAO;
GLuint compass_shader;
GLuint compass_fb;
GLuint compass_tex;

GLuint vertical_VBOs[MAX_OBJECTS];
GLuint vertical_VAOs[MAX_OBJECTS];
FloatDArray vertical_objects[MAX_OBJECTS];
int vertical_object_count;
GLuint vertical_fb;
GLuint vertical_tex;
GLuint vertical_rbo;

float *view, *projection;



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
    error++; // silence warning
}

static int create_shader(GLuint *shader_program, const char *vs_filename,
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
            cleanup();
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
        cleanup();
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


    CHECK_RES(create_shader(&base_shader, "vertex.glsl", NULL, "fragment.glsl"));
    CHECK_RES(create_shader(&compass_shader, "compass_vertex.glsl", NULL,"compass_fragment.glsl"));
    CHECK_RES(create_shader(&fb_shader, "fb_vertex.glsl", "fb_geometry.glsl", "fb_fragment.glsl"));

    view_loc = glGetUniformLocation(base_shader, "view");
    projection_loc = glGetUniformLocation(base_shader, "projection");
    compass_projection_location = glGetUniformLocation(compass_shader, "projection");


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
    glGenVertexArrays(MAX_OBJECTS, VAOs);


    glGenBuffers(1, &compass_VBO);
    glGenVertexArrays(1, &compass_VAO);
    glBindVertexArray(compass_VAO);
    glBindBuffer(GL_ARRAY_BUFFER, compass_VBO);
    glBufferData(GL_ARRAY_BUFFER, 6 * sizeof(float), NULL, GL_STREAM_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);


    glGenBuffers(MAX_OBJECTS, vertical_VBOs);
    glGenVertexArrays(MAX_OBJECTS, vertical_VAOs);


    glGenBuffers(1, &fb_rectangle_vbo);
    glGenVertexArrays(1, &fb_rectangle_vao);


    glGenFramebuffers(1, &main_fb);
    glBindFramebuffer(GL_FRAMEBUFFER, main_fb);
    glGenTextures(1, &main_tex);
    glBindTexture(GL_TEXTURE_2D, main_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, main_tex, 0);
    glGenRenderbuffers(1, &main_rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, main_rbo);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, main_rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    glGenFramebuffers(1, &compass_fb);
    glBindFramebuffer(GL_FRAMEBUFFER, compass_fb);
    glGenTextures(1, &compass_tex);
    glBindTexture(GL_TEXTURE_2D, compass_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, compass_tex, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    glGenFramebuffers(1, &vertical_fb);
    glBindFramebuffer(GL_FRAMEBUFFER, vertical_fb);
    glGenTextures(1, &vertical_tex);
    glBindTexture(GL_TEXTURE_2D, vertical_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, vertical_tex, 0);
    glGenRenderbuffers(1, &vertical_rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, vertical_rbo);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, vertical_rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);


    glEnable(GL_DEBUG_OUTPUT);
    glEnable(GL_DEPTH_TEST);
    //glEnable(GL_CULL_FACE);
    glEnable(GL_MULTISAMPLE);

    return 0;
}

int window_size_update(void)
{
    glBindVertexArray(fb_rectangle_vao);
    glBindBuffer(GL_ARRAY_BUFFER, fb_rectangle_vbo);
    float vs[4 * 3] = {
        -1,      -1, 1, 1,      // main area
        UNSPECF, -1, 1, UNSPECF, // compass
        0,       -1, 1, 1,      // vertical view
    };
    switch (display_mode)
    {
    case DisplayMode__NORMAL:
        // already good
        break;

    case DisplayMode__SPLIT:
        vs[2] = 0; // make main area half width
        break;

    default:
        assert(0);
    }
    glBufferData(GL_ARRAY_BUFFER, sizeof(vs), vs, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);

    //float mag = sqrt(width * width + height * height);

    // TODO: update glTexImage2D when window size changes
    glUseProgram(compass_shader);
    // TODO: actually use this; and then see if it really needs to be updated on window size change
    glUniformMatrix4fv(compass_projection_location, 1, GL_FALSE, compass_projection);


    glUseProgram(base_shader);
    glUniformMatrix4fv(projection_loc, 1, GL_FALSE, projection);

    float alt_w = width;
    switch (display_mode)
    {
    case DisplayMode__NORMAL:
        break;

    case DisplayMode__SPLIT:
        alt_w /= 2;
        break;

    default:
        assert(0);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, main_fb);
    glBindTexture(GL_TEXTURE_2D, main_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, alt_w, height, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    glBindRenderbuffer(GL_RENDERBUFFER, main_rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
    CHECK_RES(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE);


    glBindFramebuffer(GL_FRAMEBUFFER, compass_fb);
    glBindTexture(GL_TEXTURE_2D, compass_tex);
    float cw = fmax(width, height) / 2.0;
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, cw, cw, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, 0);
    CHECK_RES(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE);


    glBindFramebuffer(GL_FRAMEBUFFER, vertical_fb);
    glBindTexture(GL_TEXTURE_2D, vertical_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, alt_w, height, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    glBindRenderbuffer(GL_RENDERBUFFER, vertical_rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    CHECK_RES(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);


    glBindBuffer(GL_ARRAY_BUFFER, fb_rectangle_vbo);
    GLfloat *m = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
    float ratio = width / (float) height;
    m[4] = 1 - 1 / (ratio > 1 ? ratio : 1);
    //m[5] = -1;
    //m[6] = 1;
    m[7] = -1 + 1 * (ratio < 1 ? ratio : 1);
    assert(glUnmapBuffer(GL_ARRAY_BUFFER));

    return 0;
}

void render(void)
{
    glfwSetWindowTitle(w, title);

    glfwGetFramebufferSize(w, &width, &height);
    float ratio = width / (float) height;

    float cw = fmax(width, height) / 2.0;
    glViewport(0, 0, cw, cw);

    glBindFramebuffer(GL_FRAMEBUFFER, compass_fb);
    glClearColor(0, 0, 0.8, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    //glEnable(GL_DEPTH_TEST);

    glUseProgram(compass_shader);
    glDisable(GL_DEPTH_TEST);
    glLineWidth(10.0);
    glBindVertexArray(compass_VAO);
    glBindBuffer(GL_ARRAY_BUFFER, compass_VBO);
    glBufferData(GL_ARRAY_BUFFER, 6 * sizeof(float), NULL, GL_STREAM_DRAW);
    GLfloat *m = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    //glBufferSubData(GL_ARRAY_BUFFER, 0 * sizeof(float), 3 * sizeof(float), &compass_base);
    //glBufferSubData(GL_ARRAY_BUFFER, 3 * sizeof(float), 3 * sizeof(float), &compass);
    m[0] = compass_base[0];
    m[1] = compass_base[1];
    m[2] = compass_base[2];
    m[3] = compass[0];
    m[4] = compass[1];
    m[5] = compass[2];
    assert(glUnmapBuffer(GL_ARRAY_BUFFER));
    /* float testo[6]; */
    /* glGetBufferSubData(GL_ARRAY_BUFFER, 0 * sizeof(float), 6 * sizeof(float), &testo); */
    /* printf("{%f, %f, %f} {%f, %f, %f}\n{%f, %f, %f} {%f, %f, %f}\n\n", */
    /*        compass_base[0], compass_base[1], compass_base[2], */
    /*        compass[0], compass[1], compass[2], */
    /*        testo[0], testo[1], testo[2], testo[3], testo[4], testo[5]); */
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);
    glDrawArrays(GL_LINES, 0, 2);


    switch (display_mode)
    {
    case DisplayMode__NORMAL:
        glViewport(0, 0, width, height);
        break;

    case DisplayMode__SPLIT:
        glViewport(0, 0, width / 2, height);
        break;

    default:
        assert(0);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, main_fb);
    glClearColor(0.1f, ratio / 5, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(base_shader);
    glEnable(GL_DEPTH_TEST);

    glUniformMatrix4fv(view_loc, 1, GL_FALSE, view);

    for (int i = 0; i < object_count; i++)
    {
        glBindVertexArray(VAOs[i]);

        glBindBuffer(GL_ARRAY_BUFFER, VBOs[i]);
        glBufferData(GL_ARRAY_BUFFER, objects[i].l * sizeof(float), objects[i].p, GL_STREAM_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(1);

        glDrawArrays(GL_TRIANGLES, 0, objects[i].l / 6);
    }

    switch (display_mode)
    {
    case DisplayMode__NORMAL:
        break;

    case DisplayMode__SPLIT:
        glViewport(0, 0, width / 2, height);

        glBindFramebuffer(GL_FRAMEBUFFER, vertical_fb);
        glClearColor(1, 1, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glUniformMatrix4fv(view_loc, 1, GL_FALSE, view);

        for (int i = 0; i < vertical_object_count; i++)
        {
            glBindVertexArray(vertical_VAOs[i]);

            glBindBuffer(GL_ARRAY_BUFFER, vertical_VBOs[i]);
            glBufferData(GL_ARRAY_BUFFER, vertical_objects[i].l * sizeof(float), vertical_objects[i].p, GL_STREAM_DRAW);
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)0);
            glEnableVertexAttribArray(0);
            glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
            glEnableVertexAttribArray(1);

            glDrawArrays(GL_TRIANGLES, 0, vertical_objects[i].l / 6);
        }
        break;

    default:
        assert(0);
    }


    glViewport(0, 0, width, height);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.3, 0.3, 0.3, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(fb_shader);
    glBindVertexArray(fb_rectangle_vao);
    glDisable(GL_DEPTH_TEST);
    glBindTexture(GL_TEXTURE_2D, main_tex);
    glDrawArrays(GL_POINTS, 0, 1);
    /* glBindTexture(GL_TEXTURE_2D, compass_tex); */
    /* glDrawArrays(GL_POINTS, 1, 1); */
    switch (display_mode)
    {
    case DisplayMode__NORMAL:
        break;

    case DisplayMode__SPLIT:
        glBindTexture(GL_TEXTURE_2D, vertical_tex);
        glDrawArrays(GL_POINTS, 2, 1);
        break;

    default:
        assert(0);
    }
    glBindVertexArray(0);


    glBindVertexArray(0);

    glfwSwapBuffers(w);

    // TODO: bleuuuurggh
    const double frame_time = 1.0 / 59.95;
    int i = 0;
    while (glfwGetTime() < frame_time) {i++;}
    //printf("%d\n", i / 5000);
    glfwSetTime(0);
}
