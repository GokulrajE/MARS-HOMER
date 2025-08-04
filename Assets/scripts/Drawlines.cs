using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System;


public class Drawlines : MonoBehaviour
{

    float initMaxX;
    float initMinX;
    float initMaxY;
    float initMinY;

    public static LineRenderer lr;
    public static List<Vector3> paths_draw;
    public static List<Vector3> paths_pass;

    int useHand;

    double xEndPoint, unityValX, yEndPoint, unityValY , centerValX, centerValY;
  
    void Start()
    {
        useHand = 2;
        Debug.Log(useHand);
        if (useHand == 1)
        {
            initMaxX = 591;
            initMinX = -91;
            initMaxY = 75;
            initMinY = -575;
        }
        else if (useHand == 2)
        {
            initMaxX = 591;
            initMinX = -91;
            initMaxY = -175;
            initMinY = -775;

        }

        paths_draw = new List<Vector3>();
        paths_pass = new List<Vector3>();
        lr = GetComponent<LineRenderer>();
        lr.SetWidth(0.1f, 0.1f);

        centerValX = (initMaxX + initMinX) / 2;
        centerValY = (initMaxY + initMinY) / 2;
    }

    void Update()
    {
        Time.timeScale = 1;

    }
    void FixedUpdate()
    {
        if (useHand == 1)
        {
            float theta1 = -MarsComm.angle1;
            float theta2 = -MarsComm.angle2;
            float theta3 = -MarsComm.angle3;

            xEndPoint = (-(475 * Mathf.Sin(3.14f / 180 * theta2) + 291 * Mathf.Sin(3.14f / 180 * theta2 + 3.14f / 180 * theta3)));
            yEndPoint = ((Mathf.Sin(3.14f / 180 * theta1) * (475 * Mathf.Cos(3.14f / 180 * theta2) + 291 * Mathf.Cos(3.14f / 180 * theta2 + 3.14f / 180 * theta3))));
            Debug.Log(xEndPoint + "...   ... " + yEndPoint);
            unityValY = -(((yEndPoint - centerValY) * 7) / (initMaxY - initMinY)) + 1;

            unityValX = (((xEndPoint - centerValX) * 4) / (initMaxX - initMinX));
        }
        else if (useHand == 2)
        {
         
            yEndPoint = ((Mathf.Sin(3.14f / 180 * MarsComm.angle1) * (475 * Mathf.Cos(3.14f / 180 * MarsComm.angle2) + 291 * Mathf.Cos(3.14f / 180 * MarsComm.angle2 + 3.14f / 180 * MarsComm.angle3))));
            xEndPoint = (-(475 * Mathf.Sin(3.14f / 180 * MarsComm.angle2) + 291 * Mathf.Sin(3.14f / 180 * MarsComm.angle2 + 3.14f / 180 * MarsComm.angle3)));
            unityValX = -(((xEndPoint - centerValX) * 10) / (initMaxX - initMinX)); //7-wide
            unityValY = -(((yEndPoint - centerValY) * 6) / (initMaxY - initMinY)) + 1;//4 Tall
          
        }

        Vector3 to_draw_values = new Vector3((float)unityValX, (float)unityValY, 0.0f);
        Vector3 to_pass_values = new Vector3((float)xEndPoint, (float)yEndPoint, 0.0f);

        paths_draw.Add(to_draw_values);
        paths_pass.Add(to_pass_values);

        lr.positionCount = paths_draw.Count;
        lr.SetPositions(paths_draw.ToArray());
        lr.useWorldSpace = true;
    }
   
}
