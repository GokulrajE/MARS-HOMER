using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DestroyOffScreen : MonoBehaviour
{
    public float yThreshold = -5.3f; // Y-position threshold for destroying the asteroid
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
            spaceShooterGameContoller.Instance.setisFailure();
            spaceShooterGameContoller.Instance.nFailure++;
            gameObject.SetActive(false);
            Destroy(gameObject);
        }

    }
}
