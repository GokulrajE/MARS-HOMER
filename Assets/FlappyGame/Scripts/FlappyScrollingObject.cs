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
       
    }

    // Update is called once per frame
    void Update()
    {
      
        if (FlappyGameControl.instance.isGameStarted)
        {
            rb2d.velocity = new Vector2(FlappyGameControl.instance.scrollSpeed, 0);
            //rb2d.velocity = new Vector2(FlappyGameControl.autoSpeed, 0);

        }
      
       

        if (FlappyGameControl.instance.isGameFinished)
        {
            rb2d.velocity = Vector2.zero;
        }

     
        
    }

    
}
