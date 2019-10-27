
NAME := main
C_SRCS := $(wildcard *.c)
D_SRCS := $(wildcard *.d)
C_OBJS := ${C_SRCS:.c=.o}
D_OBJS := ${D_SRCS:.d=.o}
OBJS := $(C_OBJS) $(D_OBJS)
#INCLUDE_DIRS :=
#LIBRARY_DIRS :=
#LIBRARIES :=

#CPPFLAGS += $(foreach includedir,$(INCLUDE_DIRS),-I$(includedir))
#LDFLAGS += $(foreach librarydir,$(LIBRARY_DIRS),-L$(librarydir))
#LDFLAGS += $(foreach library,$(LIBRARIES),-l$(library))

#CC := ./gdc/x86_64-pc-linux-gnu/bin/x86_64-linux-gnu-gcc
#DC := ./gdc/x86_64-pc-linux-gnu/bin/x86_64-linux-gnu-gdc
#DC := ./ldc/build/bin/ldc2
#DC := gdc
#DC := ldc2
DC := dmd

CFLAGS := -m64 -g -c -O3 -std=c11 -pedantic -Wall -Werror -Wno-error=unused-variable -Iinclude #-I/usr/include/freetype2/ #-Iftgl/src/
DFLAGS := -m64 -g -c -O
#DFLAGS += -d-debug=prof
DFLAGS += # -debug=prof # -profile=gc
#LDFLAGS := -Llib -lm -lSOIL -lGLEW -lglfw -lGL

LDFLAGS := -L=-Llib
LDFLAGS += -L=-lm
LDFLAGS += -L=-lSOIL
LDFLAGS += -L=-lglfw
LDFLAGS += -L=-lGL
LDFLAGS += -L=-lGLEW
#LDFLAGS := -L=-rpath=lib
#LDFLAGS += -L=-l:libGLEW.so

.PHONY: all clean distclean

all: $(NAME)

$(NAME): $(OBJS)
#	$(DC) $(OBJS) $(LDFLAGS) -o $(NAME)
	$(DC) -L=-rpath=lib $(OBJS) $(LDFLAGS) -of$(NAME)

$(D_OBJS): $(D_SRCS)
	$(DC) $(D_SRCS) $(DFLAGS)

render.o: render.c text.h util.h font.h
	$(CC) render.c $(CFLAGS)


#windows:
#	$(CC) render.c -g -c -std=c11 -pedantic -Wall -Werror
#	$(DC) $(D_SRCS) -g -c -mtriple=x86_64-pc-mingw32
#	$(DC) $(OBJS) $(LDFLAGS) -of=$(NAME)

clean:
	@- $(RM) $(NAME)
	@- $(RM) $(OBJS)

distclean: clean
