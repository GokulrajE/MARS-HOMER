using System.Text.RegularExpressions;
using TMPro;
using Unity.VisualScripting;
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
   
  
    public Image calibTick;
    public Text calibTxt;
    public Text kinParaTxt;
    public Image kinTick;
    public Text messageTxt;
    public GameObject CalibSetupImg;
    public GameObject kinSetupImg;
    public TMP_InputField faLength;
    public TMP_InputField uaLength;
    public Button setLenght;
  
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
        messageTxt.text = "Press the MARS button to start calibration. Before proceeding, ensure the MARS device orientation matches the image shown";
        
        AppLogger.SetCurrentScene(SceneManager.GetActiveScene().name);
        AppLogger.LogInfo($"{SceneManager.GetActiveScene().name} scene started.");
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        MarsComm.OnCalibButtonReleased += onCalibButtonReleased;
        MarsComm.onHumanLimbKinParamData += OnHumanLimbKinParamData;
        calibState = CALIBSTATES.SETUPLIMB;
        initUI()
;    }

    void Update()
    {
        //To open Weight Estimation Scene
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.A))
        {
             if(calibState == CALIBSTATES.ALLDONE)
                SceneManager.LoadScene("WEIGHTEST");
        }

        //change length of Arm
        if (Input.GetKey(KeyCode.LeftControl) && Input.GetKeyDown(KeyCode.L))
        {
            setLenght.gameObject.SetActive(!setLenght.IsActive());
        }

        MarsComm.sendHeartbeat();
        RunCalibStateMachine();
       
    }
   
    public void onMarsButtonReleased()
    {
        switch (calibState)
        {
            
            case CALIBSTATES.SETUPLIMB:
                calibState = CALIBSTATES.CALIBRATE;
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
            setHLimbKinUALength = (float)AppData.Instance.userData.uaLength;
            setHLimbKinFALength = (float)AppData.Instance.userData.faLength;
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
                 
                break;

            case CALIBSTATES.CALIBRATE:
                if (MarsComm.CALIBRATION[MarsComm.calibration] == "NOCALIB")
                {
                    if (MarsComm.COMMAND_STATUS[MarsComm.recentCommandStatus] == "FAIL")
                    {
                        messageTxt.text = "Check that the MARS device looks exactly like the image (straight and properly aligned)";
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
                messageTxt.text = "Perform the procedure as illustrated, then press the calibration button in the MARS device.";
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
                messageTxt.text = "You can redo the parameter setup, or press the MARS button to move to the next step.";
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
      
        calibTick.enabled = false;
        kinTick.enabled = false;
        CalibSetupImg.gameObject.SetActive(false);
        kinSetupImg.gameObject.SetActive(false);
        panel.gameObject.SetActive(false);
        MarsComm.setLimb("NOLIMB");
        setLenght.gameObject.SetActive(false);

        //change Lenght of Arm Dynamically
        setLenght.onClick.AddListener(delegate
        {
            AppData.Instance.userData.setFALength(float.Parse(faLength.text));
            AppData.Instance.userData.setUALength(float.Parse(uaLength.text));
            setLenght.gameObject.SetActive(!setLenght.IsActive());
        });

    }
    private void updataUI()
    {
        string calibStatus = MarsComm.calibration == 1 ? "DONE" : "CALIBRATE";
        calibTxt.text = $"STATUS : {calibStatus}";
        kinParaTxt.text = $"KIN-PARAM: \n\t{MarsComm.uaLength}m\n\t{MarsComm.faLength}m\n\t{MarsComm.shPosZ}";
        calibTick.enabled = MarsComm.CALIBRATION[MarsComm.calibration] != "NOCALIB";
        CalibSetupImg.SetActive(calibState == CALIBSTATES.CALIBRATE || calibState == CALIBSTATES.SETUPLIMB);
        kinSetupImg.SetActive(calibState == CALIBSTATES.SETLIMBKINPARA);
        panel.SetActive( calibState == CALIBSTATES.ALLDONE);

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
