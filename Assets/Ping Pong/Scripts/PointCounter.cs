using UnityEngine;
using UnityEngine.UI;
using System.Collections;

public class PointCounter : MonoBehaviour {

	public GameObject rightBound;
	public GameObject leftBound;
	Text text;
	// Use this for initialization
	void Start () {
		text = GetComponent<Text>();
		text.text = BoundController.enemyScore + "\t\t" + 
			BoundController.playerScore;
	}
	
	// Update is called once per frame
	void Update () {
	
		text.text = BoundController.enemyScore + "\t\t" + 
			BoundController.playerScore;
	}
}
