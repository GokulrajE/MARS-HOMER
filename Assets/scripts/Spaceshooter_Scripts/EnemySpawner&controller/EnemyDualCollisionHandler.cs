using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyDualCollisionHandler : MonoBehaviour
{
    // Start is called before the first frame update
    public int hitsRequired = 2; // Number of hits required to destroy the enemy
    private int currentHits = 0; // Tracks the current number of hits
    public AudioClip ExplosionSound;

    private AudioSource audioSource;
    private PlayerScore Ps;
    private bool isDestroyed = false; // Track if the Enemy is destroyed
    private Animator animator; // Reference to the Animator component
    private spaceShooterGameContoller gm;
    // public Transform Powerup_Shield; field for powerup prefab shield
    
    private int randomfall;
    

    void Start()
    {
        audioSource = GetComponent<AudioSource>();
        Ps = FindObjectOfType<PlayerScore>();
        animator = GetComponent<Animator>();
        gm=FindObjectOfType<spaceShooterGameContoller>();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    void OnTriggerEnter2D(Collider2D other)
    {
        // Check if the collider is the player's laser
        if (other.CompareTag("Laser")  && !isDestroyed)
        {
            // Increment the hit counter
            currentHits++;

            // Destroy the laser
            Destroy(other.gameObject);

            // Check if the enemy should be destroyed
            if (currentHits >= hitsRequired)
            {
              
            isDestroyed = true; // Mark enemy as destroyed
            animator.SetTrigger("TriggerExplosion"); // Play destruction animation
            if (audioSource != null && ExplosionSound != null)
            {
                audioSource.PlayOneShot(ExplosionSound);
            }
            
            //randomly drop powerup shield prefab when hit by player laser
            // randomfall = Random.Range(1, 100);
            // if (randomfall < 40)
            // {
            //     Instantiate(Powerup_Shield, other.transform.position, other.transform.rotation);
            // }
             // Delay the destruction to allow the animation to finish
                StartCoroutine(waitforAnimation());
            }
        }
    }

    void DestroyEnemy()
    {
        // Destroy the enemy object
        Destroy(gameObject);
        Ps.AddScore();
    }
    IEnumerator waitforAnimation()
    {
        // Wait for the explosion animation duration
        
        yield return new WaitForSeconds(2);

       
    }
}
