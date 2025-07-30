using System.Collections;
using System.Collections.Generic;
using System.Threading;
using UnityEditor;
using UnityEngine;

public class AsteroidSpawner : MonoBehaviour
{
    public static AsteroidSpawner Instance;
    public GameObject asteroidPrefab;
    public Transform spawnArea;

    // public float spawnInterval = 5f;
    public float minX = -8f;
    public float maxX = 8f;
    public float spawnY = 6f;
 
    // private float timer_r = 5;
    public GameObject currentAsteroid;
    private void Awake()
    {
        Instance = this;
    }
    void Start()
    {
        
        
    }

    void Update()
    {
       
    }
    private void FixedUpdate()
    {
        
    }

    public void SpawnAsteroid()
    {
        if (currentAsteroid != null)
        {
            return;
        }
          
           
        // Generate a random X position within specified bounds
        float randomX = Random.Range(minX, maxX);

        // Create a spawn position
        Vector3 spawnPosition = new Vector3(randomX, spawnY, 0f);

        // Instantiate the asteroid prefab 
        currentAsteroid=Instantiate(asteroidPrefab, spawnPosition, Quaternion.identity);
      
    }
}
