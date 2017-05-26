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
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "game_info.h"

#define BUF_SIZE 255
#define MAX_NAME 17	//16 chars + zero


vector games;
highscore_list_t highscores;
FILE *fstore = NULL;
static int shmid;

void usage(char *progname)
{
	fprintf(stderr, "Usage: %s [-v] PORT\n", progname);
	vector_free(&games);

	if(fstore != NULL)
		fclose(fstore);

	exit(1);
}

bool loadHighscore(char *progname, char *filename, int verbose, highscore_list_shm_t *shm_com)
{
	char buffer[MAX_NAME];
	int x;
	char *endptr;
	uint32_t score;

	if(verbose)
		printf("Loading highscores...\n");

	FILE *fload = fopen(filename, "r");
	if(fload == NULL)
	{
		fprintf(stderr, "%s: Invalid file %s\n", progname, filename);
		return false;
	}

	while(fgets(buffer, MAX_NAME, fload) != NULL)
	{
		x = new_game(&games);
		if(buffer[strlen(buffer)-1] == '\n')
			buffer[strlen(buffer)-1] = 0;

		if(!update_name(&games, x, buffer))
		{
			fprintf(stderr, "%s: Invalid name: %s\n", progname, buffer);
			fclose(fload);
			return false;
		}

		if(verbose)
			printf("%s - ", buffer);

		if(fgets(buffer, MAX_NAME, fload) == NULL)
		{
			fprintf(stderr, "%s: Invalid structure of file\n", progname);
			fclose(fload);
			return false;
		}
		score = strtol(buffer, &endptr, 10);
		if(score == 0 && endptr == buffer)
		{
			fprintf(stderr, "%s: Invalid score: %s\n", progname, buffer);
			fclose(fload);
			return false;
		}
		if(verbose)
			printf("%i\n", score);

		if(!update_score(&games, x, score))
		{
			fprintf(stderr, "%s: Could not update score\n", progname);
			fclose(fload);
			return false;
		}

		if(!end_game(&games, x, &highscores, shm_com))
		{
			fprintf(stderr, "%s: Could not read highscore\n", progname);
			fclose(fload);
			return false;
		}
	}

	fclose(fload);

	return true;
}

void saveHighscore(int verbose)
{
	if(fstore != NULL)
	{
		if(verbose)
			printf("Saving highscore...\n");

		fstore = freopen(NULL, "w", fstore); //truncate file

		for(int x=0; x<NUMBER_OF_HIGHSCORES; x++)
		{
			if(highscores.games[x] != NULL)
			{
				fprintf(fstore, "%s\n%u\n", highscores.games[x]->name, highscores.games[x]->score);
			}
			else
				break;
		}

		fflush(fstore);
	}
}

void release_resources()
{
	if(fstore != NULL) {
		fclose(fstore);
	}

	vector_free(&games);

	shmctl(shmid, IPC_RMID, NULL);
}

void release_resources_signal(int signal)
{
	// atexit handler will be called
	exit(EXIT_SUCCESS);
}

