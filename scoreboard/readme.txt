====================================
= author:	Bernhard Petschina
= date:		15.05.2015
====================================

== Scoreboard for app2 ==

This program is the scoreboard for the second application.

Before you can use it you have to compile it with "make"; after that you can
start the program:
$ make
$ ./scoreboard [-v] [-i] [-l file_to_load] [-s file_to_store] PORT

i.e. ./scoreboard 50000
or   ./scoreboard -vi -l load.txt -s store.txt 50000

OPTIONS
	-v
		Verbose mode.
		In this mode the program prints more messages about
		the commands. This may be useful for debugging.

	-s file_to_store
		Save highscore
		With this option you can save the current highscore to a file.

	-l file_to_load
		Load Highscore
		With this option you can reload a previously saved highscore.


The second program, "highscores" can be used to watch the highscores in
real-time, i.e., the list of finished games as they are completed.
You can start it by executing
$ ./highscores

Please note that you have to start the scoreboard before starting highscores!
