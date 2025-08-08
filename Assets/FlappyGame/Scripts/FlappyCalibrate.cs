using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
//using Michsky.UI.ModernUIPack;

public class FlappyCalibrate : MonoBehaviour
{
    public static LineRenderer lr;
    public static List<Vector3> paths_draw;
    public static List<Vector3> paths_pass;
    

    public static Rigidbody2D rb2d;
    public float speed = 0.001f;
    public float tilt;
    public Text ScoreText;

    Color c2;

    // Start is called before the first frame update
    void Start()
    {
        rb2d = GetComponent<Rigidbody2D>();

        paths_draw = new List<Vector3>();
        paths_pass = new List<Vector3>();
        
        c2 = new Color(1, 1, 1, 0);

        lr = GetComponent<LineRenderer>();
        lr.SetWidth(1.0f, 1.0f);
    }

    // Update is called once per frame
    void Update()
    {
        // if (Input.GetMouseButtonDown(0))
        // {
        //     Vector3 mousePos = Input.mousePosition;
        //     Debug.Log(Camera.main.ScreenToWorldPoint(Input.mousePosition)+" :xx");
        //     // Debug.Log(mousePos.y+" yy");
        // }
    }

    void FixedUpdate ()
	{		
        // float moveHorizontal = Input.GetAxis ("Horizontal");
		float moveVertical = Input.GetAxis ("Vertical");

		// Vector3 movement = new Vector3 (moveHorizontal, 0.0f, moveVertical);
        Vector3 movement = new Vector3 (0.0f, 0.0f, moveVertical);
		GetComponent<Rigidbody2D>().velocity = movement * speed;

        double y_value = ((Mathf.Cos(3.14f/180*MarsComm.angle1) * (333 * Mathf.Cos(3.14f / 180 * MarsComm.angle2) + 381 * Mathf.Cos(3.14f / 180 * MarsComm.angle2 + 3.14f / 180 *MarsComm.angle3))));
        double result_value = (-(y_value/400)*7.0);
		
        // Debug.Log("PlayerPosition: "+AppData.plutoData.enc1);
        ScoreText.text = MarsComm.angle1.ToString();

        GetComponent<Rigidbody2D>().position = new Vector3
		(
			0.0f, 
			(float)result_value+1.0f,
            0.0f
		);
		
		GetComponent<Rigidbody2D>().transform.rotation = Quaternion.Euler (0.0f, 0.0f, GetComponent<Rigidbody2D>().velocity.x * -tilt);

		
		Vector3 xxx = GetComponent<Rigidbody2D>().position;
		// Debug.Log("PlayerPosition: "+xxx);

        Vector3 to_draw_values = xxx;
        Vector3 to_pass = new Vector3 (0.0f, (float)y_value,0.0f);
        
        paths_draw.Add(to_draw_values);
        paths_pass.Add(to_pass);

        lr.positionCount = paths_draw.Count;
        lr.SetPositions (paths_draw.ToArray());
        lr.SetColors(Color.green,Color.green);
        lr.useWorldSpace = true;
		
	}


    public void onclick_recalibrate()
    {
        SceneManager.LoadScene("FlappyRecalibrate");
    }
}
