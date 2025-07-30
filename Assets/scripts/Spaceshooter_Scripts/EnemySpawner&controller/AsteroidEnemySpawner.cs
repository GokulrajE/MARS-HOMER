using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AsteroidEnemySpawner : MonoBehaviour
{
    public GameObject[] asteroids; // Array of asteroid prefabs
    public GameObject[] enemies;   // Array of enemy prefabs

    // public float spawnInterval = 7f; // Interval between spawns
    public float minX = -8f;         // Minimum X position for spawning
    public float maxX = 8f;          // Maximum X position for spawning
    public float spawnHeight = 6f;

    public bool[] spawnSequence; // Sequence of spawns: true for asteroid, false for enemy

    private GameObject currentSpawnedObject;
    private spaceShooterGameContoller ssGameContoller;
    

    private int sequenceIndex = 0; // Current index in the spawn sequence

    
    void Start()
    {
       
        SpawnObject(); // Start spawning
    }

    void Update()
    {
        if (ssGameContoller != null && ssGameContoller.isGameFinished)
        {
            return; // Stop spawning when the game is over
        }
        // timer_r += Time.deltaTime;
        // // Debug.Log(timer_r);
        // if (timer_r >= spawnInterval)
        if (currentSpawnedObject== null)
        {
           
            // SpawnAsteroid();
            SpawnObject();
            // timer_r = 0;

        }
    }

    void SpawnObject()
    {
       
        GameObject prefabToSpawn;

        // Determine whether to spawn an asteroid or an enemy based on the sequence
        if (spawnSequence[sequenceIndex])
        {
            // Pick a random asteroid from the array
            prefabToSpawn = asteroids[Random.Range(0, asteroids.Length)];
        }
        else
        {
            // Pick a random enemy from the array
            prefabToSpawn = enemies[Random.Range(0, enemies.Length)];
        }

        // Advance to the next index in the sequence
        sequenceIndex = (sequenceIndex + 1) % spawnSequence.Length;

        // Generate a random X position within the screen boundaries, keeping Y fixed
        Vector3 spawnPosition = new Vector3(Random.Range(minX, maxX), spawnHeight, 0);

        // Spawn the object and keep a reference to it
        currentSpawnedObject = Instantiate(prefabToSpawn, spawnPosition, Quaternion.identity);
    }
}
