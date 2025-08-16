
using System.Collections;
using System.Collections.Generic;
using System.Data;
using UnityEngine;
using UnityEngine.Rendering;
using static AppData;

public class Player_controller_s : MonoBehaviour
{
    // Start is called before the first frame update
    Camera mainCamera;
    private Vector2 screenBounds;

    // Start is called before the first frame update
    public float speed = 4f;

    [SerializeField]
    private GameObject Player_bullet;

    public AudioClip laserSound;
    private AudioSource audioSource;

    [SerializeField]
    private Transform Spawn_point;
    public int[] DEPENDENT = new int[] { 0, -1, 1 };

    public static float xMin, yMin, xMax, yMax;

    public float ShootInterval = 10f;
    private float timeSinceLastShot = 0f;  // Timer to track intervals between shots
  
    float th1, th2, th3, yEndPoint, zEndPoing;
    float xPoint, yPoint;
    public float tilt;
    public float[] currRom;

    //default values
    public static float yMinMars = 175;
    public static float yMaxMars = 775;
    public static float zMinMars = 291 - 300;
    public static float zMaxMars = 291 + 300;
 
    Vector3 temp;
    void Start()
    {
        mainCamera = Camera.main;
        screenBounds = mainCamera.ScreenToWorldPoint(new Vector3(Screen.width, Screen.height, mainCamera.transform.position.z));
        xMin = -0.9f * screenBounds.x;
        xMax = 0.9f * screenBounds.x;
        yMin = -screenBounds.y + 0.2f;//change into 1 from 4
        yMax = screenBounds.y - screenBounds.y / 1.5f;
        audioSource = GetComponent<AudioSource>();
        
        //GET ROM DATA
        currRom = AppData.Instance.selectedMovement.CurrentAromFWS;
        zMinMars = currRom[0] * 1000;
        zMaxMars = currRom[1] * 1000;
        yMinMars = currRom[2] * 1000;
        yMaxMars = currRom[3] * 1000;

    }
   
    public void FixedUpdate()
    {
        //need to check for dynamic limbchange
        th1 = MarsComm.OFFSET[AppData.Instance.userData.useHand] * MarsComm.angle1;
        th2 = MarsComm.OFFSET[AppData.Instance.userData.useHand] * MarsComm.angle2;
        th3 = MarsComm.OFFSET[AppData.Instance.userData.useHand] * MarsComm.angle3;
        yEndPoint = Mathf.Sin(th1) * (475.0f * Mathf.Cos(th2) + 291.0f * Mathf.Cos(th2 + th3));
        zEndPoing = (-475.0f * Mathf.Sin(th2) - 291.0f * Mathf.Sin(th2 + th3));
        xPoint = -((xMin + xMax) / 2.0f + (xMax - xMin) / (zMaxMars - zMinMars) * (zEndPoing - ((zMinMars + zMaxMars) / 2.0f)));
        yPoint = ((yMin + yMax) / 2.0f - (yMax - yMin) / (yMaxMars - yMinMars) * (yEndPoint - ((yMinMars + yMaxMars) / 2.0f)));

        transform.position = new Vector3(Mathf.Clamp(xPoint, xMin, xMax),
            Mathf.Clamp(yPoint, yMin, yMax),
            -8.0f);

        //Initiate Bullet
        shootTime();
       
    }
 
    void shootTime()
    {
       
        if (spaceShooterGameContoller.Instance == null 
            || spaceShooterGameContoller.Instance.isGameFinished
            || !spaceShooterGameContoller.Instance.isGameStarted
            )
        {
           
            return; // Stop shooting when the game is over

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
        GameObject Laser = Instantiate(Player_bullet, Spawn_point.position, Quaternion.identity);
        // Destroy laser after 5 seconds to prevent clutter
        if (audioSource != null && laserSound != null)
        {
            audioSource.PlayOneShot(laserSound);
        }
        Destroy(Laser, 3.5f);
    }
    public void DestroyPlayer()
    {
        Destroy(gameObject);
    }
   
}
