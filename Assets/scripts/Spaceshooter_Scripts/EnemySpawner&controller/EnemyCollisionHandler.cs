using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyCollisionHandler : MonoBehaviour
{
    private PlayerScore Ps;
    private bool isDestroyed = false; // Track if the Enemy is destroyed
    private Animator animator; // Reference to the Animator component
    private spaceShooterGameContoller ssGameController;
    public AudioClip ExplosionSound;
    private AudioSource audioSource;
    
   

    void Start()
    {
        audioSource = GetComponent<AudioSource>();
        Ps = FindObjectOfType<PlayerScore>();
        animator = GetComponent<Animator>();
        ssGameController=FindObjectOfType<spaceShooterGameContoller>();
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        // Check the other object is tagged as a laser
        if (other.CompareTag("Laser")  && !isDestroyed)
        {
            spaceShooterGameContoller.Instance.nSuccess++;
            spaceShooterGameContoller.Instance.setisSuccess();
            animator.SetTrigger("TriggerExplosion"); // Play destruction animation
            if (audioSource != null && ExplosionSound != null)
            {
                audioSource.PlayOneShot(ExplosionSound);
            }
            isDestroyed = true; // Mark enemy as destroyed
            Destroy(other.gameObject);
            // randomfall = Random.Range(1, 100);
            // if (randomfall < 20)
            // {
            //     Instantiate(Powerup_Shield, other.transform.position, other.transform.rotation);
            // }
        }
       
    }
    
    public void DestroyEnemy()
    {
        gameObject.SetActive(false);
        Destroy(gameObject);// Destroy the enemy
        // Add score after ensuring destruction
        Ps.AddScore();
    }
}
