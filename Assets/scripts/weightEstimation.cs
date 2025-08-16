
using System.Linq;
using UnityEngine;
using System;
using UnityEngine.UI;
using System.IO;
using System.Text;
using UnityEngine.SceneManagement;
public class weightEstimation : MonoBehaviour
{
    private byte stateMachineFlags = 0x00;
    public Text hlbDynParamSetText;
    public Text messageText;
    public Image limDynParaTick;
   
    public Slider AWSTest;
    public Text sliderVal;
    // Dynamic parameter estimation variables.
    private enum LimbDynEstState
    {
        WAITFORSTART = 0x00,
        SETUPFORESTIMATION = 0x01,
        WAITFORESTIMATION = 0x02,
        ESTIMATE = 0x03,
        ESTIMATIONDONE = 0x04,
        WAITFORHOLDTEST = 0x05,
        HOLDTEST = 0x06,
        ALLDONE = 0x07,
        CHANGESECNE = 0x08
    }
    private LimbDynEstState hLimbDynEstState = LimbDynEstState.WAITFORSTART;
   
    private const int nParams = 2;
    private const int maxParamEstimates = 250;
    private RecursiveLeastSquares rlsHLimbWeights = new RecursiveLeastSquares(nParams);
    private float[,] weightParams = new float[maxParamEstimates, nParams];
    private int weightParamsIndex = 0;
    private float[] weightParamsMean = new float[nParams];
    private float[] weightParamsStdev = new float[nParams];

    private float setHLimbDynUAWeight = 0.0f;
    private float setHLimbDynFAWeight = 0.0f;
    // Start is called before the first frame update
    void Start()
    {
        MarsComm.onHumanLimbDynParamData += OnHumanLimbDynParamData;
        MarsComm.OnMarsButtonReleased += onMarsButtonReleased;
        messageText.text = "HIT Mars BUtton To SetUp";
        limDynParaTick.enabled = false;
      
    }

    // Update is called once per frame
    void Update()
    {
      
        MarsComm.sendHeartbeat();
        RunHumanLimbDynParamEstimation();
       
    }
   
