using TMPro;
using UnityEditor.VersionControl;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class calibrationSceneHandler : MonoBehaviour
{
    //ui related variables
    public TMP_Text messageBox;
    public readonly string nextScene = "CHOOSEMOVEMENT";
    public GameObject panel;
    Image panelImage;
    public Text limbTxt;
    public Image limbTick;
    public Image calibTick;
    public Text calibTxt;
    public Text kinParaTxt;
    public Image kinTick;
    public Text messageTxt;

    private const int MAX_ENDPOINTS = 10;
    private int endpointCount = 0;
    private Vector3[] endpointPositions = new Vector3[100];

    private float setHLimbKinUALength = 0.0f;
    private float setHLimbKinFALength = 0.0f;
    private float setHLimbKinShPosZ = 0.0f;
    private enum CALIBSTATES
    {
        WAITFORSTART = 0x00,
        START = 0x01,
        SETUPLIMB = 0x02,
        CALIBRATE= 0x03,
        SETPOSITION = 0X04,
        SETLIMBKINPARA = 0x05,
        ALLDONE = 0x06,
        CHANGESCENE = 0x07
        
    }
    private CALIBSTATES calibState ;


    void Start()
    {
        messageTxt.text = "HIT MARS BUTTON TO START CALIBRATION";
        
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        MarsComm.OnCalibButtonReleased += onCalibButtonReleased;
        MarsComm.onHumanLimbKinParamData += OnHumanLimbKinParamData;
        calibState = CALIBSTATES.WAITFORSTART;
        initUI()
;    }

    void Update()
    {
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.A))
        {
             if(calibState == CALIBSTATES.ALLDONE)
                SceneManager.LoadScene("WEIGHTEST");
        }
        MarsComm.sendHeartbeat();
        RunCalibStateMachine();
        Debug.Log(calibState.ToString());
    }
   
    public void onMarsButtonReleased()
    {
        switch (calibState)
        {
            case CALIBSTATES.WAITFORSTART:
                calibState = CALIBSTATES.SETUPLIMB;
            break;
            case CALIBSTATES.CALIBRATE:
                
                break;
            case CALIBSTATES.ALLDONE:
                calibState = CALIBSTATES.CHANGESCENE;
                //change the scene
                break;
        }
    }
    

    private void onCalibButtonReleased()
    {
        if (calibState == CALIBSTATES.SETLIMBKINPARA)
        {
            // Get the current endpoint position from MARS robot.
            // Compute the average position of the endpoints.
            Vector3 averagePosition = Vector3.zero;
            for (int i = 0; i < MAX_ENDPOINTS; i++)
            {
                averagePosition += endpointPositions[i];
            }
            averagePosition /= MAX_ENDPOINTS;
            // Set the human limb kinematic parameters based on the average position.
            setHLimbKinUALength = (float)AppData.Instance.userData.uaLength/100;
            setHLimbKinFALength = (float)AppData.Instance.userData.faLength/100;
            setHLimbKinShPosZ = averagePosition.z;
            Debug.Log($"Setting human limb kinematic parameters: UALength={setHLimbKinUALength}, FALength={setHLimbKinFALength}, Average Position Z={setHLimbKinShPosZ}");
            MarsComm.setHumanLimbKinParams(setHLimbKinUALength, setHLimbKinFALength, setHLimbKinShPosZ);
            // Get the human limb kinematic parameters from MARS.
            MarsComm.getHumanLimbKinParams();
           
        }
    }
    
    private void OnHumanLimbKinParamData()
    {
        // Check if the human limb kinematics parameters match the set values.
        if (MarsComm.limbKinParam != 0x01 || MarsComm.uaLength != setHLimbKinUALength || MarsComm.faLength != setHLimbKinFALength || MarsComm.shPosZ != setHLimbKinShPosZ)
        {
            Debug.LogWarning("Human limb kinematic parameters are not set correctly.");
        
            MarsComm.resetHumanLimbKinParams();
        }
        else
        {
           
            calibState = CALIBSTATES.ALLDONE;
            Debug.Log("Human limb kinematic parameters are set correctly.");
           
        }
    }

    private void RunCalibStateMachine()
    {
        if (calibState == CALIBSTATES.WAITFORSTART) return;
        updataUI();
        switch (calibState)
        {
            case CALIBSTATES.SETUPLIMB:
               
                if (MarsComm.LIMBTYPE[MarsComm.limb] == "NOLIMB")
                {
                    MarsComm.setLimb(MarsComm.LIMBTYPE[AppData.Instance.userData.useHand]);
                    return;
                }
                 calibState = CALIBSTATES.CALIBRATE;
                break;

            case CALIBSTATES.CALIBRATE:
                if (MarsComm.CALIBRATION[MarsComm.calibration] == "NOCALIB")
                {
                    if (MarsComm.COMMAND_STATUS[MarsComm.recentCommandStatus] == "FAIL")
                    {
                        messageTxt.text = "CHECK MARS ANGLES";
                    }
                    MarsComm.calibrate();
                    return;
                }
                calibState = CALIBSTATES.SETLIMBKINPARA;
                break;
          
            case CALIBSTATES.SETLIMBKINPARA:
                if(MarsComm.CALIBRATION[MarsComm.calibration] == "NOCALIB")
                    calibState = CALIBSTATES.CALIBRATE;
                Debug.Log(MarsKinDynamics.ForwardKinematicsExtended(MarsComm.angle1, MarsComm.angle2, MarsComm.angle3, MarsComm.angle4));
                messageTxt.text = "HIT CALIB BUTTON TO SET LIMB PARASMETERS";
                if (endpointCount < MAX_ENDPOINTS && MarsComm.calibButton == 0)
                {
                    endpointPositions[endpointCount] = MarsKinDynamics.ForwardKinematicsExtended(MarsComm.angle1, MarsComm.angle2, MarsComm.angle3, MarsComm.angle4);
                    endpointCount++;
                }
                else
                {
                    endpointCount = 0;
                }
                break;
            case CALIBSTATES.ALLDONE:
                messageTxt.text = "HIT MARS BUTTON TO CHANGE SCENE";
                kinTick.enabled = true;
                break;
            case CALIBSTATES.CHANGESCENE:

                //check need to calibrater or not
                if (AppData.Instance.transitionControl.isDynLimbParamExist)
                {
                    SceneManager.LoadScene("CHOOSEMOVEMENT");

                }
                else
                {
                    SceneManager.LoadScene("WEIGHTEST");

                }

                break;
        }

    }
    private void initUI()
    {
        limbTick.enabled = false;
        calibTick.enabled = false;
        kinTick.enabled = false;
        MarsComm.setLimb("NOLIMB");
    }
    private void updataUI()
    {
       
        calibTxt.text = $"CALIB : {MarsComm.CALIBRATION[MarsComm.calibration]}";
        kinParaTxt.text = $"KIN-PARAM: \n\t{MarsComm.uaLength}m\n\t{MarsComm.faLength}m\n\t{MarsComm.shPosZ}";
        calibTick.enabled = MarsComm.CALIBRATION[MarsComm.calibration] != "NOCALIB";

    }
    public void redoKinParamSet()
    {
        if (calibState != CALIBSTATES.ALLDONE)
            return;
        calibState = CALIBSTATES.SETLIMBKINPARA;
        kinTick.enabled = false;
    }
    private void OnDestroy()
    {
        MarsComm.OnMarsButtonReleased -= onMarsButtonReleased;
    }
    private void OnApplicationQuit()
    {

        Application.Quit();
        JediComm.Disconnect();
    }
}
