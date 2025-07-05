
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using TMPro;
using System;

public class weightEstimation : MonoBehaviour
{
    //ui related variables
    public TMP_Text UpdateText;

    public float[] phi1 = new float[] { 0 };
    public float[] phi2 = new float[] { 0 };
    public float[] phi3 = new float[] { 0 };
    public float[] force = new float[] { 0 };
    public float[] momentArm = new float[] { 0 };
    public float[] tauf = new float[] { 0 };
    public static float[] sol = new float[2];
   //flags
    public int recordClick = 0;
    public float weightCalibStatus;

    //FileHeader
    string headerData = "Time,B1,B2";
    //
    string headerData1 = "Shf,sha,elf,tauf,endx,endy,force,angle1,angle2,angle3,angle4,shox,shoy,shoz";
    string data;
    bool HOLD = false;
    bool RELEASE = false;
    void Start()
    {
        AppLogger.StartLogging(SceneManager.GetActiveScene().name);
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        weightCalibStatus = 0;
    }
    
    void Update()
    {
      
        MarsComm.computeShouderPosition();

        //if(MarsComm.desThree < 2005)
        //  AppData.MakeRobotHoldTheArm.initiate
        if (HOLD)
        {
            MarsComm.onclickHold();
            if(MarsComm.pcParameter == MarsComm.CONTROL_STATUS_CODE[0])
                HOLD = false;
        }

        if (RELEASE)
        {
            MarsComm.onclickRealease();
            if (MarsComm.desThree == 0)
                RELEASE = false;
        }

        if (weightCalibStatus == 2004)
        {

            //if (MarsComm.desThree < AppData.ArmSupportController.SEND_ARM_WEIGHT)
            //{
            //    AppData.dataSendToRobot = new float[] { sol[0], (float)MarsComm.thetades1, AppData.ArmSupportController.SEND_ARM_WEIGHT, (float)MarsComm.controlStatus };
            //    AppData.sendToRobot(AppData.dataSendToRobot);
            //}
            //if (MarsComm.desThree == AppData.ArmSupportController.SEND_ARM_WEIGHT)
            //{
            //    AppData.dataSendToRobot = new float[] { sol[1], (float)MarsComm.thetades1, AppData.ArmSupportController.MARS_ACTIVATED, (float)MarsComm.controlStatus };
            //    AppData.sendToRobot(AppData.dataSendToRobot);

            //}
            //else if (MarsComm.desThree == AppData.ArmSupportController.MARS_ACTIVATED)
            //{

            //    Debug.Log("Weight Calibration Complete");
            //    AppLogger.LogInfo("weight calibration has been completed successfully " + "b1=" + sol[0] + "b2 = " + sol[1] + "sigmoid dz  = " + MarsComm.desOne + "sigmoid Flex = " + MarsComm.desTwo + "Flexion Torque  = " + MarsComm.desThree);

            //    weightCalibStatus = 2006;
            //}
           

        }
        updateGUI();

        //AppData.sendToRobot(AppData.dataSendToRobot);
    }
   
