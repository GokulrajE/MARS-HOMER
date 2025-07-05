using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
//using PlutoDataStructures;

using System.IO;
using System;
using System.Linq;
using System.Text;
using System.Data;
using NeuroRehabLibrary;
//using Newtonsoft.Json;

// [System.Serializable]
// public class Done_Boundary 
// {
// 	public float xMin, xMax, zMin, zMax;
// }

public class BirdControl : MonoBehaviour
{
    //public Done_Boundary boundary;
    private float[] angXRange = { -40, 40 };
	private float[] angZRange  = { -200, 200 };
    public float tilt;

    // max_x_init=681;
    //         min_x_init=81;
    //         max_y_init=-33;
    //         min_y_init=-633;

    public static BirdControl instance;
    private bool isDead = false;
    public static Rigidbody2D rb2d;
    Animator anime;
    // player controls

    public int controlValue;
    public static float playSize;
    public static int FlipAngle = 1;
    public static float tempRobot,tempBird;
    public bool set= false;
    public TMPro.TMP_Dropdown ControlMethod;
    public float angle1;

    int totalLife = 5;
    int currentLife = 0;
    bool columnHit;
    public Image life1;
    public Image life2;
    public Image life3;

    public float spriteBlinkingTimer = 0.0f;
    public float spriteBlinkingMiniDuration = 0.1f;
    public float spriteBlinkingTotalTimer = 0.0f;
    public float spriteBlinkingTotalDuration = 2f;
    public bool startBlinking = false;
   
    public float happyTimer = 200.0f;

    public float speed = 0.001f;
    //public float down_speed = 3f;
    //public float up_speed = -3f;
    public float Player_translate_UpSpeed = 0.03f;
    public float Player_translate_DownSpeed = -0.03f;

    static float topbound = 5.5F;
    static float bottombound = -3.5F;
    //public static float playSize;
    public static float spawntime = 3f;
    private Vector2 direction;
    public static float y_value,previousY;

    float startTime;
    float endTime;
    float loadcell;
    // Start is called before the first frame update

    float targetAngle;

    public FlappyGameControl FGC;

    //flappybird style for hand grip
    private Vector3 Direction;
    public float gravity = -9.8f;
    public float strength;

    long temp_ms=0;
    
    public static int collision_count;
    public int total_life = 3;
    public int overall_life = 3;

    string date_now;
    string hospno;
    int hand_use;
    int count_session;

    public static int hit_count = 0;

    public static bool reduce_speed;

    StringBuilder csv = new StringBuilder();

    List<Vector3> paths;
	public static float max_y;
	public static float min_y;
    public static float max_y_Unity = 3, min_y_Unity = -6;
    float y_c;
    float theta1, theta2, theta3, theta4;
     public int[] DEPENDENT = new int[] { 0, -1, 1 };
   
    void Start()
    {
       
        collision_count = 0;
        startTime = 0;
        endTime = 0;
        currentLife = 0;
        anime = GetComponent<Animator>();
        rb2d = GetComponent<Rigidbody2D>();
       
        playSize = 2.3f + 5.5f;

        reduce_speed = false;

        paths = new List<Vector3>();
        paths = FlappyCalibrate.paths_pass;

        max_y = -(Mathf.Abs(MovementSceneHandler.initialAngle) + 20);
        min_y = -(Mathf.Abs(MovementSceneHandler.initialAngle) - 20);
        y_c = max_y-min_y;

        angZRange[0] = max_y;
		angZRange[1] = min_y;
        
        

    }

    // Update is called once per frame

    private void Update()
    {
       
        if (startBlinking == true)
        {
            hit_count = collision_count;
            
            if (collision_count<total_life)
            {
                SpriteBlinkingEffect();   
            }   
            else
            {
                overall_life = overall_life-1;
                // Debug.Log(overall_life+" :gameOver__");
                FlappyGameControl.instance.BirdDied();
                // Debug.Log("over!");
                collision_count = 0;
                life1.enabled = true;
                life2.enabled = true;
                life3.enabled = true;
                // Destroy(gameObject);
                // gameObject.SetActive (false);
                if(overall_life==0)
                {
                    // FlappyGameControl.instance.BirdDied();
                    reduce_speed = true;
                    overall_life = 3;
                    // Debug.Log(overall_life + ".." +reduce_speed+" :reduce_speed");
                }
                else
                {
                    reduce_speed = false;
                    // Debug.Log(reduce_speed+" :reduce_speed");
                }
                
            }

        }


    }

   
    void FixedUpdate ()
	{
        // float moveHorizontal = Input.GetAxis ("Horizontal");
        float moveVertical = Input.GetAxis("Vertical");
        Vector3 movement = new Vector3(0.0f, 0.0f, moveVertical);
        GetComponent<Rigidbody2D>().velocity = movement * speed;

        //move the game object based on MarsAngle

        y_value = -Mathf.Clamp(Angle2ScreenZ(DEPENDENT[AppData.Instance.userData.uaLength] * MarsComm.angleOne), min_y_Unity, max_y_Unity);
        //Debug.Log(y_value);
        GetComponent<Rigidbody2D>().position = new Vector3
        (
            0.0f,
            (float)y_value,
            0.0f
        );

        gameData.playerPos = GetComponent<Rigidbody2D>().position.y.ToString();
        if(y_value!= previousY)
        {
            gameData.events = 1;
            Debug.Log("playermoving");
            previousY = y_value;
        }
        GetComponent<Rigidbody2D>().transform.rotation = Quaternion.Euler(0.0f, 0.0f, GetComponent<Rigidbody2D>().velocity.x * -tilt);
        //KeyboardControl();

    }
    
