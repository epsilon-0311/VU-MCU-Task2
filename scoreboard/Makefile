#author: Bernhard Petschina
#date: 13.05.2015


FILENAME    = scoreboard
OBJECTS_SB  = scoreboard.o game_info.o
OBJECTS_HS  = highscores.o game_info.o

CC = gcc
CFLAGS = -std=gnu99 -Wall -pedantic -g

all: scoreboard highscores

scoreboard: $(OBJECTS_SB)
	$(CC) -o scoreboard $(OBJECTS_SB)

highscores: $(OBJECTS_HS)
	$(CC) -o highscores $(OBJECTS_HS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f scoreboard highscores *.o
