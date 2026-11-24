using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Windows.Forms;

class Program
{
    private static HttpListener listener;
    private static string webRoot;
    private static bool isRunning = true;

    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            // Determine directory where Dawami.exe is running
            string appDir = AppDomain.CurrentDomain.BaseDirectory;
            
            // Search for web files
            string[] candidatePaths = new string[]
            {
                Path.Combine(appDir, "data", "web"),
                Path.Combine(appDir, "web"),
                Path.Combine(appDir, "..", "build", "web"),
                Path.Combine(appDir, "..", "..", "build", "web")
            };

            foreach (string p in candidatePaths)
            {
                if (Directory.Exists(p) && File.Exists(Path.Combine(p, "index.html")))
                {
                    webRoot = Path.GetFullPath(p);
                    break;
                }
            }

            if (string.IsNullOrEmpty(webRoot))
            {
                MessageBox.Show(
                    "لم يتم العثور على ملفات واجهة النظام (web/index.html).\nيرجى التأكد من اكتمال مجلد التطبيق.",
                    "دوامي - خطأ في التشغيل",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            // Find an open port
            int port = GetAvailablePort();
            string url = string.Format("http://127.0.0.1:{0}/", port);

            // Start embedded local HTTP server
            listener = new HttpListener();
            listener.Prefixes.Add(url);
            listener.Start();

            Thread serverThread = new Thread(ListenLoop);
            serverThread.IsBackground = true;
            serverThread.Start();

            // Find Microsoft Edge executable
            string edgePath = GetEdgeExecutablePath();
            string profileDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DawamiApp",
                "BrowserData");

            Directory.CreateDirectory(profileDir);

            ProcessStartInfo psi = new ProcessStartInfo();
            if (!string.IsNullOrEmpty(edgePath) && File.Exists(edgePath))
            {
                psi.FileName = edgePath;
                psi.Arguments = string.Format(
                    "--app=\"{0}\" --user-data-dir=\"{1}\" --window-size=1360,850 --no-first-run --no-default-browser-check",
                    url,
                    profileDir);
            }
            else
            {
                psi.FileName = url;
                psi.UseShellExecute = true;
            }

            Process browserProcess = Process.Start(psi);
            if (browserProcess != null)
            {
                browserProcess.WaitForExit();
            }

            isRunning = false;
            try { listener.Stop(); } catch { }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "حدث خطأ أثناء تشغيل دوامي: " + ex.Message,
                "دوامي",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private static int GetAvailablePort()
    {
        TcpListener l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        int port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    private static string GetEdgeExecutablePath()
    {
        string[] candidates = new string[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft", "Edge", "Application", "msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Microsoft", "Edge", "Application", "msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "Edge", "Application", "msedge.exe")
        };

        foreach (string path in candidates)
        {
            if (File.Exists(path))
            {
                return path;
            }
        }
        return null;
    }

    private static void ListenLoop()
    {
        while (isRunning)
        {
            try
            {
                HttpListenerContext context = listener.GetContext();
                ThreadPool.QueueUserWorkItem((state) => HandleRequest((HttpListenerContext)state), context);
            }
            catch
            {
                if (!isRunning) break;
            }
        }
    }

    private static void HandleRequest(HttpListenerContext context)
    {
        try
        {
            string rawUrl = context.Request.Url.AbsolutePath;
            if (rawUrl == "/" || string.IsNullOrEmpty(rawUrl))
            {
                rawUrl = "/index.html";
            }

            rawUrl = Uri.UnescapeDataString(rawUrl).TrimStart('/');
            string filePath = Path.Combine(webRoot, rawUrl.Replace('/', Path.DirectorySeparatorChar));

            if (!File.Exists(filePath))
            {
                // Fallback to index.html for SPA routing
                filePath = Path.Combine(webRoot, "index.html");
            }

            byte[] bytes = File.ReadAllBytes(filePath);
            string contentType = GetContentType(filePath);

            context.Response.ContentType = contentType;
            context.Response.ContentLength64 = bytes.Length;
            context.Response.AddHeader("Cache-Control", "no-cache");
            context.Response.OutputStream.Write(bytes, 0, bytes.Length);
            context.Response.OutputStream.Close();
        }
        catch
        {
            try { context.Response.StatusCode = 500; context.Response.Close(); } catch { }
        }
    }

    private static string GetContentType(string path)
    {
        string ext = Path.GetExtension(path).ToLowerInvariant();
        switch (ext)
        {
            case ".html": return "text/html; charset=utf-8";
            case ".js": return "application/javascript; charset=utf-8";
            case ".wasm": return "application/wasm";
            case ".json": return "application/json";
            case ".css": return "text/css; charset=utf-8";
            case ".png": return "image/png";
            case ".jpg":
            case ".jpeg": return "image/jpeg";
            case ".svg": return "image/svg+xml";
            case ".ico": return "image/x-icon";
            case ".otf": return "font/otf";
            case ".ttf": return "font/ttf";
            case ".woff": return "font/woff";
            case ".woff2": return "font/woff2";
            default: return "application/octet-stream";
        }
    }
}
