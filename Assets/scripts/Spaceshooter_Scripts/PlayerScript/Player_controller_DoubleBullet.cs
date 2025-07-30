using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Player_controller_DoubleBullet : MonoBehaviour
{
    public float speed = 4f;
    public float min_x, max_x, min_y, max_y;
    [SerializeField]
    private GameObject Player_bullet;

    public AudioClip laserSound;
    private AudioSource audioSource;

    [SerializeField]
    // private Transform Spawn_point;
    public Transform spawnPoint1;  // First spawn point for the bullet
    public Transform spawnPoint2;  // Second spawn point for the bullet

    public float ShootInterval = 2f; // Time between sets of bullets
    private float timeSinceLastShot = 0f; // Timer to track intervals between shots
    public float doubleBulletInterval = 0.2f; // Time between two bullets in a single attack

    private spaceShooterGameContoller gm;

    void Start()
    {
        audioSource = GetComponent<AudioSource>();
        gm = FindObjectOfType<spaceShooterGameContoller>();
    }

    void Update()
    {
        //MovePlayer();
        Shoot_time();
    }

    void MovePlayer()
    {
        if (gm != null && gm.isGameFinished)
        {
            return; // Stop movement when the game is over
        }
        if (Input.GetAxisRaw("Horizontal") > 0f)
        {
            Vector3 temp = transform.position;
            temp.x += speed * Time.deltaTime;

            if (temp.x > max_x)
                temp.x = max_x;
            transform.position = temp;

        }
        else if (Input.GetAxisRaw("Horizontal") < 0f)
        {
            Vector3 temp = transform.position;
            temp.x -= speed * Time.deltaTime;

            if (temp.x < min_x)
                temp.x = min_x;
            transform.position = temp;
        }
        if (Input.GetAxisRaw("Vertical") > 0f)
        {
            Vector3 temp = transform.position;
            temp.y += speed * Time.deltaTime;

            if (temp.y > max_y)
                temp.y = max_y;
            transform.position = temp;
        }
        else if (Input.GetAxisRaw("Vertical") < 0f)
        {
            Vector3 temp = transform.position;
            temp.y -= speed * Time.deltaTime;

            if (temp.y < min_y)
                temp.y = min_y;
            transform.position = temp;
        }
    }

    void Shoot_time()
    {
        if (gm != null && gm.isGameFinished)
        {
            return; // Stop shooting when the game is over
        }
        // Track time passed
        timeSinceLastShot += Time.deltaTime;

        // Check if it's time to shoot
        if (timeSinceLastShot >= ShootInterval)
        {
            StartCoroutine(DoubleBulletAttack());
            timeSinceLastShot = 0f; // Reset timer after shooting
        }
    }

    IEnumerator DoubleBulletAttack()
    {
        // Spawn the first bullet
        SpawnBullet();

        // Wait for a short interval before spawning the second bullet
        yield return new WaitForSeconds(doubleBulletInterval);

        // Spawn the second bullet
        SpawnBullet1();
    }

    void SpawnBullet()
    {
        GameObject Laser = Instantiate(Player_bullet, spawnPoint1.position, Quaternion.identity);
        // Destroy laser after 3.5 seconds to prevent clutter
        Destroy(Laser, 3.5f);

        // Play laser sound
        if (audioSource != null && laserSound != null)
        {
            audioSource.PlayOneShot(laserSound);
        }
    }
    void SpawnBullet1(){
       GameObject Laser = Instantiate(Player_bullet, spawnPoint2.position, Quaternion.identity);
        // Destroy laser after 3.5 seconds to prevent clutter
        Destroy(Laser, 3.5f);

        // Play laser sound
        if (audioSource != null && laserSound != null)
        {
            audioSource.PlayOneShot(laserSound);
        } 
    }

    public void DestroyPlayer()
    {
        Destroy(gameObject);
    }
}
