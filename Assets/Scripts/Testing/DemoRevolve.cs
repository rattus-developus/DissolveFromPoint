using UnityEngine;

public class DemoRevolve : MonoBehaviour
{
    [SerializeField] Transform revolver;
    [SerializeField] float radius = 0.5f;
    [SerializeField] float speed = 1f;

    void Start()
    {
        radius = Vector3.Distance(transform.position, revolver.position);
    }
    
    void Update()
    {
        Vector3 offset = Vector3.zero;

        offset.x = Mathf.Sin(Time.time * speed) * radius;
        offset.z = Mathf.Cos(Time.time * speed) * radius;
        
        revolver.transform.position = transform.position + offset;
    }
}
