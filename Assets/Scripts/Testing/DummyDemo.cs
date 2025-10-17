using UnityEngine;

public class DummyDemo : MonoBehaviour
{
    [SerializeField] float explosionForce = 5f;
    [SerializeField] Transform explosionPoint;
    [SerializeField] DissolveHelper helper;
    [SerializeField] GameObject line;
    bool active;

    void Update()
    {
        if(!active && Time.time > 5f)
        {
            active = true;
            GetComponent<Rigidbody>().AddExplosionForce(explosionForce, explosionPoint.position, 0.5f);
            helper.StartDissolve(explosionPoint.position);
            explosionPoint.GetComponent<Renderer>().enabled = false;
            line.SetActive(false);
        }
    }
}
