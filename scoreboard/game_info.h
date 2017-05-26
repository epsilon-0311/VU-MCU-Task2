/**
 * author:	Bernhard Petschina
 * date:	13.05.2015
 */

#ifndef GAME_INFO_H
#define GAME_INFO_H

#include <stdint.h>
#include <stdbool.h>

#define VECTOR_INITIAL_CAPACITY 5
#define NUMBER_OF_HIGHSCORES 10

typedef struct {
	char name[17];
	uint32_t score;
	bool ended;
} game_info_t;

typedef struct {
  int size;      // slots used so far
  int capacity;  // total available slots
  game_info_t *data;
} vector;

typedef struct highscore_list {
	game_info_t* games[NUMBER_OF_HIGHSCORES];
} highscore_list_t;

#define SHM_PERMISSION 0666
#define SHM_KEY 5432

typedef struct {
	bool changed;
	int size;
	game_info_t games[NUMBER_OF_HIGHSCORES];
} highscore_list_shm_t;

void vector_init(vector *vector, highscore_list_t *highscores);
int new_game(vector *vector);
bool update_score(vector *vector, int index, uint32_t score);
bool update_name(vector *vector, int index, char *name);
bool end_game(vector *vector, int index, highscore_list_t *highscores, highscore_list_shm_t *shm_highscores);
game_info_t* vector_get(vector *vector, int index);

void vector_free(vector *vector);

#endif //GAME_INFO_H