    public void updateGUI()
    {
        //if (weightCalibStatus <= AppData.ArmSupportController.SEND_ARM_WEIGHT)
        //    return;
        //UpdateText.text = "b1=" + sol[0] +
        //              "b2 = " + sol[1] + '\n' +
        //              "Weight Estimation Complete" + '\n' +
        //              "sigmoid dz  = " + MarsComm.desOne + '\n' +
        //              "sigmoid Flex = " + MarsComm.desTwo + '\n' +
        //              "Flexion Torque  = " + MarsComm.desThree;
       
    }
    public void onClickRecord()
    {
        
        if (MarsComm.pcParameter != MarsComm.CONTROL_STATUS_CODE[0])
        {
            UpdateText.text = "please.. 'HOLD' MARS";
            return;
        }

        if (MarsComm.elF == float.NaN)
            return;
        recordClick++;
        AppLogger.LogInfo("recoding the data for weight calibration : count-" + recordClick++);
        if (recordClick == 1)
        {
          
            phi1[0] = MarsComm.shF;
            phi2[0] = MarsComm.shA;
            phi3[0] = MarsComm.elF;
            momentArm[0] = Mathf.Pow(MarsComm.endPt[0] * MarsComm.endPt[0] + MarsComm.endPt[1] * MarsComm.endPt[1], 0.5f);
            force[0] = MarsComm.forceOne;
            tauf[0] = MarsComm.forceOne * momentArm[0] / 1000.0f;
            Debug.Log(phi1.Length);
            Debug.Log("shF  =   " + MarsComm.shF + ",   shA   =   " + MarsComm.shA + ",   elF   =   " + MarsComm.elF + ",   tauf   =   " + tauf[0] + ",   endx   =   " + MarsComm.endPt[0] + ",   endy   =   " + MarsComm.endPt[1]);
            UpdateText.text = "shF  =   " + MarsComm.shF + ",   shA   =   " + MarsComm.shA + ",   elF   =   " + MarsComm.elF + ",   tauf   =   " + tauf[0] + ",   endx   =   " + MarsComm.endPt[0] + ",   endy   =   " + MarsComm.endPt[1]+"force = "+MarsComm.forceOne;
            data = $"{MarsComm.shF},{MarsComm.shA},{MarsComm.elF},{tauf[0]},{MarsComm.endPt[0]},{MarsComm.endPt[1]},{MarsComm.forceOne},{MarsComm.angleOne},{MarsComm.angleTwo},{MarsComm.angleThree},{MarsComm.angleFour},{MarsComm.shPos[0]},{MarsComm.shPos[1]},{MarsComm.shPos[2]}";
           
        }
        else
        {
            System.Array.Resize(ref phi1, phi1.Length + 1);
            System.Array.Resize(ref phi2, phi2.Length + 1);
            System.Array.Resize(ref phi3, phi3.Length + 1);
            System.Array.Resize(ref momentArm, momentArm.Length + 1);
            System.Array.Resize(ref force, force.Length + 1);
            System.Array.Resize(ref tauf, tauf.Length + 1);

            Debug.Log(phi1.Length);

            phi1[phi1.Length - 1] = MarsComm.shF;
            phi2[phi2.Length - 1] = MarsComm.shA;
            phi3[phi3.Length - 1] = MarsComm.elF;
            momentArm[momentArm.Length - 1] = Mathf.Pow(MarsComm.endPt[0] * MarsComm.endPt[0] + MarsComm.endPt[1] * MarsComm.endPt[1], 0.5f);
            force[force.Length - 1] = MarsComm.forceOne;
            tauf[tauf.Length - 1] = MarsComm.forceOne * momentArm[momentArm.Length - 1] / 1000.0f;
            UpdateText.text = "shF  =   " + MarsComm.shF + ",   shA :" + MarsComm.shA + ",elF :" + MarsComm.elF + ",tauf = " + tauf[tauf.Length - 1] + ",endx = " + MarsComm.endPt[0] + ",   endy   =   " + MarsComm.endPt[1];

            Debug.Log("shF  =   " + MarsComm.shF + ",   shA   =   " + MarsComm.shA + ",   elF   =   " + MarsComm.elF + ",   tauf   =   " + tauf[tauf.Length - 1] + ",   endx   =   " + MarsComm.endPt[0] + ",   endy   =   " + MarsComm.endPt[1]);
            data = $"{MarsComm.shF},{MarsComm.shA},{MarsComm.elF},{tauf[tauf.Length - 1]},{MarsComm.endPt[0]},{MarsComm.endPt[1]},{MarsComm.forceOne},{MarsComm.angleOne},{MarsComm.angleTwo},{MarsComm.angleThree},{MarsComm.angleFour},{MarsComm.shPos[0]},{MarsComm.shPos[1]},{MarsComm.shPos[2]}";
        }
        //test purpose
        AppData.writeAssessmentData(headerData1, data, $"testData.csv", DataManager.directoryAssessmentData);


    }

