using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FinalBossBullet : MonoBehaviour
{
    [SerializeField]
    private GameObject Enemy_bullet;


    public AudioClip laserSound;
    private AudioSource audioSource;

    [SerializeField]
    private Transform Spawn_point1;
    [SerializeField]
    private Transform Spawn_point2;
    [SerializeField]
    private Transform Spawn_point3;
   

    public float ShootInterval = 2.5f;
    private float timeSinceLastShot = 0f;  // Timer to track intervals between shots

    private spaceShooterGameContoller gm;
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
        GameObject Laser = Instantiate(Enemy_bullet, Spawn_point1.position, Quaternion.identity);
        GameObject Laser2=Instantiate(Enemy_bullet, Spawn_point2.position, Quaternion.identity);
        GameObject Laser3=Instantiate(Enemy_bullet, Spawn_point3.position, Quaternion.identity);

        // Destroy laser after 5 seconds to prevent clutter
        if (audioSource != null && laserSound != null)
        {
            audioSource.PlayOneShot(laserSound);
        }
        Destroy(Laser, 2.5f);
        Destroy(Laser2, 2.5f);
        Destroy(Laser3, 2.5f);

    }
}
