using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System;


public class Drawlines : MonoBehaviour
{
  
    float max_x_init;
    float min_x_init;
    float max_y_init;
    float min_y_init;

    double x_c;
    double y_c;

    double y_value, y_u;

    public static LineRenderer lr;
    public static List<Vector3> paths_draw;
    public static List<Vector3> paths_pass;

    string hospno;
    int hand_use;

    double x_value;
    double x_u;

    int[] DEPENDENT = new int[] { 0, -1, 1 };
    void Start()
    {
        hand_use = AppData.Instance.userData.useHand;
        Debug.Log(hand_use);
        if (hand_use == 1)
        {
            max_x_init = 591;
            min_x_init = -91;
            max_y_init = 75;
            min_y_init = -575;
        }
        else if (hand_use == 2)
        {
            max_x_init = 591;
            min_x_init = -91;
            max_y_init = -175;
            min_y_init = -775;
        }
        
        paths_draw = new List<Vector3>();
        paths_pass = new List<Vector3>();
        lr = GetComponent<LineRenderer>();
        lr.SetWidth(0.1f, 0.1f);

        x_c = (max_x_init + min_x_init) / 2;
        y_c = (max_y_init + min_y_init) / 2;
    }

    void Update()
    {
        Time.timeScale = 1;

    }
    void FixedUpdate()
    {
        if (hand_use == 1)
        {
            float theta1 = -MarsComm.angle1;
            float theta2 = -MarsComm.angle2;
            float theta3 = -MarsComm.angle3;

            x_value = (-(475 * Mathf.Sin(3.14f / 180 * theta2) + 291 * Mathf.Sin(3.14f / 180 * theta2 + 3.14f / 180 * theta3)));
            y_value = ((Mathf.Sin(3.14f / 180 * theta1) * (475 * Mathf.Cos(3.14f / 180 * theta2) + 291 * Mathf.Cos(3.14f / 180 * theta2 + 3.14f / 180 * theta3))));
            Debug.Log(x_value + "...   ... " + y_value);
            y_u = -(((y_value - y_c) * 7) / (max_y_init - min_y_init)) + 1;

            x_u = (((x_value - x_c) * 14) / (max_x_init - min_x_init));
        }
        else if (hand_use == 2)
        {
            y_value = ((Mathf.Sin(3.14f / 180 * MarsComm.angle1) * (475 * Mathf.Cos(3.14f / 180 * MarsComm.angle2) + 291 * Mathf.Cos(3.14f / 180 * MarsComm.angle2 + 3.14f / 180 * MarsComm.angle3))));
            x_value = (-(475 * Mathf.Sin(3.14f / 180 * MarsComm.angle2) + 291 * Mathf.Sin(3.14f / 180 * MarsComm.angle2 + 3.14f / 180 * MarsComm.angle3)));
            x_u = -(((x_value - x_c) * 14) / (max_x_init - min_x_init));
            y_u = -(((y_value - y_c) * 7) / (max_y_init - min_y_init)) + 1;
        }
        //y_value = ((Mathf.Sin(3.14f / 180 * (DEPENDENT[AppData.useHand]*MarsComm.angle1)) * (475 * Mathf.Cos(3.14f / 180 * (DEPENDENT[AppData.useHand]*MarsComm.angle2)) + 291 * Mathf.Cos(3.14f / 180 * (DEPENDENT[AppData.useHand] * MarsComm.angle2)+ 3.14f / 180 * (DEPENDENT[AppData.useHand] * MarsComm.angle3)))));
        //x_value = (-(475 * Mathf.Sin(3.14f / 180 * (DEPENDENT[AppData.useHand] * MarsComm.angle2)) + 291 * Mathf.Sin(3.14f / 180 * (DEPENDENT[AppData.useHand] * MarsComm.angle2) + 3.14f / 180 * (DEPENDENT[AppData.useHand] * MarsComm.angle3))));
        //x_u = DEPENDENT[AppData.useHand] * -(((x_value - x_c) * 14) / (max_x_init - min_x_init));
        //y_u = -(((y_value - y_c) * 7) / (max_y_init - min_y_init)) + 1;
        Vector3 to_draw_values = new Vector3((float)x_u, (float)y_u, 0.0f);
        Vector3 to_pass_values = new Vector3((float)x_value, (float)y_value, 0.0f);

        paths_draw.Add(to_draw_values);
        paths_pass.Add(to_pass_values);

        lr.positionCount = paths_draw.Count;
        lr.SetPositions(paths_draw.ToArray());
        lr.useWorldSpace = true;
    }


}
