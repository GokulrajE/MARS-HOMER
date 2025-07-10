using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class Player_collision_handler : MonoBehaviour
{
    private Animator animator;
    private bool isDestroyed = false; // To ensure animation plays only once
    private GameManagerScript gameManager;
    public AudioClip ExplosionSound;
    private AudioSource audioSource;
    private PlayerScore ps;
    public float blinkDuration = 2f; // Duration for blinking effect
    public float blinkInterval = 0.1f; // Time between blinks
    private bool isBlinking = false;
    private Renderer playerRenderer;
    
      
   
    void Start()
    {
        audioSource = GetComponent<AudioSource>();
        animator = GetComponent<Animator>();
        gameManager = FindObjectOfType<GameManagerScript>();
        ps=FindObjectOfType<PlayerScore>();
        playerRenderer = GetComponent<Renderer>();
        
        
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        // Check if the player is hit by an asteroid
        if ((other.CompareTag("Asteroid") && !isDestroyed)||(other.CompareTag("Enemy")&&!isDestroyed)||(other.CompareTag("EnemyLaser")&&!isDestroyed))//check if any asteroid or enemy hit the player 
        {
            //Trigger the explosion animation,
            animator.SetTrigger("TriggerExplosion");
            if (audioSource != null && ExplosionSound != null)
            {
                audioSource.PlayOneShot(ExplosionSound);
            }
            StartCoroutine(Blink());
            ps.DeductScore();
            //gameData.events = 2;
            Debug.Log("enemy hit or astroid it");
            // destroy the player GameObject after the animation 
            isDestroyed = true;

            gameManager.GameOver(); // Trigger game over
            //  destroy  the asteroid
            Destroy(other.gameObject);
        }
       
    }
     IEnumerator Blink()
    {
        isBlinking = true;
        float endTime = Time.time + blinkDuration;

        while (Time.time < endTime)
        {
            // Toggle visibility
            playerRenderer.enabled = !playerRenderer.enabled;
            yield return new WaitForSeconds(blinkInterval);
        }

        // Ensure visibility is restored
        playerRenderer.enabled = true;
        isBlinking = false;
    }
    
}
