using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System;
using UnityEngine.UI;


public class Drawlines : MonoBehaviour
{

    float endPointMaxX;
    float endPointMinX;
    float endPointMaxY;
    float endPointMinY;

    //Line render
    public static LineRenderer lr;
    public static List<Vector3> unityDrawValues;
    public static List<Vector3> endPntPos;
    public int OFFSET;


   
    public static  double zEndPoint, unityValX, yEndPoint, unityValY , centerValX, centerValY;

    void Start()
    {
        //meter 
        endPointMaxX = 0.800f;
        endPointMinX = -0.082f;
        endPointMaxY = -0.092f;
        endPointMinY = -0.800f;
       

        unityDrawValues = new List<Vector3>();
        endPntPos = new List<Vector3>();
        lr = GetComponent<LineRenderer>();
        lr.SetWidth(0.1f, 0.1f);

        centerValX = (endPointMaxX + endPointMinX) / 2;
        centerValY = (endPointMaxY + endPointMinY) / 2;
        OFFSET = AppData.Instance.userData.useHand == 1 ? -1 : 1;

    }
    void FixedUpdate()
    {
        if(DrawArea.instance.countDown>0)
                return;
        Vector3 endPointPosition = MarsKinDynamics.ForwardKinematicsExtended(MarsComm.angle1,MarsComm.angle2,MarsComm.angle3,MarsComm.angle4);
        zEndPoint = endPointPosition.z;
        yEndPoint = endPointPosition.y;
        unityValX = OFFSET*(((zEndPoint - centerValX) * 10) / (endPointMaxX - endPointMinX)); //10-width
        unityValY = -(((yEndPoint - centerValY) * 7) / (endPointMaxY - endPointMinY)) + 1;//7-hight unity scene draw area
        Vector3 toDrawValues = new Vector3((float)unityValX, (float)unityValY, 0.0f);
        Vector3 endPointValues = new Vector3((float)zEndPoint, (float)yEndPoint, 0.0f);
        unityDrawValues.Add(toDrawValues);
        endPntPos.Add(endPointValues);
        lr.positionCount = unityDrawValues.Count;
        lr.SetPositions(unityDrawValues.ToArray());
        lr.useWorldSpace = true;
    }
   
}
