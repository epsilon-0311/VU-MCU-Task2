/**
 * author:	Bernhard Petschina
 * date:	13.05.2015
 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>
#include <signal.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "game_info.h"

highscore_list_shm_t *shm_com;

void release_resources()
{
	shmdt((void *)shm_com);
}

void release_resources_signal(int signal)
{
	exit(EXIT_SUCCESS);
}

int main(int argc,char** argv)
{
	int shmid;

	atexit(release_resources);
	signal(SIGINT, release_resources_signal);
	signal(SIGQUIT, release_resources_signal);
	signal(SIGTERM, release_resources_signal);

	if((shmid = shmget(SHM_KEY, sizeof(highscore_list_shm_t), SHM_PERMISSION)) < 0)
	{
		fprintf(stderr, "ERROR: Could not get id of shared memory.\n Is the scoreboard running?\n");
		exit(EXIT_FAILURE);
	}
	if((shm_com = (highscore_list_shm_t *)shmat(shmid, NULL, 0)) == (void *)-1)
	{
		fprintf(stderr, "ERROR: Could not attach to shared memory\n");
		exit(EXIT_FAILURE);
	}

	system("clear");

	while(true)
	{
		if(shm_com->changed)
		{
			system("clear");
			for(int x=0; x<shm_com->size; x++)
			{
				printf("%i: %s - %u\n", x, shm_com->games[x].name, shm_com->games[x].score);
			}
			shm_com->changed = 0;
		}
		sleep(1);
	}

	exit(EXIT_SUCCESS);
}
