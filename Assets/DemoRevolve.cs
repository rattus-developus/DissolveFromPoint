using UnityEngine;

public class DemoRevolve : MonoBehaviour
{
    [SerializeField] Transform revolver;
    [SerializeField] float radius = 0.5f;

    void Start()
    {
        radius = Vector3.Distance(transform.position, revolver.position);
    }
    
    void Update()
    {
        Vector3 offset = Vector3.zero;
        
        revolver.transform.position = transform.position + offset;
    }
}
