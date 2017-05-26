/**
 * author:	Bernhard Petschina
 * date:	13.05.2015
 */
 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "game_info.h"

static void vector_double_capacity_if_full(vector *vector)
{
	if (vector->size >= vector->capacity)
	{
		vector->capacity *= 2;
		vector->data = realloc(vector->data, sizeof(game_info_t) * vector->capacity);
	}
}

void vector_init(vector *vector, highscore_list_t *highscores)
{
	vector->size = 0;
	vector->capacity = VECTOR_INITIAL_CAPACITY;
	
	for(int x=0; x<NUMBER_OF_HIGHSCORES; x++)
		highscores->games[x] = NULL;
	
	vector->data = malloc(sizeof(game_info_t) * vector->capacity);
}

int new_game(vector *vector)
{
	vector_double_capacity_if_full(vector);

	vector->data[vector->size].name[0] = 0;
	vector->data[vector->size].score = 0;
	vector->data[vector->size].ended = false;
	vector->size++;
	
	return vector->size-1;
}

bool update_score(vector *vector, int index, uint32_t score)
{
	game_info_t *game = vector_get(vector, index);
	if(game == NULL)
		return false;
	
	if(game->ended)
		return false;
		
	game->score = score;
	return true;
}

bool update_name(vector *vector, int index, char *name)
{
	game_info_t *game = vector_get(vector, index);
	if(game == NULL)
		return false;
	
	if(game->ended)
		return false;
		
	strncpy(game->name, name, 16);
	game->name[16] = 0;
	return true;
}

bool end_game(vector *vector, int index, highscore_list_t *highscores, highscore_list_shm_t *shm_highscores)
{
	bool changed = 0;
	
	game_info_t *game = vector_get(vector, index);
	if(game == NULL)
		return false;
	
	if(game->ended == true)
		return false;
		
	game->ended = true;
	
	for(int x=0; x<NUMBER_OF_HIGHSCORES; x++)
	{
		if((highscores->games[x] != NULL) && (game->score >= highscores->games[x]->score))
		{
			for(int y = NUMBER_OF_HIGHSCORES-1; y > x; y--)
				highscores->games[y] = highscores->games[y-1];
			
			highscores->games[x] = game;
			changed = 1;
			break;
		}
		else if(highscores->games[x] == NULL)
		{
			highscores->games[x] = game;
			changed = 1;
			break;
		}
	}
	
	if(changed)
	{
		int x;
		for(x=0; x<NUMBER_OF_HIGHSCORES; x++)
		{
			if(highscores->games[x] != NULL)
			{
				strcpy(shm_highscores->games[x].name, highscores->games[x]->name);
				shm_highscores->games[x].score = highscores->games[x]->score;
			}
			else
				break;
		}
		shm_highscores->size = x;
		shm_highscores->changed = 1;
	}
	
	return true;
}

game_info_t* vector_get(vector *vector, int index)
{
	if (index >= vector->size || index < 0)
		return NULL;
	
	return &(vector->data[index]);
}

void vector_free(vector *vector)
{
	free(vector->data);
	vector->data = NULL;
}
