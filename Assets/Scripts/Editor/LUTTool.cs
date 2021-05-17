using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;

public class LUTTool : EditorWindow
{
    private RenderTexture lut;
    private Material material;
    private string path;
    private string subPath;
    
    [MenuItem("Tool/LUT Generate")]
    public static void GenerateLUT()
    {
        GetWindow<LUTTool>();
    }

    private void OnGUI()
    {
        material = EditorGUILayout.ObjectField("Material", material, typeof(Material), true, GUILayout.Width(400)) as Material;
        if (GUILayout.Button("Select Output"))
        {
            path = EditorUtility.OpenFolderPanel("select output", path, "Assets");
            int index = path.IndexOf("Assets");
            if (index >= 0)
            {
                subPath = path.Substring(index, path.Length - index);
            }
        }

        if (GUILayout.Button("Generate Prefilter Map"))
        {
  
            if (!string.IsNullOrEmpty(subPath))
            {
                lut = new RenderTexture(512, 512, 24);
                lut.enableRandomWrite = true;
                if (!lut.IsCreated())
                {
                    lut.Create();
                }
                
                Graphics.Blit(lut, lut, material);

                if (!Directory.Exists(path))
                {
                    Directory.CreateDirectory(path);
                }
                CreateTexture(path, lut);
                /*
                if (!AssetDatabase.Contains(lut))
                {
                    AssetDatabase.CreateAsset(lut, subPath + "/LUT.png");
                }
                else
                {
                    AssetDatabase.AddObjectToAsset(lut, subPath + "/LUT.png");
                }
                */
                AssetDatabase.Refresh();
                EditorUtility.DisplayDialog("tip", "Done!", "ok");
            }
            else
            {
                EditorUtility.DisplayDialog("tip", "Please select one output folder!", "ok");
            }


        }

        if (!string.IsNullOrEmpty(subPath))
        {
            GUILayout.Label("Output Dir" + subPath);
        }
    }

    void CreateTexture(string path, RenderTexture rt)
    {
        RenderTexture tem = RenderTexture.active;
        RenderTexture.active = rt;
        Texture2D lut = new Texture2D(rt.width, rt.height, TextureFormat.ARGB32, false);
        lut.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        byte[] bytes = lut.EncodeToPNG();
        FileStream filestream = File.Open(path + "/LUT.png", FileMode.Create);
        BinaryWriter writer = new BinaryWriter(filestream);
        writer.Write(bytes);
        filestream.Close();
        Texture.DestroyImmediate(lut);
        RenderTexture.active = tem;
    }
}
