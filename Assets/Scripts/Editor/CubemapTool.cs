using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using System.IO;
using System;

public class CubemapTool : EditorWindow
{
    private Cubemap cubemap = null;
    private Material material = null;
    private Camera renderCam = null;
    private Transform renderPos;
    
    private string path;

    [MenuItem("Tool/Cube Map Generate")]
    public static void GenerateCubemap()
    {
        GetWindow<CubemapTool>();
    }

    private void OnGUI()
    {
        cubemap = EditorGUILayout.ObjectField("Cubemap", cubemap, typeof(Cubemap), true, GUILayout.Width(400)) as Cubemap;
        material = EditorGUILayout.ObjectField("Material", material, typeof(Material), true, GUILayout.Width(400)) as Material;
        //renderTex = EditorGUILayout.ObjectField("RenderTexture", renderTex, typeof(RenderTexture), true, GUILayout.Width(400)) as RenderTexture;
        renderPos = EditorGUILayout.ObjectField("Render Position", renderPos, typeof(Transform), true, GUILayout.Width(400)) as Transform;
        renderCam = EditorGUILayout.ObjectField("Render Camera", renderCam, typeof(Camera), true, GUILayout.Width(400)) as Camera;
        /*
        if (GUILayout.Button("Select Output"))
        {
            path = EditorUtility.OpenFolderPanel("select output", path, "Assets");
            int index = path.IndexOf("Assets");
            if(index >= 0)
            {
                path = path.Substring(index, path.Length - index);
            }
        }*/

        if (GUILayout.Button("Generate To Cubemap")){
           
            if (!renderCam)
            {
                
                GameObject g = new GameObject("RenderGo");
                g.transform.position = renderPos.position;
                g.transform.rotation = Quaternion.identity;
                renderCam = g.AddComponent<Camera>();
                //renderCam.farClipPlane = 5;
                if (material)
                {
                    Skybox skybox = g.AddComponent<Skybox>();                  
                    skybox.material = material;
                }

                renderCam.RenderToCubemap(cubemap);
                DestroyImmediate(g);
      
            }
            else
            {
                if (material)
                {
                    
                    Skybox skybox = renderCam.gameObject.GetComponent<Skybox>();
                    if (!skybox)
                    {
                        skybox = renderCam.gameObject.AddComponent<Skybox>();
                    }
                    skybox.material = material;
                }       
                renderCam.RenderToCubemap(cubemap);
                
            }
            EditorUtility.DisplayDialog("tip", "Done!", "ok");

            /*
            if (!string.IsNullOrEmpty(path))
            {
                material.SetTexture("_Skybox", cubemap);
                material.SetFloat("_SamplerDelta", 0.025f);
                RenderTexture tem = RenderTexture.active;
                RenderTexture renderTex = new RenderTexture(256, 256, 0);

                renderTex.enableRandomWrite = true;
                renderTex.dimension = TextureDimension.Tex3D;
                if (!renderTex.IsCreated())
                {
                    renderTex.Create();
                }
                RenderTexture.active = renderTex;
                Graphics.Blit(cubemap, renderTex, material);

                if (!Directory.Exists(path))
                {
                    Directory.CreateDirectory(path);
                }

                if (!AssetDatabase.Contains(renderTex))
                {
                    AssetDatabase.CreateAsset(renderTex, path + "/Irradiance.renderTexture");
                }
                else
                {
                    AssetDatabase.AddObjectToAsset(renderTex, path + "/Irradiance.renderTexture");
                }
                //renderTex.Release();

                AssetDatabase.ImportAsset(path);
                AssetDatabase.Refresh();
                RenderTexture.active = tem;
                EditorUtility.DisplayDialog("tip", "Done!", "ok");
            }
            else
            {
                EditorUtility.DisplayDialog("tip", "Please select one output folder!", "ok");
            }
            */

        }
        /*
        if (!string.IsNullOrEmpty(path))
        {
            GUILayout.Label("Output Dir" + path);
        }*/
    }

}
