using UnityEngine;

public class DissolveTest : MonoBehaviour
{
    [SerializeField] DissolveHelper dissHelper;
    [SerializeField] Transform testPos;
    [SerializeField] bool dissolve;

    void Update()
    {
        if(dissolve)
        {
            dissolve = false;
            dissHelper.Reset();
            dissHelper.StartDissolve(testPos.position);
        }
    }
}
