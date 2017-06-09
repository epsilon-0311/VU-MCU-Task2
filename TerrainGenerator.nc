interface TerrainGenerator{
    
    // IOs initialisieren, IRQ aktivieren
    command void startTerrainGenerator(void);
    
    command uint8_t* getTerrain(void); 
    
    event void terrainGenerated(uint8_t*);
}