    private void RunHumanLimbDynParamEstimation()
    {
        if (hLimbDynEstState == LimbDynEstState.WAITFORSTART ) return;
       
        switch (hLimbDynEstState)
        {
            case LimbDynEstState.SETUPFORESTIMATION:
                // Wait for the start of the estimation.
                handleSetupDynParamEstimation();
                // Check statemachine flag
                if ((stateMachineFlags & 0x01) == 0x01)
                {
                    hLimbDynEstState = LimbDynEstState.WAITFORESTIMATION;
                }
                break;
            case LimbDynEstState.WAITFORESTIMATION:
                messageText.text = "HIT BUTTON TO START ESTIMATION";
                if (AppData.Instance.transitionControl.readyToChange)
                {
                    messageText.text = "HIT BUTTON TO START ESTIMATION";
                }
                else
                {
                    messageText.text = "Please fit the Arm with Mars";
                }
                // Check statemachine flag
                if ((stateMachineFlags & 0x02) == 0x02)
                {
                    hLimbDynEstState = LimbDynEstState.ESTIMATE;
                }
                break;
            case LimbDynEstState.ESTIMATE:
                // Update the estimtate if parameters are not yet estimated.
                rlsHLimbWeights.Update(new float[] {
                    (float) (Math.Sin(MarsComm.phi1 * Mathf.Deg2Rad) * Math.Cos(MarsComm.phi2 * Mathf.Deg2Rad)),
                    (float) (Math.Sin(MarsComm.phi1 * Mathf.Deg2Rad) * Math.Cos((MarsComm.phi2 - MarsComm.phi3) * Mathf.Deg2Rad))
                }, MarsComm.torque);
                // Check if we need to change state.
                if (computeMeanAndStdev())
                {
                    hLimbDynEstState = LimbDynEstState.ESTIMATIONDONE;
                }
                break;
            case LimbDynEstState.ESTIMATIONDONE:
               
                if ((stateMachineFlags & 0x04) == 0x04)
                {
                    limDynParaTick.enabled = true;
                    // Check statemachine flag
                    hLimbDynEstState = LimbDynEstState.WAITFORHOLDTEST;
                }
                else
                {
                    // Send the weight parameters to MARS.
                    Debug.Log("Setting human limb dynamic parameters: " +
                        $"UA Weight = {weightParamsMean[0]:F3}, FA Weight = {weightParamsMean[1]:F3}");
                    setHLimbDynUAWeight = weightParamsMean[0];
                    setHLimbDynFAWeight = weightParamsMean[1];
                    MarsComm.setHumanLimbDynParams(setHLimbDynUAWeight, setHLimbDynFAWeight);
                    // Get the human limb dynamic parameters from MARS.
                    MarsComm.getHumanLimbDynParams();
                }
                break;
            case LimbDynEstState.WAITFORHOLDTEST:
                messageText.text = "HIT BUTTON TO TEST MARS HOLD ARM WITH FWS";
                // Check statemachine flag
                if ((stateMachineFlags & 0x08) == 0x08)
                {
                    hLimbDynEstState = LimbDynEstState.HOLDTEST;
                }
                break;
            case LimbDynEstState.HOLDTEST:
                // Perform hold testing with the estimated weights.
                // Check the current control type.
                onSliderValueChange();
                messageText.text = "HIT BUTTON TO FINISH AWS WEIGHT TEST";
                if (MarsComm.CONTROLTYPE[MarsComm.controlType] != "AWS")
                {
                    // Set the control mode to AWS.
                    MarsComm.transitionControl("AWS", 1.0f, 5.0f);
                }
                // Check statemachine flag
                if ((stateMachineFlags & 0x10) == 0x10)
                {
                   
                    hLimbDynEstState = LimbDynEstState.ALLDONE;
                }
                break;
            case LimbDynEstState.ALLDONE:
                // Handle all done.
                messageText.text = "HIT BUTTON TO CHANGE THE SCENE OR CLICK REDO";
                // Wait for the start of the estimation.
                if (MarsComm.CONTROLTYPE[MarsComm.controlType] != "POSITION")
                {
                    // Set the control mode to AWS.
                    MarsComm.transitionControl("POSITION", -90f, 5.0f);
                }
                else
                {
                    //hLimbDynEstState = LimbDynEstState.WAITFORSTART;
                }
                break;
            case LimbDynEstState.CHANGESECNE:
                SceneManager.LoadScene("CHOOSEMOVEMENT");
                break;
        }
    }
   
    public void changeDynLimbStates()
    {
        switch (hLimbDynEstState)
        {
            case LimbDynEstState.WAITFORSTART:
                hLimbDynEstState = LimbDynEstState.SETUPFORESTIMATION;
                break;
            case LimbDynEstState.WAITFORESTIMATION:
                // Check if we are in the appropriate state.
                if (!AppData.Instance.transitionControl.readyToChange)
                    return;
                if (hLimbDynEstState == LimbDynEstState.WAITFORESTIMATION)
                {
                    stateMachineFlags = (byte)(stateMachineFlags | 0x02);
                }
                break;
            case LimbDynEstState.WAITFORHOLDTEST:
                // Check if we are in the appropriate state.
                if (hLimbDynEstState == LimbDynEstState.WAITFORHOLDTEST)
                {
                    stateMachineFlags = (byte)(stateMachineFlags | 0x08);
                }
                break;
            case LimbDynEstState.HOLDTEST:
                // Check if we are in the appropriate state.
                if (hLimbDynEstState == LimbDynEstState.HOLDTEST)
                {
                    stateMachineFlags = (byte)(stateMachineFlags | 0x10);
                }
                break;
            case LimbDynEstState.ALLDONE:
                hLimbDynEstState = LimbDynEstState.CHANGESECNE;
                break;
        }
    }
    private bool computeMeanAndStdev()
    {
        bool[] _done = new bool[nParams];
        for (int _i = 0; _i < nParams; _i++)
        {
            weightParams[weightParamsIndex, _i] = rlsHLimbWeights.theta[_i];
        }
        weightParamsIndex = (weightParamsIndex + 1) % maxParamEstimates;
        // Display the parameters mean and standard deviation.
        hlbDynParamSetText.text = "";
        for (int _i = 0; _i < nParams; _i++)
        {
            weightParamsMean[_i] = 0f;
            weightParamsStdev[_i] = 0f;
            for (int _j = 0; _j < maxParamEstimates; _j++)
            {
                weightParamsMean[_i] += weightParams[_j, _i];
            }
            weightParamsMean[_i] /= maxParamEstimates;
            for (int _j = 0; _j < maxParamEstimates; _j++)
            {
                weightParamsStdev[_i] += Mathf.Pow(weightParams[_j, _i] - weightParamsMean[_i], 2);
            }
            weightParamsStdev[_i] = Mathf.Sqrt(weightParamsStdev[_i] / maxParamEstimates);

            // Add parameter mean +/- stdev to the text.
            float _variation = 100 * weightParamsStdev[_i] / Math.Abs(weightParamsMean[_i]);
            hlbDynParamSetText.text += $"{_i + 1}: {weightParamsMean[_i]:F3} +/- {weightParamsStdev[_i]:F3} [{_variation:F3}]\n";
            _done[_i] = _variation < 5f;
        }
        return _done.All(x => x);
    }
  
