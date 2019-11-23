
#include <sys/resource.h>

#include "util.h"
#include "text.h"

#define PRINT_IF_GL_ERR(...)                                    \
    do {                                                        \
        int __err = glGetError();                               \
        if (__err != 0) {                                       \
            printf("gl error at %d: %d\n", __LINE__, __err);    \
            printf(__VA_ARGS__);                                \
            printf("\n");                                       \
        }                                                       \
    } while (0)


typedef struct
{
    size_t l;
    float *p;
} FloatDArray;
typedef struct
{
    size_t l;
    const char **p;
} StringDArray;




const float UNSPECF = 37.0;

enum
{
    DisplayMode__NORMAL = 0,
    DisplayMode__SPLIT = 1,
};

GLFWwindow *window;
int width, height;
const char *title;
int display_mode;

GLuint fb_shader;
GLuint fb_rectangle_vbo;
GLuint fb_rectangle_vao;

GLuint main_VBO;
GLuint main_VAO;
FloatDArray objects;
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


typedef struct ChunkGLData {
    GLuint VAO;
    GLuint VBO;
    GLsizei len;
    GLsizei capacity;
} ChunkGLData;

#define MAX_RENDERED_CHUNKS 8191
GLuint cuboid_shader;
GLuint cuboid_static_csdata_ubo;
ChunkGLData *cuboid_data[MAX_RENDERED_CHUNKS + 1];
ChunkGLData *cuboid_data_vertical[MAX_RENDERED_CHUNKS + 1];

typedef struct CuboidShaderData {
// uniforms
    float *base_pos;
    float *normal;
    float *right;
    float *up;
    float *front;

    float *view;
    float *projection;
} CuboidShaderData;
CuboidShaderData cuboid_uniforms;
CuboidShaderData cuboid_uniforms_vertical;

GLuint vertical_VBO;
GLuint vertical_VAO;
FloatDArray vertical_objects;
GLuint vertical_fb;
GLuint vertical_tex;
GLuint vertical_rbo;

float *view, *projection;

Font *font;
#define MAX_TEXTS 16
struct
{
    StringDArray a;
    float x;
    float y;
    float x_scale;
    float y_scale;
    float line_spacing;
} screen_text_data[MAX_TEXTS];

int ui_hidden = 0;




void cleanup(void)
{
    glfwDestroyWindow(window);
    glDeleteVertexArrays(1, &main_VAO);
    glDeleteBuffers(1, &main_VBO);
    glDeleteVertexArrays(1, &vertical_VAO);
    glDeleteBuffers(1, &vertical_VBO);
    //glDeleteBuffers(1, &EBO);
    glfwTerminate();

    delete_font(font);
}

static void error_callback(int error, const char *description)
{
    fputs(description, stderr);
    (void)error;
}

int init(void)
{
    const rlim_t stack_size = 128 * 1024 * 1024;
    struct rlimit rl;

    int res;
    if ((res = getrlimit(RLIMIT_STACK, &rl)) == 0)
    {
        if (rl.rlim_cur < stack_size)
        {
            rl.rlim_cur = stack_size;
            if ((res = setrlimit(RLIMIT_STACK, &rl)) != 0)
            {
                return EXIT_FAILURE;
            }
        }
    }

    glfwSetErrorCallback(error_callback);

    if (!glfwInit())
    {
        return EXIT_FAILURE;
    }
    // TODO ???
    // glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_RESIZABLE, GL_TRUE);
    glfwWindowHint(GLFW_SAMPLES, 4);


    window = glfwCreateWindow(width, height, title, NULL, NULL);
    if (!window)
    {
        glfwTerminate();
        return EXIT_FAILURE;
    }

    glfwMakeContextCurrent(window);

    // TODO: figure out cross-platform shit for vsync and shit
    glfwSwapInterval(0);


    glewExperimental = GL_TRUE;
    glewInit();

    //assert(glfwRawMouseMotionSupported());
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED | GLFW_CURSOR_HIDDEN);
    

    CHECK_RES(create_shader(&base_shader, "vertex.glsl", NULL, "fragment.glsl"));
    CHECK_RES(create_shader(&compass_shader, "compass_vertex.glsl", NULL, "compass_fragment.glsl"));
    CHECK_RES(create_shader(&cuboid_shader, "block_vertex.glsl", "block_geometry.glsl", "block_fragment.glsl"));
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


    glGenBuffers(1, &main_VBO);
    glGenVertexArrays(1, &main_VAO);


    glGenBuffers(1, &compass_VBO);
    glGenVertexArrays(1, &compass_VAO);
    glBindVertexArray(compass_VAO);
    glBindBuffer(GL_ARRAY_BUFFER, compass_VBO);
    glBufferData(GL_ARRAY_BUFFER, 6 * sizeof(float), NULL, GL_STREAM_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);


    glGenBuffers(1, &vertical_VBO);
    glGenVertexArrays(1, &vertical_VAO);


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


    font_init();
    font = load_font("font_0.png");


    return 0;
}

