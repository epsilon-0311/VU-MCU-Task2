#include "LunarLander.h"

module TerrainGeneratorP{
    provides interface TerrainGenerator;
    uses interface Random;
}
implementation{
    
    task void generateTerrain(void);
    
    uint8_t terrainSeed[TERRAIN_POINTS+1];
    uint8_t counter = 0;
    uint8_t flat_spot =0;
    uint8_t flat_hight=0;
    
    command void TerrainGenerator.startTerrainGenerator(void){
        flat_spot = call Random.rand16()%TERRAIN_POINTS;
        flat_hight= call Random.rand16()%MAXIMUM_HEIGHT_PLAIN;
        
    
        post generateTerrain();
    }
        
    task void generateTerrain(void){
        
        
        if(counter!= flat_spot && counter!= flat_spot+1){
            terrainSeed[counter] = (call Random.rand16()) %MAXIMUM_HEIGHT;
        }else{
            terrainSeed[counter] =flat_hight;
        }
        
        counter++;
        
        if(counter >= TERRAIN_POINTS){
            signal TerrainGenerator.terrainGenerated(terrainSeed);
        }else{
            post generateTerrain(); 
        }
        
    }
    
    command uint8_t* TerrainGenerator.getTerrain(void){
        return terrainSeed;
        
    }
}