int main(int argc,char** argv)
{
	int sock, n;
	int verbose = 0, store = 0;
	bool load = 0;
	char *load_file;
	socklen_t len;
	const int y = 1;
	struct sockaddr_in cliAddr, servAddr;
	char buffer[BUF_SIZE];
	int port = 0;
	highscore_list_shm_t *shm_com;

	atexit(release_resources);
	signal(SIGINT,  release_resources_signal);
	signal(SIGQUIT, release_resources_signal);
	signal(SIGTERM, release_resources_signal);

	vector_init(&games, &highscores);

	if(argc <= 8)
	{
		int opt;
		while((opt = getopt(argc, argv, "vs:l:")) != EOF)
		{
			switch(opt)
			{
				case 'v':
					verbose++;
					break;
				case 's':
					store++;
					fstore = fopen(optarg, "w");
					if(fstore == NULL)
					{
						fprintf(stderr, "%s: Invalid file %s\n", argv[0], optarg);
						usage(argv[0]);
					}
					break;
				case 'l':
					load++;
					load_file = optarg;
					break;
				default:
					usage(argv[0]);
			}
		}
		if((verbose > 1) || (store > 1) || (load > 1))
			usage(argv[0]);
		if(optind < argc)
		{
			port = strtol(argv[optind], NULL, 10);
			if((port < 1024) || (port > 65535))
			{
				fprintf(stderr, "%s: Invalid port\n", argv[0]);
				vector_free(&games);

				if(fstore != NULL)
					fclose(fstore);
				exit(EXIT_FAILURE);
			}
		}
		else
			usage(argv[0]);
	}
	else
	{
		usage(argv[0]);
	}

	if((shmid = shmget(SHM_KEY, sizeof(highscore_list_shm_t), IPC_CREAT | SHM_PERMISSION)) < 0)	// Create shared memory
	{
		fprintf(stderr, "ERROR: Could not create shared memory\n");

		exit(EXIT_FAILURE);
	}

	if((shm_com = (highscore_list_shm_t *)shmat(shmid, NULL, 0)) == (void *)-1)	// Attach to shared memory
	{
		fprintf(stderr, "ERROR: Could not attach to shared memory\n");

		exit(EXIT_FAILURE);
	}

	if(load && !loadHighscore(argv[0], load_file, verbose, shm_com))
	{
		fprintf(stderr, "ERROR: Could not load highscores\n");

		exit(EXIT_FAILURE);
	}

	sock = socket(AF_INET, SOCK_DGRAM, 0);
	if(sock < 0)
	{
		fprintf(stderr, "ERROR: Could not open socket ... (%s)\n", strerror(errno));

		exit(EXIT_FAILURE);
	}

	servAddr.sin_family = AF_INET;
	servAddr.sin_addr.s_addr = htonl(INADDR_ANY);
	servAddr.sin_port = htons(port);
	setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &y, sizeof(int));
	n = bind(sock, (struct sockaddr *)&servAddr, sizeof(servAddr));
	if(n < 0)
	{
		fprintf(stderr, "ERROR: Could not bind to port ... (%s)\n", strerror(errno));

		exit(EXIT_SUCCESS);
	}

	printf("Waiting for messages from client...\n");

	char *ptr;

	while(true)
	{
		memset(buffer, 0, BUF_SIZE);

		len = sizeof(cliAddr);

		if(verbose)
			printf("\n");

		n = recvfrom(sock, buffer, BUF_SIZE, 0, (struct sockaddr *)&cliAddr, &len);
		if(n < 0)
		{
			fprintf(stderr, "ERROR: Cannot receive data\n");
			continue;
		}

        ptr = buffer;

		if(verbose)
			printf("Rest: %s\n", ptr);

		if(strncmp(ptr, "start game", 10) == 0)
		{
			int x = new_game(&games);
			if(verbose)
				printf("OK, New game number: %i\n", x);

			sprintf(buffer, "ok: gameid %i", x);
			sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
		}
		else if(strncmp(ptr, "set name", 8) == 0)
		{
			char *endptr;
			int index = strtol(&ptr[9], &endptr, 10);
			if(index == 0 && endptr == &ptr[9])
			{
				printf("Set name: invalid index\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));

				continue;
			}

			if((*endptr != 0) && update_name(&games, index, endptr+1))
			{
				game_info_t *game = vector_get(&games, index);
				if(verbose)
					printf("OK, new name: %s\n", game->name);

				sprintf(buffer, "ok");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
			else
			{
				printf("Set name: invalid argument\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
		}
		else if(strncmp(ptr, "update score", 12) == 0)
		{
			char *endptr, *endptr2;
			int index = strtol(&ptr[13], &endptr, 10);
			if(index == 0 && endptr == &ptr[13])
			{
				printf("Update score: invalid index\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));

				continue;
			}
			uint32_t score = strtol(endptr, &endptr2, 10);
			if(score == 0 && endptr2 == endptr)
			{
				printf("Update score: invalid score\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));

				continue;
			}

			if(update_score(&games, index, score))
			{
				game_info_t *game = vector_get(&games, index);
				if(verbose)
					printf("OK, new score: %u\n", game->score);

				sprintf(buffer, "ok");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
			else
			{
				printf("Update score: invalid argument\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
		}
		else if(strncmp(ptr, "end game", 8) == 0)
		{
			char *endptr;
			int index = strtol(&ptr[9], &endptr, 10);
			if(index == 0 && endptr == &ptr[9])
			{
				printf("End game: invalid index\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));

				continue;
			}

			if(end_game(&games, index, &highscores, shm_com))
			{
				if(verbose)
					printf("OK\n");

				saveHighscore(verbose);

				sprintf(buffer, "ok");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
			else
			{
				printf("End game: invalid argument\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
		}
		else if(strncmp(ptr, "get highscore", 13) == 0)
		{
			bool sent = false;
			printf("Highscores: \n");

			for(int x=0; x<NUMBER_OF_HIGHSCORES; x++)
			{
				if(highscores.games[x] != NULL)
				{
					sprintf(buffer, "%i: %s - %u", x, highscores.games[x]->name, highscores.games[x]->score);
					printf("%s\n", buffer);

					sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
					sent = true;
				}
				else
					break;
			}

			if(!sent)
			{
				printf("Get highscores: no highscore available\n");

				sprintf(buffer, "err");
				sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
			}
		}
		else if(strncmp(ptr, "ping", 4) == 0)
		{
			if(verbose)
				printf("pong\n");

			sprintf(buffer, "pong");
			sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
		}
		else
		{
			printf("Received incorrect command: %s\n", ptr);

			sprintf(buffer, "err");
			sendto(sock, buffer, strlen(buffer), 0, (struct sockaddr *)&cliAddr, sizeof(cliAddr));
		}
	}

	exit(EXIT_SUCCESS);
}
