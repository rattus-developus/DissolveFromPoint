using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class StressTest : MonoBehaviour
{
    [SerializeField] GameObject testObj;
    [SerializeField] int2 testDimensions;
    [SerializeField] float testSpacing = 2f;
    List<Material> testMats = new List<Material>();

    void Start()
    {
        SpawnTestObjects();
    }

    void SpawnTestObjects()
    {
        for (int i = 0; i < testDimensions.x; i++)
        {
            for (int j = 0; j < testDimensions.y; j++)
            {
                GameObject obj = Instantiate(testObj);
                testObj.transform.position = new Vector3(i * testSpacing, 2f, j * testSpacing);
                testMats.Add(obj.GetComponent<Renderer>().material);
            }
        }
    }
}