    public void onClickWeightCalib()
    {
        AppLogger.LogInfo("calibrating the weight");
        UpdateText.text = "calibrating...";
        float[,] Amat = new float[phi1.Length, 2];
        float[,] AmatTrans = new float[2, phi1.Length];
        float[,] ATA = new float[2, 2];
        float[] ATf = new float[2];
        float[,] ATAinv = new float[2, 2];

        for (int i = 0; i < phi1.Length; i++)
        {
            Amat[i, 0] = Mathf.Sin(phi1[i]) * Mathf.Cos(phi2[i]);
            Amat[i, 1] = Mathf.Sin(phi1[i]) * Mathf.Cos(phi2[i] - phi3[i]);

            AmatTrans[0, i] = Amat[i, 0];
            AmatTrans[1, i] = Amat[i, 1];
        }

        ATA = matmul(AmatTrans, Amat);
        ATAinv = matInvTwoCrossTwo(ATA);
        ATf = matVecMul(AmatTrans, tauf);
        sol = matVecMul(ATAinv, ATf);
        weightCalibStatus = 2004;
       
        DateTime time = DateTime.Now;
        string data = time.ToString() + "," + sol[0] + "," + sol[1] ;
        string data1 = time.ToString() + "," + sol[0] + "," + sol[1]+"\\n////////\\n";
        AppData.writeAssessmentData(headerData1, data1, $"testData.csv", DataManager.directoryAssessmentData);
        AppData.writeAssessmentData(headerData, data, DataManager.SupportCalibrationFileName, DataManager.directoryAssessmentData);
         phi1 = new float[] { 0 };
         phi2 = new float[] { 0 };
         phi3 = new float[] { 0 };
         force = new float[] { 0 };
         momentArm = new float[] { 0 };
         tauf = new float[] { 0 };
         recordClick = 0;

    }

    public float[,] matmul(float[,] Ac, float[,] Bc)
    {
        float[,] Cx = new float[Ac.GetLength(0), Bc.GetLength(1)];

        for (int i = 0; i < Ac.GetLength(0); i++)
        {
            for (int j = 0; j < Bc.GetLength(1); j++)
            {
                Cx[i, j] = 0;

                for (int k = 0; k < Ac.GetLength(1); k++)
                {
                    Cx[i, j] = Cx[i, j] + Ac[i, k] * Bc[k, j];
                }
            }
        }

        return Cx;

    }

    public float[] matVecMul(float[,] Ac, float[] Bc)
    {
        float[] Cx = new float[Ac.GetLength(0)];

        for (int i = 0; i < Ac.GetLength(0); i++)
        {
            Cx[i] = 0;

            for (int k = 0; k < Ac.GetLength(1); k++)
            {
                Cx[i] = Cx[i] + Ac[i, k] * Bc[k];
            }

        }

        return Cx;
    }

    public float[,] matInvTwoCrossTwo(float[,] Ac)
    {
        float[,] AcInv = new float[2, 2];

        float det = Ac[0, 0] * Ac[1, 1] - Ac[0, 1] * Ac[1, 0];

        AcInv[0, 0] = Ac[1, 1] / det;
        AcInv[0, 1] = -Ac[0, 1] / det;
        AcInv[1, 0] = -Ac[1, 0] / det;
        AcInv[1, 1] = Ac[0, 0] / det;

        return AcInv;
    }
    public void onclickexit()
    {
        SceneManager.LoadScene("chooseMovementScene");
    }
    public void onClickHold()
    {
        HOLD = true;
    }

    public void onClickRelease()
    {
        RELEASE = true;
    }
   
    public void ActivateMars()
    {
        //if (MarsComm.desThree == AppData.ArmSupportController.MARS_ACTIVATED)
        //{
        //    AppData.ArmSupportController.setSupport(MarsComm.SUPPORT_CODE[1]);
        //}
   
    }
    public void ROMforFullsupport()
    {
        Debug.Log(MarsComm.desOne + "," + MarsComm.SUPPORT + "$fullweightsuppoer");
        if (MarsComm.desOne == MarsComm.SUPPORT)
        {
            Debug.Log(MarsComm.desOne + "," + MarsComm.SUPPORT + "$fullweightsuppoerin");
            AppLogger.LogInfo("full weight suppport initiated");
            SceneManager.LoadScene("fullWeightSupportScene");
        }
    }
    private void OnApplicationQuit()
    {

        Application.Quit();
        JediComm.Disconnect();
    }
}