int window_size_update(void)
{
    glBindVertexArray(fb_rectangle_vao);
    glBindBuffer(GL_ARRAY_BUFFER, fb_rectangle_vbo);
    float vs[4 * 3] = {
        -1,      -1, 1, 1,       // main area
        UNSPECF, -1, 1, UNSPECF, // compass
        0,       -1, 1, 1,       // vertical view
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


void assign_static_cs_data(int* selected_edges) {
    glGenBuffers(1, &cuboid_static_csdata_ubo);
    glBindBufferBase(GL_UNIFORM_BUFFER, 2, cuboid_static_csdata_ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, cuboid_static_csdata_ubo);
    glBufferData(GL_UNIFORM_BUFFER, 0x80 * 8 * sizeof(int), selected_edges, GL_STATIC_DRAW);
}


void render_objects(FloatDArray os, GLuint VAO, GLuint VBO)
{
    assert(os.l % 6 == 0);

    glUniformMatrix4fv(view_loc, 1, GL_FALSE, view);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, os.l * sizeof(float), os.p, GL_STREAM_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);

    glDrawArrays(GL_TRIANGLES, 0, os.l / 6);
}


void free_chunk_gl_data(ChunkGLData *data) {
    assert(data);

    //printf("freeing ChunkGLData %p\n", (void*)data);

    free(data);
        
    glDeleteBuffers(1, &data->VBO);
    glDeleteVertexArrays(1, &data->VAO);
}

void assign_chunk_gl_data(ChunkGLData **data_p, float* cube_corners, int cube_corners_len) {
    assert(data_p);
    assert(cube_corners_len % 8 == 0);
    ChunkGLData *data;

    if (*data_p && (*data_p)->capacity < cube_corners_len) {
        free_chunk_gl_data(*data_p);
        *data_p = NULL;
    }

    if (*data_p == NULL) {
        data = calloc(1, sizeof(ChunkGLData));
        assert(data);

        glGenBuffers(1, &data->VBO);
        glGenVertexArrays(1, &data->VAO);
        glBindVertexArray(data->VAO);
        glBindBuffer(GL_ARRAY_BUFFER, data->VBO);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (GLvoid*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (GLvoid*)(4 * sizeof(GLfloat)));
        glEnableVertexAttribArray(1);

        // TODO round up to power of 2?
        data->capacity = cube_corners_len;
        glBufferData(GL_ARRAY_BUFFER, data->capacity * sizeof(float), NULL, GL_DYNAMIC_DRAW);
        
        *data_p = data;
    } else {
        data = *data_p;
        glBindBuffer(GL_ARRAY_BUFFER, data->VBO);
    }
    
    //printf("%p\twrote %d\n", (void*)data, cube_corners_len);

    glBufferSubData(GL_ARRAY_BUFFER, 0, cube_corners_len * sizeof(float), cube_corners);
    PRINT_IF_GL_ERR("%d", cube_corners_len);
    data->len = cube_corners_len / 8;
    
    /* for (int j = 0; j < data->len; j++) { */
    /*     printf("%.2f %.2f %.2f %.2f\t %.2f %.2f %.2f %.2f\n", cube_corners[j], cube_corners[j + 1], cube_corners[j + 2], cube_corners[j + 3], cube_corners[j + 4], cube_corners[j + 5], cube_corners[j + 6], cube_corners[j + 7]); */
    /* } */
}


void render_cuboids(/*const*/ ChunkGLData **data, const CuboidShaderData* uniforms) {
    assert(data);
    assert(uniforms);

    // TODO make these not per-frame
    GLint loc;

    loc = glGetUniformLocation(cuboid_shader, "base_pos");
    assert(loc != -1);
    glUniform4fv(loc, 1, uniforms->base_pos);
    //printf("base_pos %d %f %f %f %f\n", loc, uniforms->base_pos[0], uniforms->base_pos[1], uniforms->base_pos[2], uniforms->base_pos[3]);
    loc = glGetUniformLocation(cuboid_shader, "normal");
    //assert(loc != -1);
    glUniform4fv(loc, 1, uniforms->normal);
    loc = glGetUniformLocation(cuboid_shader, "right");
    //assert(loc != -1);
    glUniform4fv(loc, 1, uniforms->right);
    loc = glGetUniformLocation(cuboid_shader, "up");
    //assert(loc != -1);
    glUniform4fv(loc, 1, uniforms->up);
    loc = glGetUniformLocation(cuboid_shader, "front");
    //assert(loc != -1);
    glUniform4fv(loc, 1, uniforms->front);

    loc = glGetUniformLocation(cuboid_shader, "view");
    //assert(loc == 5);
    glUniformMatrix4fv(loc, 1, GL_FALSE, uniforms->view);
    loc = glGetUniformLocation(cuboid_shader, "projection");
    //assert(loc == 6);
    glUniformMatrix4fv(loc, 1, GL_FALSE, uniforms->projection);

    for (GLsizei i = 0; data[i] != NULL; i++) {
        //printf("rendering %d\n", i);
        glBindVertexArray(data[i]->VAO);
        glDrawArrays(GL_POINTS, 0, data[i]->len);
        if (i < 5) {
            //printf("idx %d: %p %d %u %u\n", i, (void*)data[i], data[i]->VAO, data[i]->len, data[i]->capacity);
        }
        //fflush(stdout);

        assert(glGetError() == 0);
        PRINT_IF_GL_ERR("%d: %d\t%d\n", i, data[i]->VAO, data[i]->len);

    }
}


// TODO i don't think these state changes are in the optimal order
void render(void)
{
    glfwSetWindowTitle(window, title);

    glfwGetFramebufferSize(window, &width, &height);
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

    glEnable(GL_DEPTH_TEST);

    {
        glUseProgram(cuboid_shader);

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
        glClearColor(150.0 / 255.0, 127.0 / 255.0, 96.0 / 255.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        render_cuboids(cuboid_data, &cuboid_uniforms);


        switch (display_mode)
        {
        case DisplayMode__NORMAL:
            break;

        case DisplayMode__SPLIT:
            glViewport(0, 0, width / 2, height);

            glBindFramebuffer(GL_FRAMEBUFFER, vertical_fb);
            glClearColor(130.0 / 255.0, 167.0 / 255.0, 90.0 / 255.0, 1.0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            render_cuboids(cuboid_data_vertical, &cuboid_uniforms_vertical);
            break;

        default:
            assert(0);
        }
    }
    
    {
        // TODO gross and bad
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
        glUseProgram(base_shader);

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
        render_objects(objects, main_VAO, main_VBO);

        switch (display_mode)
        {
        case DisplayMode__NORMAL:
            break;

        case DisplayMode__SPLIT:
            glViewport(0, 0, width / 2, height);

            glBindFramebuffer(GL_FRAMEBUFFER, vertical_fb);
            render_objects(vertical_objects, vertical_VAO, vertical_VBO);
            break;

        default:
            assert(0);
        }
    
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    }


    glViewport(0, 0, width, height);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.3, 0.3, 0.3, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(fb_shader);
    glBindVertexArray(fb_rectangle_vao);
    glDisable(GL_DEPTH_TEST);
    glBindTexture(GL_TEXTURE_2D, main_tex);

    glUniform1i(0, ui_hidden);

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


    if (!ui_hidden) {
        for (size_t i = 0; i < MAX_TEXTS; i++)
        {
            if (screen_text_data[i].a.p)
            {
                for (size_t j = 0; j < screen_text_data[i].a.l; j++)
                {
                    //render_text(lines_to_render.p[i], font, -0.6, 1 - i * 0.1, 0.000001 * height, 0.000001 * width);
                    //render_text(screen_text_data[i].a.p[j], font, -0.6, 1 - i * 0.1, 0.001, 0.001 * ratio);
                    render_text(screen_text_data[i].a.p[j],
                                font,
                                screen_text_data[i].x,
                                screen_text_data[i].y - j * screen_text_data[i].line_spacing,
                                screen_text_data[i].x_scale,
                                screen_text_data[i].y_scale * ratio);
                }
            }
        }
    }
    glfwSwapBuffers(window);
}


void wait_for_next_frame(void)
{
    // TODO: bleuuuurggh
    const double frame_time = 1.0 / 59.95;
    int i = 0;
    while (glfwGetTime() < frame_time) {i++;}
    //printf("%d\n", i / 5000);
    glfwSetTime(0);
}
