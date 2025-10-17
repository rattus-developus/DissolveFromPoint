using UnityEngine;

/*
    This is a minimalist script to control the Dissolve shader automatically, all that's needed is a time/duration for the dissolving to take place over.
*/

public class DissolveManual : MonoBehaviour
{
    [SerializeField] Transform dissolveTran;
    [SerializeField] GameObject dissolveObj;

    void Update()
    {
        if (dissolveTran == null || dissolveObj == null) return;
        Vector3 localPos = dissolveObj.transform.InverseTransformPoint(dissolveTran.position);
        dissolveObj.GetComponent<Renderer>().material.SetVector("_dissPoint", localPos);
    }
}
