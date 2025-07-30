using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FinalBossCollisionHandlerScript : MonoBehaviour
{
    public int hitsRequired = 50; // Number of hits required to destroy the enemy
    private int currentHits = 0; // Tracks the current number of hits
    public AudioClip ExplosionSound;

    private AudioSource audioSource;
    private PlayerScore Ps;
    private bool isDestroyed = false; // Track if the Enemy is destroyed
    private Animator animator; // Reference to the Animator component
    private spaceShooterGameContoller gm;

    public Image healthBarFill; // Reference to the health bar fill image

    void Start()
    {
        audioSource = GetComponent<AudioSource>();
        Ps = FindObjectOfType<PlayerScore>();
        animator = GetComponent<Animator>();
        gm = FindObjectOfType<spaceShooterGameContoller>();

        // Ensure the health bar is fully filled at the start
        if (healthBarFill != null)
        {
            healthBarFill.fillAmount = 1.0f;
        }
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        // Check if the collider is the player's laser
        if (other.CompareTag("Laser") && !isDestroyed)
        {
            // Increment the hit counter
            currentHits++;

            // Destroy the laser
            Destroy(other.gameObject);

            // Update the health bar
            UpdateHealthBar();

            // Check if the enemy should be destroyed
            if (currentHits >= hitsRequired)
            {
                isDestroyed = true; // Mark enemy as destroyed
                animator.SetTrigger("TriggerExplosion"); // Play destruction animation
                if (audioSource != null && ExplosionSound != null)
                {
                    audioSource.PlayOneShot(ExplosionSound);
                }
                // Delay the destruction to allow the animation to finish
                StartCoroutine(waitforAnimation());
            }
        }
    }

    void UpdateHealthBar()
    {
        if (healthBarFill != null)
        {
            // Calculate the current health percentage and update the health bar fill
            healthBarFill.fillAmount = 1.0f - (float)currentHits / hitsRequired;
        }
    }

    IEnumerator waitforAnimation()
    {
        // Wait for the explosion animation duration
        yield return new WaitForSeconds(2);

        DestroyEnemy();
    }

    void DestroyEnemy()
    {
        // Destroy the enemy object
        Destroy(gameObject);
        Ps.AddScore();
    }
}
