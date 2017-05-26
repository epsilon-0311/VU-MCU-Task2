/**
 * @author:	Markus Hartmann <e9808811@student.tuwien.ac.at>
 * @date:	31.07.2012
 */

interface MP3
{
	/**
	 * Start and stop sine test
	 *
	 * @param on TRUE to start - FALSE to stop
	 *
	 * @return SUCCESS if command was successfully sent over SPI
	 */	
	command error_t sineTest( bool on );


	/**
	 * Set volume
	 *
	 * @param volume Volume to be set
	 *
	 * @return SUCCESS if command was successfully sent over SPI
	 */	
	command error_t setVolume( uint8_t volume );

	/**
	 * Send data
	 *
	 * @param data A point to a data buffer where the data is stored
	 * @param len Length of the message to be sent - data must be at least as large as len
	 *
	 * @return SUCCESS if request was granted and sending the data started
	 */	
	command error_t sendData( uint8_t *data, uint8_t len );

	/**
	 * Notification that sending data completed
	 *
	 * @param error SUCCESS if sending completed successfully
	 */
	event void sendDone( error_t error );

	/**
	 * Check if VS1011e is ready to accept new data
	 *
	 * @return FALSE if VS1011e is busy or sending of data is in progress - otherwise TRUE
	 */	
	command bool isBusy( void );
}
