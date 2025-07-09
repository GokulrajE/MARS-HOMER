using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;

public class DiagnosticSceneHandler : MonoBehaviour
{
    public TMP_Text UpdateTextBox;
   
    void Start()
    {

        //AppData.Instance.Initialize(SceneManager.GetActiveScene().name);
        AppData.Instance.InitializeRobot();
    }

    private void Update()
    {
        updateTextBox();
      
    }
    public void updateTextBox()
    {
        //Construct the display text while ensuring values are safely converted to string
        string displayText = "Theta1        : " + MarsComm.angleOne.ToString() + "\n" +
                             "Theta2        : " + MarsComm.angleTwo.ToString() + "\n" +
                             "Theta3        : " + MarsComm.angleThree.ToString() + "\n" +
                             "Theta4        : " + MarsComm.angleFour.ToString() + "\n" +
                             "IMUAng1       : " + MarsComm.imuAng1.ToString() + "\n" +
                             "IMUAng2       : " + MarsComm.imuAng2.ToString() + "\n" +
                             "IMUAng3       : " + MarsComm.imuAng3.ToString() + "\n" +
                             "IMUAng4       : " + MarsComm.imuAng4.ToString() + "\n" +
                             "Force1        : " + MarsComm.forceOne.ToString() + "\n" +
                             "calibBtnState : " + MarsComm.calibBtnState.ToString() + "\n" +

                             "des1          : " + MarsComm.desOne.ToString() + "\n" +
                             "des2          : " + MarsComm.desTwo.ToString() + "\n" +
                             "des3          : " + MarsComm.desThree.ToString() + "\n" +
                             "dataSndToRobot: " + MarsComm.pcParameter.ToString() + "\n" +
                             "shoulderPosX  : " + MarsComm.shPosX.ToString() + "\n" +
                             "shoulderPosy  : " + MarsComm.shPosY.ToString() + "\n" +
                             "shoulderPosz  : " + MarsComm.shPosZ.ToString() + "\n" +
                             "lenUpperArm   : " + MarsComm.lenUpperArm.ToString() + "\n" +
                             "lenLowerArm   : " + MarsComm.lenUpperArm.ToString() + "\n" +
                             "weight1       : " + MarsComm.lenUpperArm.ToString() + "\n" +
                             "weight2       : " + MarsComm.lenUpperArm.ToString() + "\n" +

                             //$"IMU1         :  aX - {MarsComm.imu1aX.ToString()}    aY - {MarsComm.imu1aY.ToString()}   aZ - {MarsComm.imu1aZ}" + "\n" +
                             //$"IMU2         :  aX - {MarsComm.imu2aX.ToString()}    aY - {MarsComm.imu2aY.ToString()}   aZ - {MarsComm.imu2aZ}" + "\n" +
                             //$"IMU3         :  aX - {MarsComm.imu3aX.ToString()}    aY - {MarsComm.imu3aY.ToString()}   aZ - {MarsComm.imu3aZ}" + "\n" +
                             "Btn_st        : " + MarsComm.buttonState.ToString();
        
        UpdateTextBox.text = displayText;
    }

    private void OnApplicationQuit()
    {

        Application.Quit();
        JediComm.Disconnect();
    }
}
