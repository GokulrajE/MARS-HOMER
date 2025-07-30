using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Scripting.APIUpdating;

public class BulletScript : MonoBehaviour
{
    // Start is called before the first frame update
    public float speed = 6f;
    private spaceShooterGameContoller gm;
    private bool isDestroyed = false;
    void Start()
    {
        gm = FindObjectOfType<spaceShooterGameContoller>();
    }

    // Update is called once per frame
    void Update()
    {
        Move();
    }
    void Move()
    {
        if (gm != null && gm.isGameFinished)
        {
            return; // Stop spawning when the game is over

        }
        Vector3 temp = transform.position;
        temp.y += speed * Time.deltaTime;
        transform.position = temp;
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        //if (other.CompareTag("EnemyLaser") && !isDestroyed)
        //{
        //    isDestroyed = true;
        //    Destroy(gameObject);
        //    Destroy(other.gameObject);

        //}
    }
}
