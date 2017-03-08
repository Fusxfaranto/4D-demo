
#include "util.h"


#define PTC(coord_, width_) (coord_ + coord_ + 1.0) / (2 * width_)


#define MAX_CHARS 128

typedef struct
{
    unsigned char* image;
    float positions[MAX_CHARS];
    float widths[MAX_CHARS];
    int height;
    int total_width;
    GLuint tex;
} Font;


GLuint font_shader;
GLuint font_VAO;
GLuint font_VBO;
GLint font_start_uniform;
GLint font_end_uniform;



int font_init()
{
    CHECK_RES(create_shader(&font_shader, "font_vertex.glsl", NULL, "font_fragment.glsl"));
    font_start_uniform = glGetUniformLocation(font_shader, "font_start");
    //font_end_uniform = glGetUniformLocation(font_shader, "font_end");

    glGenBuffers(1, &font_VBO);
    glGenVertexArrays(1, &font_VAO);

    return 0;
}

Font* load_font(const char *filename)
{
    Font *f = malloc(sizeof(Font));
    memset(f, 0, sizeof(Font));

    f->image = SOIL_load_image(filename, &f->total_width, &f->height, 0, SOIL_LOAD_RGBA);

    // TODO: don't hardcode
#include "font.h"

    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &f->tex);
    glBindTexture(GL_TEXTURE_2D, f->tex);

    /* glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); */
    /* glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); */
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, f->total_width, f->height, 0, GL_RGBA, GL_UNSIGNED_BYTE, f->image);

    return f;
}

void delete_font(Font *f)
{
    SOIL_free_image_data(f->image);
    free(f);
}


void render_text(const char *s, Font *f, float x, float y, float x_scale, float y_scale)
{
    glUseProgram(font_shader);
    glBindTexture(GL_TEXTURE_2D, f->tex);

    float new_y = y - f->height * y_scale;
    for (; *s; s++)
    {
        float new_x = x + f->total_width * f->widths[(int)*s] * x_scale;

        float rect[4][4] =
            {
                {x,     y    , f->positions[(int)*s],                      0},
                {new_x, y    , f->positions[(int)*s] + f->widths[(int)*s], 0},
                {x,     new_y, f->positions[(int)*s],                      1},
                {new_x, new_y, f->positions[(int)*s] + f->widths[(int)*s], 1},
            };

        /* printf("%c\n", *s); */
        /* printf("%f %f %f %f\n", x, -y, f->positions[(int)*s], 0.0); */
        /* printf("%f %f %f %f\n", new_x, -y, f->positions[(int)*s] + f->widths[(int)*s], 0.0); */
        /* printf("%f %f %f %f\n", x, -new_y, f->positions[(int)*s], 1.0); */
        /* printf("%f %f %f %f\n", new_x, -new_y, f->positions[(int)*s] + f->widths[(int)*s], 1.0); */
        /* printf("\n"); */

        assert(glGetUniformLocation(font_shader, "font_start") == font_start_uniform);
        glUniform1f(font_start_uniform, f->positions[(int)*s]);
        //glUniform1f(font_end_uniform, f->widths[(int)*s]);

        glBindVertexArray(font_VAO);
        glBindBuffer(GL_ARRAY_BUFFER, font_VBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(rect), rect, GL_DYNAMIC_DRAW);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (GLvoid*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (GLvoid*)(2 * sizeof(float)));
        glEnableVertexAttribArray(1);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        x = new_x;
    }

    //assert(0);
}
