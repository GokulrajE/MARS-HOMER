using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyDestroyOffScreen : MonoBehaviour
{
    // Start is called before the first frame update
    public float yThreshold = -6f; // Y-position threshold for destroying the Enemy object when moves out of the camera view
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
        // Check if the asteroid has fallen below the specified threshold
        if (transform.position.y <= yThreshold)
        {
            spaceShooterGameContoller.Instance.nFailure++;
            gameObject.SetActive(false);
            Destroy(gameObject);
        }

    }
}
