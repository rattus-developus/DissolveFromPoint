using UnityEngine;

/*
    This is a minimalist script to control the Dissolve shader automatically, all that's needed is a time/duration for the dissolving to take place over.
*/

public class DissolveHelper : MonoBehaviour
{
    [Tooltip("This string holds the player's name.")]
    [SerializeField] float dissolveTime;
    [ColorUsage(true, true)] public Color hdrColor;
    bool dissolving;
    float timer;

    public void StartDissolve(Vector3 dissolvePointWorld, float duration = -1f)
    {
        if (duration != -1f) dissolveTime = duration;
        SetShaderProperties(transform.InverseTransformPoint(dissolvePointWorld), duration);
        dissolving = true;
    }

    void StopDissolve()
    {
        dissolving = false;
    }

    public void Reset()
    {
        timer = 0f;
        SetShaderProgress();
    }

    void SetShaderProperties(Vector3 dissolvePointLocal, float duration)
    {
        if (!GetComponent<MeshFilter>() || !GetComponent<Renderer>()) return;

        //Use mesh bounds to approximate a bounding sphere, used as the radius
        float radius = GetComponent<MeshFilter>().mesh.bounds.extents.magnitude + dissolvePointLocal.magnitude;

        GetComponent<Renderer>().sharedMaterial.SetFloat("_dissRadius", radius);
        GetComponent<Renderer>().sharedMaterial.SetVector("_dissPoint", dissolvePointLocal);
        GetComponent<Renderer>().sharedMaterial.SetColor("_glowColor", hdrColor);
    }

    void Update()
    {
        if (!dissolving) return;
        
        timer += Time.smoothDeltaTime;
        SetShaderProgress();
        if(timer >= dissolveTime) StopDissolve();
    }

    void SetShaderProgress()
    {
        if (!GetComponent<Renderer>()) return;
        GetComponent<Renderer>().sharedMaterial.SetFloat("_dissProgress", timer / dissolveTime);
    }
}
