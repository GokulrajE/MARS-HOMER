using UnityEngine;
using UnityEngine.UI;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System;

using UnityEngine.SceneManagement;
using System.Linq;

public class FlappyScrollingObject : MonoBehaviour
{
    
    private Rigidbody2D rb2d;
    // float auto_speed = -2.0f;
    public static float auto_speed;
    bool column_position_flag;
    // bool reduce_speed;
    bool flag_reduced_speed = false;

    public static float start_speed;
    public static float end_speed;

    // string p_hospno;

    

    // Start is called before the first frame update
    void Start()
    {
        
        rb2d = GetComponent<Rigidbody2D>();
       
        rb2d.velocity = new Vector2(-1.0f, 0);

     

               
    }

    // Update is called once per frame
    void Update()
    {
        // column_position_flag = FlappyGameControl.column_position_flag_topass;
        // column_position_flag = false;
        // if(column_position_flag)
        // {
        //     Debug.Log(column_position_flag);

        // }
        // reduce_speed = BirdControl.reduce_speed;
        // // Debug.Log(reduce_speed+" :reduce_speed");
        // if(reduce_speed & !flag_reduced_speed)
        // {
        //     // Debug.Log(reduce_speed+" :reduce_speed_flappy");
        //     flag_reduced_speed = true;
        //     auto_speed = auto_speed/2.0f;
        //     // Debug.Log(auto_speed+" :auto_speed");
            
        // }

        // if(!reduce_speed)
        // {
        //     flag_reduced_speed = false;
        //     // Debug.Log(reduce_speed+" :reduce_speed: "+flag_reduced_speed);
        // }
        
        rb2d.velocity = new Vector2(FlappyGameControl.instance.scrollSpeed, 0);
        rb2d.velocity = new Vector2(FlappyGameControl.auto_speed , 0);
        // rb2d.velocity = new Vector2(-2.0f , 0);
        // if(!column_position_flag)
        // {
        //     rb2d.velocity = new Vector2(auto_speed , 0);
        //     // Debug.Log(column_position_flag+" :column_position_flag_FALSE");
        //     // Debug.Log("NOO: "+);
            
        // }
        // else if(column_position_flag)
        // {
        //     Debug.Log("HEREEREEEEEEEEEEEEEEEEEEEEEEEEEE: "+auto_speed*2.0f);
        //     // column_position_flag = false;
        //     // Debug.Log(column_position_flag);
        //     // auto_speed = auto_speed*2.0f;
        //     // Debug.Log(auto_speed+" :auto_speed");
        //     rb2d.velocity = new Vector2(auto_speed , 0);
            
            
        // }
        
           

        if (FlappyGameControl.instance.gameOver)
        {
            rb2d.velocity = Vector2.zero;
        }

        // end_speed = auto_speed;
        
    }

    
}
