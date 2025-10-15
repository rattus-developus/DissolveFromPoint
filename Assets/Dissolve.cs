using UnityEngine;

//This is a simple script to dynamically control the dissolve point. It uses it's own position as the dissolve point for the targeted object's material

public class Dissolve : MonoBehaviour
{
    [SerializeField] Transform target;

    void Update()
    {
        target.GetComponent<Renderer>().material.SetVector("_dissolvePoint", transform.position);
    }
}
