using NeuroRehabLibrary;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using UnityEngine;
using static AppData;

public class Player_controller_s : MonoBehaviour
{
    // Start is called before the first frame update
    Camera mainCamera;
    private Vector2 screenBounds;

    // Start is called before the first frame update
    public float speed = 4f;
    public float min_x, max_x, min_y, max_y;
    [SerializeField]
    private GameObject Player_bullet;

    public AudioClip laserSound;
    private AudioSource audioSource;

    [SerializeField]
    private Transform Spawn_point;
    public int[] DEPENDENT = new int[] { 0, -1, 1 };
    public static float xMin, yMin, xMax, yMax;
    public float threshold;
    public float ShootInterval = 2f;
    private float timeSinceLastShot = 0f;  // Timer to track intervals between shots
    private GameManagerScript gm;
    float th1, th2, th3, yMARS, zMARS;
    float xSS, ySS,previosXss;
    public float tilt;
    public DataTable dTableAssessment;
    public static float yMinMars = 175;
    public static float yMaxMars = 775;
    public static float zMinMars = 291 - 300;
    public static float zMaxMars = 291 + 300;
    public static new Vector3 playerPos;
    Vector3 temp;
    public string maxx = "Max_x", minx = "Min_x", maxy = "Max_y", miny = "Min_y";
    void Start()
    {
        mainCamera = Camera.main;
        screenBounds = mainCamera.ScreenToWorldPoint(new Vector3(Screen.width, Screen.height, mainCamera.transform.position.z));
        xMin = -0.9f * screenBounds.x;
        xMax = 0.9f * screenBounds.x;//changed into x from y
        yMin = -screenBounds.y / 1 + 0.2f;//change into 1 from 4
        yMax = screenBounds.y - screenBounds.y / 1.5f;
        //threshold = MarsComm.OFFSET[AppData.useHand];
        getAssessmentData();
        audioSource = GetComponent<AudioSource>();
        gm = FindObjectOfType<GameManagerScript>();
    }
    public  void getAssessmentData()
    {
        Debug.Log(DataManager.directoryAssessmentData);
        dTableAssessment = DataManager.loadCSV($"{DataManager.directoryAssessmentData}/{DataManager.ROMWithSupportFileNames[1]}");
        DataRow lastRow = dTableAssessment.Rows[dTableAssessment.Rows.Count - 1];
        zMinMars = float.Parse((lastRow.Field<string>(minx)));
        zMaxMars = float.Parse((lastRow.Field<string>(maxx)));
        yMinMars = float.Parse((lastRow.Field<string>(miny)));
        yMaxMars = float.Parse((lastRow.Field<string>(maxy)));
        Debug.Log(zMaxMars + "," + zMaxMars + "," + yMaxMars + "," + yMinMars + "possistion Rom");
        Debug.Log("working");
    }
    public void FixedUpdate()
    {
        
        th1 = MarsComm.OFFSET[AppData.Instance.userData.useHand] * MarsComm.angleOne;
        th2 = MarsComm.OFFSET[AppData.Instance.userData.useHand] * MarsComm.angleTwo;
        th3 = MarsComm.OFFSET[AppData.Instance.userData.useHand] * MarsComm.angleThree;
        yMARS = Mathf.Sin(th1) * (475.0f * Mathf.Cos(th2) + 291.0f * Mathf.Cos(th2 + th3));
        zMARS = (-475.0f * Mathf.Sin(th2) - 291.0f * Mathf.Sin(th2 + th3));
        xSS = DEPENDENT[AppData.Instance.userData.useHand] * -((xMin + xMax) / 2.0f + (xMax - xMin) / (zMaxMars - zMinMars) * (zMARS - ((zMinMars + zMaxMars) / 2.0f)));
        ySS = ((yMin + yMax) / 2.0f - (yMax - yMin) / (yMaxMars - yMinMars) * (yMARS - ((yMinMars + yMaxMars) / 2.0f)));
        transform.position = new Vector3(Mathf.Clamp(xSS, xMin, xMax),
            Mathf.Clamp(ySS, yMin, yMax),
            -8.0f);
        playerPos = transform.position;
        Debug.Log(playerPos+"playerpos");
        
        if (xSS != previosXss)
        {
            gameData.events = 1;
            Debug.Log("playerMoveing");
            previosXss = xSS;
        }
        gameData.playerPos = playerPos.x.ToString();
        //MovePlayer();
        Shoot_time();
    }
    void MovePlayer()
    {
        if (gm != null && gm.isGameOver)
        {
            return; // Stop spawning when the game is over

        }
       
        if (Input.GetAxisRaw("Horizontal") > 0f)
        {
             temp = transform.position;
            temp.x += speed * Time.deltaTime;

            if (temp.x > max_x)
                temp.x = max_x;
            transform.position = temp;
            gameData.events = 1;
            Debug.Log("playerMoveing");

        }
        else if (Input.GetAxisRaw("Horizontal") < 0f)
        {
             temp = transform.position;
             temp.x -= speed * Time.deltaTime;

            if (temp.x < min_x)
                temp.x = min_x;
            transform.position = temp;
            gameData.events = 1;
            Debug.Log("playerMoveing");
        }
        if (Input.GetAxisRaw("Vertical") > 0f)
        {
             temp = transform.position;
            temp.y += speed * Time.deltaTime;

            if (temp.y > max_y)
                temp.y = max_y;
            transform.position = temp;
            gameData.events = 1;
            Debug.Log("playerMoveing");
        }
        else if (Input.GetAxisRaw("Vertical") < 0f)
        {
            temp = transform.position;
            temp.y -= speed * Time.deltaTime;

            if (temp.y < min_y)
                temp.y = min_y;
            transform.position = temp;
            gameData.events = 1;
            Debug.Log("playerMoveing");
        }
    }
    void Shoot_time()
    {
        if (gm != null && gm.isGameOver)
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
