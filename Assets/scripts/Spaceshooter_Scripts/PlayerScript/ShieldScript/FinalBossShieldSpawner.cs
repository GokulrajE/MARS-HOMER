using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FinalBossShieldSpawner : MonoBehaviour
{
    public Transform ShieldPrefab;
    public Transform spawnArea;
    public float spawnInterval = 20f;
    public float minX = -8f;
    public float maxX = 8f;
    public float spawnY = 4f;
    private spaceShooterGameContoller gameManager;
    private float timer_r = 10;
    void Start()
    {
        gameManager = FindObjectOfType<spaceShooterGameContoller>();
    }

    void Update()
    {
        if (gameManager != null && gameManager.isGameFinished)
        {
            return; // Stop spawning when the game is over

        }
        timer_r += Time.deltaTime;
        // Debug.Log(timer_r);
        if (timer_r >= spawnInterval)
        {
            SpawnAsteroid();
            timer_r = 0;

        }

    }

    void SpawnAsteroid()
    {
        // Generate a random X position within specified bounds
        float randomX = Random.Range(minX, maxX);

        // Create a spawn position
        Vector3 spawnPosition = new Vector3(randomX, spawnY, 0f);

        // Instantiate the asteroid prefab 
        Instantiate(ShieldPrefab, spawnPosition, Quaternion.identity);
    }
}