	public float Angle2ScreenZ(float angleZ)
    {
        float playSizeZ = 6 - (-6);
        return Mathf.Clamp(-6 + (angleZ - angZRange[0]) * (playSizeZ) / (angZRange[1] - angZRange[0]), -1.2f * playSizeZ, 1.2f * playSizeZ);
	}

   
    public void SpriteBlinkingEffect()
    {
        spriteBlinkingTotalTimer += Time.deltaTime;
        if (spriteBlinkingTotalTimer >= spriteBlinkingTotalDuration)
        {
            startBlinking = false;
            spriteBlinkingTotalTimer = 0.0f;
            this.gameObject.GetComponent<SpriteRenderer>().enabled = true;   // according to 
                                                                             //your sprite
            return;
        }

        spriteBlinkingTimer += Time.deltaTime;
        if (spriteBlinkingTimer >= spriteBlinkingMiniDuration)
        {
            spriteBlinkingTimer = 0.0f;
            if (this.gameObject.GetComponent<SpriteRenderer>().enabled == true)
            {
                this.gameObject.GetComponent<SpriteRenderer>().enabled = false;  //make changes
            }
            else
            {
                this.gameObject.GetComponent<SpriteRenderer>().enabled = true;   //make changes
            }
        }
    }

    
    private void OnCollisionEnter2D(Collision2D collision)
    {
        gameData.events = 2;
        startBlinking = true;
        collision_count++;
        // Debug.Log(collision_count+" :collision");
        if(collision_count == 1)
        {
            life1.enabled=false;
        }
        else if(collision_count == 2)
        {
            life2.enabled=false;
        }
        else if(collision_count == 3)
        {
            life3.enabled=false;
        }
        
        
    }

    
    public static float Force2Screen(float force)
    {   float GripForce = PlayerPrefs.GetFloat("Grip force");
        return (-2.3f + (force - 2.3f ) * (playSize) / (GripForce - 2.3f));
    }

    public static float Angle2Screen(float angle)// Last used for handle surface testing
    {
        //angle1 = angle;
        float AngMin = PlayerPrefs.GetFloat("Handle Ang Min");
        float AngMax = PlayerPrefs.GetFloat("Handle Ang Max");
        if (angle > 45f)
        {
            //return (-0.5f + (angle - 40) * (playSize) / (20 - (-90)));
            //return ((0.1636f * angle) - 10.8636f); // Last used for handle surface testing
            return (-2.3f + (angle - AngMin) * (playSize) / (AngMax - AngMin));
        }

        else
        {
            return (bottombound);
        }


    }
    public static float Angle2ScreenTripodGrasp(float angle)// Last used for handle surface testing
    {
        //angle1 = angle;
        float DistMin = PlayerPrefs.GetFloat("Dist Min");
        float DistMax = PlayerPrefs.GetFloat("Dist Max");
        
        
            //return (-0.5f + (angle - 40) * (playSize) / (20 - (-90)));
            //return ((0.1636f * angle) - 10.8636f); // Last used for handle surface testing
            return (-2.3f + (angle - DistMin) * (playSize) / (DistMax - DistMin));

    }

    public static float Angle2ScreenFineKnob(float angle)
    {

        //130 and -120 degrees.
        return Mathf.Clamp((0.036f * angle + 0.82f), bottombound, topbound);


    }

    public static float Angle2ScreenGrossKnob(float angle)
    {

        //45 and -60 degrees.
       return Mathf.Clamp((-0.085f * angle + 0.325f), bottombound, topbound);


    }

    public static float Angle2ScreenKeyHold(float angle)
    {

        //95 and -40 degrees.
        return Mathf.Clamp((-0.067f * angle + 2.865f), bottombound, topbound);


    }

    private void KeyboardControl()
    {
        if (Input.GetKey(KeyCode.UpArrow))
        {
            gameData.events = 1;
            direction = Vector2.up;
            this.transform.Translate(direction * speed * Time.deltaTime);
        }
        else if (Input.GetKey(KeyCode.DownArrow))
        {
            gameData.events = 1;
            direction = Vector2.down;
            this.transform.Translate(direction * speed * Time.deltaTime);
        }
        else
        {
            direction = Vector2.zero;
        }
    }
   
}
