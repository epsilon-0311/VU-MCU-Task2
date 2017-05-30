configuration TerrainGeneratorC{
    provides interface TerrainGenerator;
}
implementation{
    components TerrainGeneratorP;
    components RandomC;
    
    TerrainGenerator = TerrainGeneratorP;
    
    TerrainGenerator.Random -> RandomC.Random;
}