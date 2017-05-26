interface Score
{
	/**
	 * Signal the scoreboard that a new game has started
	 * @param The name of the player
	 */
	command void startGame(char* name);
	
	/**
	 * Send a new score to the scoreboard
	 * @param The new score
	 */
	command void sendScore(uint32_t score);
	
	/**
	 * Signal the scoreboard that the game has ended
	 * @param The final score
	 */
	command void gameOver(uint32_t score);
}
