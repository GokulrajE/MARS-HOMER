using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class ButtonClickAuto : MonoBehaviour
{
    // Start is called before the first frame update
    public void AutoGamePlay()
    {
        SceneManager.LoadScene("FlappyGame");
    }

    public void HomeSceneLoad()
    {
        SceneManager.LoadScene("Main scene");
    }

}
