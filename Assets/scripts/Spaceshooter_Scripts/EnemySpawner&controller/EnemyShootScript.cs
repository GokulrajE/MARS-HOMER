using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyShootScript : MonoBehaviour
{
    [SerializeField]
    private GameObject Enemy_bullet;


    public AudioClip laserSound;
    private AudioSource audioSource;

    [SerializeField]
    private Transform Spawn_point;


    public float ShootInterval = 1.5f;
    private float timeSinceLastShot = 1f;  // Timer to track intervals between shots

    private spaceShooterGameContoller gm;

    // Start is called before the first frame update
    void Start()
    {
        gm = FindObjectOfType<spaceShooterGameContoller>();
        audioSource = GetComponent<AudioSource>();

    }

    // Update is called once per frame
    void Update()
    {
        Shoot_time();

    }

    void Shoot_time()
    {
        if (gm != null && gm.isGameFinished)
        {
            return; // Stop spawning when the game is over

        }
        // Track time passed
        timeSinceLastShot += Time.deltaTime;


        // Check if it's time to shoot
        if (timeSinceLastShot >= ShootInterval)
        {
            Attack();
            timeSinceLastShot = 0f;  // Reset timer after shooting
        }
    }
    void Attack()
    {
        GameObject Laser = Instantiate(Enemy_bullet, Spawn_point.position, Quaternion.identity);
        // Destroy laser after 5 seconds to prevent clutter
        if (audioSource != null && laserSound != null)
        {
            audioSource.PlayOneShot(laserSound);
        }
        Destroy(Laser, 3.5f);
    }
}
