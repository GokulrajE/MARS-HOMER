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
    private float[] angZRange = { -200, 200 };
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

  
    public static float playSize;
   
   
 
    public float angle1;

    int currentLife;

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
    public static float y_value, previousY;

    float startTime;
    float endTime;

    public FlappyGameControl FGC;

   
    public float gravity = -9.8f;
    public float strength;


    public static int collision_count;
    public int total_life = 3;
    public int overall_life = 3;


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
        y_c = max_y - min_y;

        angZRange[0] = max_y;
        angZRange[1] = min_y;



    }

    // Update is called once per frame

    private void Update()
    {

        if (startBlinking == true)
        {
            hit_count = collision_count;

            if (collision_count < total_life)
            {
                SpriteBlinkingEffect();
            }
            else
            {
                overall_life = overall_life - 1;
                FlappyGameControl.instance.BirdDied();
                collision_count = 0;
                life1.enabled = true;
                life2.enabled = true;
                life3.enabled = true;
           
                if (overall_life == 0)
                {
               
                    reduce_speed = true;
                    overall_life = 3;
              
                }
                else
                {
                    reduce_speed = false;
                
                }

            }

        }


    }


    void FixedUpdate()
    {
        // float moveHorizontal = Input.GetAxis ("Horizontal");
        float moveVertical = Input.GetAxis("Vertical");
        Vector3 movement = new Vector3(0.0f, 0.0f, moveVertical);
        GetComponent<Rigidbody2D>().velocity = movement * speed;

        //move the game object based on MarsAngle

        y_value = -Mathf.Clamp(Angle2ScreenZ(DEPENDENT[AppData.Instance.userData.useHand] * MarsComm.angle1), min_y_Unity, max_y_Unity);
        //Debug.Log(y_value);
        GetComponent<Rigidbody2D>().position = new Vector3
        (
            -6f,
            (float)y_value,
            0.0f
        );


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
        
        startBlinking = true;
        collision_count++;
        // Debug.Log(collision_count+" :collision");
        if (collision_count == 1)
        {
            life1.enabled = false;
        }
        else if (collision_count == 2)
        {
            life2.enabled = false;
        }
        else if (collision_count == 3)
        {
            life3.enabled = false;
        }


    }


}