using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AsteroidCollisionHandler : MonoBehaviour
{
    private PlayerScore ps;
    private bool isDestroyed = false; // Track if the asteroid is destroyed
    private Animator animator; // Reference to the Animator component
    public AudioClip ExplosionSound;
    private AudioSource audioSource;

    void Start()
    {
        ps = FindObjectOfType<PlayerScore>();
        animator = GetComponent<Animator>();
        audioSource = GetComponent<AudioSource>();
    }

    void OnTriggerEnter2D(Collider2D other)
    {

        // Check the other object is tagged as a laser
        if (other.CompareTag("Laser") && !isDestroyed)
        {
            AsteroidSpawner.Instance.currentAsteroid = null;
            spaceShooterGameContoller.Instance.nSuccess++;
            spaceShooterGameContoller.Instance.setisSuccess();
            isDestroyed = true; // Mark asteroid as destroyed
            animator.SetTrigger("TriggerDestroy"); // Play destruction animation
             if (audioSource != null && ExplosionSound != null)
            {
                audioSource.PlayOneShot(ExplosionSound);
            }

            Destroy(other.gameObject); // Destroy the laser
        }
    }


    public void DestroyAsteroid()
    {
        gameObject.SetActive(false);
        Destroy(gameObject);// Destroy the asteroid
        // Add score after ensuring destruction
      
        ps.AsteroidScore();
    }
}
