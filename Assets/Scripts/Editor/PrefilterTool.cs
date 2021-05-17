using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using System.IO;
using UnityEngine.UI;

public class PrefilterTool : EditorWindow
{
    private Cubemap skybox = null;
    //private RenderTexture prefilter = null;
    private Material material = null;
    private string path;
    //[Range(0.0f, 1.0f)]
    private float roughness;

    [MenuItem("Tool/Prefilter Map Generate")]
    public static void GeneratePrefilter()
    {
        GetWindow<PrefilterTool>();
    }

    private void OnGUI()
    {
        skybox = EditorGUILayout.ObjectField("Skybox", skybox, typeof(Cubemap), true, GUILayout.Width(400)) as Cubemap;
        material = EditorGUILayout.ObjectField("Material", material, typeof(Material), true, GUILayout.Width(400)) as Material;
        //prefilter = EditorGUILayout.ObjectField("RenderTexture", prefilter, typeof(RenderTexture), true, GUILayout.Width(400)) as RenderTexture; 
        roughness = EditorGUILayout.Slider("Roughness", roughness, 0, 1);
        
        if (GUILayout.Button("Select Output"))
        {
            path = EditorUtility.OpenFolderPanel("select output", path, "Assets");
            int index = path.IndexOf("Assets");
            if (index >= 0)
            {
                path = path.Substring(index, path.Length - index);
            }
        }

        if (GUILayout.Button("Generate Prefilter Map"))
        {
 
            if (!string.IsNullOrEmpty(path))
            {
                material.SetTexture("_Skybox", skybox);
                material.SetFloat("_Roughness", roughness);
                RenderTexture prefilter = new RenderTexture(512, 512, 0);
                RenderTexture tem = RenderTexture.active;
                prefilter.enableRandomWrite = true;
                prefilter.dimension = TextureDimension.Tex3D;
                if (!prefilter.IsCreated())
                {
                    prefilter.Create();
                }               
                RenderTexture.active = prefilter;
                Graphics.Blit(skybox, prefilter, material);

                if (!Directory.Exists(path))
                {
                    Directory.CreateDirectory(path);
                }

                if (!AssetDatabase.Contains(prefilter))
                {
                    AssetDatabase.CreateAsset(prefilter, path + "/prefilter_" + roughness + ".renderTexture");
                }
                else
                {
                    AssetDatabase.AddObjectToAsset(prefilter, path + "/prefilter_" + roughness + ".renderTexture");
                }
                
                AssetDatabase.ImportAsset(path);
                AssetDatabase.Refresh();
                RenderTexture.active = tem;
                EditorUtility.DisplayDialog("tip", "Done!", "ok");
            }
            else
            {
                EditorUtility.DisplayDialog("tip", "Please select one output folder!", "ok");
            }


        }
        
        if (!string.IsNullOrEmpty(path))
        {
            GUILayout.Label("Output Dir" + path);
        }
    }
}