    private void handleSetupDynParamEstimation()
    {
        // Check if the control mode is position, else set and leave.
        if (MarsComm.CONTROLTYPE[MarsComm.controlType] != "POSITION")
        {
            MarsComm.setControlType("POSITION");
            MarsComm.setControlTarget(-90f);
            return;
        }
        // Check if the target position is set to -90 degrees.
        if (MarsComm.target != -90f)
        {
            MarsComm.setControlTarget(-90f);
            return;
        }
        // Check if the robot has reached the target position.
        if (Mathf.Abs(MarsComm.angle1 - MarsComm.target) < 2.5)
        {
            if (hLimbDynEstState == LimbDynEstState.SETUPFORESTIMATION)
            {
                stateMachineFlags = (byte)(stateMachineFlags | 0x01);
                rlsHLimbWeights.ResetEstimator();
            }
        }
    }
    private void OnHumanLimbDynParamData()
    {
        // Check if the human limb dynamics parameters match the set values.
        if (MarsComm.limbDynParam != 0x01 || MarsComm.uaWeight != setHLimbDynUAWeight || MarsComm.faWeight != setHLimbDynFAWeight)
        {
            Debug.LogWarning("Human limb dynamic parameters are not set correctly.");
            MarsComm.resetHumanLimbDynParams();
            stateMachineFlags = (byte)(stateMachineFlags & 0xFB);
        }
        else
        {
            Debug.Log("Human limb dynamic parameters are set correctly.");
            stateMachineFlags = (byte)(stateMachineFlags | 0x04);
            if (!AppData.Instance.transitionControl.newhLimbDynWeights.isParamSet)
                AppData.Instance.transitionControl.saveParameters(setHLimbDynUAWeight, setHLimbDynFAWeight);
        }
    }
    public void redoDynLimbEstimation()
    {
        if (hLimbDynEstState != LimbDynEstState.ALLDONE && MarsComm.LIMBDYNPARAM[MarsComm.limbDynParam]!= "YESLIMBKINPARAM") return;
        //Reset states
        hLimbDynEstState = LimbDynEstState.SETUPFORESTIMATION;
        MarsComm.resetHumanLimbDynParams();
        AppData.Instance.transitionControl.restParameters();
        stateMachineFlags = 0x00;
        limDynParaTick.enabled = false;
    }
   
   public void onClickCheckTc()
   {
        if (hLimbDynEstState != LimbDynEstState.HOLDTEST) return;
        MarsComm.setControlTarget(AWSTest.value, dur: 6f);
   } 
    public void onSliderValueChange()
    {
        sliderVal.text =$"GAIN-{AWSTest.value.ToString("F1")} -- {MarsComm.COMMAND_STATUS[MarsComm.recentCommandStatus]}" ;
    }
    private void onMarsButtonReleased()
    {
        changeDynLimbStates();
    }

}
