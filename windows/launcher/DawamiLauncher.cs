using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("دوامي - نظام إدارة حضور وغياب الطلاب الذكي")]
[assembly: AssemblyDescription("نظام دوامي لإدارة الحضور والانصراف بالتعرف على الوجه وبصمة الإصبع والباركود - جامعة دنقلا")]
[assembly: AssemblyCompany("جامعة دنقلا - Dawami Systems")]
[assembly: AssemblyProduct("Dawami دوامي")]
[assembly: AssemblyCopyright("Copyright (C) 2026 جامعة دنقلا - كلية علوم الحاسوب والتنمية البشرية")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

class Program
{
    private static HttpListener listener;
    private static string webRoot;
    private static bool isRunning = true;
    private static NotifyIcon trayIcon;
    private static string appUrl;
    private static DateTime startTime;

    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

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

            // Self-contained fallback: Extract embedded bundle if running as standalone single exe
            if (string.IsNullOrEmpty(webRoot))
            {
                try
                {
                    string localDataDir = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "DawamiApp",
                        "WebBundle_v1.1.0");

                    string localIndex = Path.Combine(localDataDir, "index.html");

                    if (!File.Exists(localIndex))
                    {
                        Assembly asm = Assembly.GetExecutingAssembly();
                        using (Stream resStream = asm.GetManifestResourceStream("DawamiWebBundle"))
                        {
                            if (resStream != null)
                            {
                                if (Directory.Exists(localDataDir))
                                {
                                    try { Directory.Delete(localDataDir, true); } catch { }
                                }
                                Directory.CreateDirectory(localDataDir);
                                string tempZip = Path.Combine(localDataDir, "bundle.zip");
                                using (FileStream fs = new FileStream(tempZip, FileMode.Create, FileAccess.Write))
                                {
                                    resStream.CopyTo(fs);
                                }
                                System.IO.Compression.ZipFile.ExtractToDirectory(tempZip, localDataDir);
                                try { File.Delete(tempZip); } catch { }
                            }
                        }
                    }

                    if (File.Exists(localIndex))
                    {
                        webRoot = localDataDir;
                    }
                }
                catch { }
            }

            if (string.IsNullOrEmpty(webRoot))
            {
                MessageBox.Show(
                    "لم يتم العثور على ملفات واجهة النظام (data/web/index.html).\nيرجى التأكد من تشغيل تطبيق دوامي المكتمل.",
                    "دوامي - خطأ في التشغيل",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            // Start embedded local HTTP server on the best available port
            int port = 60507;
            bool started = false;

            for (int tryPort = 60507; tryPort <= 60525; tryPort++)
            {
                try
                {
                    listener = new HttpListener();
                    string testPrefix = string.Format("http://127.0.0.1:{0}/", tryPort);
                    listener.Prefixes.Add(testPrefix);
                    try
                    {
                        listener.Prefixes.Add(string.Format("http://localhost:{0}/", tryPort));
                    }
                    catch { }
                    listener.Start();
                    port = tryPort;
                    appUrl = testPrefix;
                    started = true;
                    break;
                }
                catch
                {
                    try { if (listener != null) listener.Close(); } catch { }
                    listener = null;
                }
            }

            if (!started || listener == null)
            {
                MessageBox.Show(
                    "تعذر تشغيل خادم الواجهة المكتبي المحلي.\nيرجى التحقق من صلاحيات النظام ومنافذ الشبكة.",
                    "دوامي - خطأ في تشغيل المنفذ",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            Thread serverThread = new Thread(ListenLoop);
            serverThread.IsBackground = true;
            serverThread.Start();

            // Setup System Tray Icon so application never dies prematurely
            SetupTrayIcon(appDir);

            // Small delay to ensure HTTP listener is fully primed
            Thread.Sleep(200);

            // Launch Browser Window
            startTime = DateTime.Now;
            LaunchBrowser(appUrl);

            // Run Windows Message Loop
            Application.Run();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "حدث خطأ أثناء تشغيل دوامي: " + ex.Message,
                "دوامي",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
        finally
        {
            isRunning = false;
            if (trayIcon != null)
            {
                trayIcon.Visible = false;
                trayIcon.Dispose();
            }
            try { if (listener != null) listener.Stop(); } catch { }
        }
    }

    private static void SetupTrayIcon(string appDir)
    {
        trayIcon = new NotifyIcon();
        trayIcon.Text = "دوامي - نظام الحضور والغياب الذكي (قيد التشغيل)";

        try
        {
            string iconPath = Path.Combine(appDir, "app_icon.ico");
            if (File.Exists(iconPath))
            {
                trayIcon.Icon = new Icon(iconPath);
            }
            else
            {
                trayIcon.Icon = SystemIcons.Application;
            }
        }
        catch
        {
            trayIcon.Icon = SystemIcons.Application;
        }

        ContextMenu menu = new ContextMenu();
        menu.MenuItems.Add(new MenuItem("فتح نظام دوامي", (s, e) => LaunchBrowser(appUrl)));
        menu.MenuItems.Add(new MenuItem("إعادة فتح النافذة", (s, e) => LaunchBrowser(appUrl)));
        menu.MenuItems.Add(new MenuItem("-"));
        menu.MenuItems.Add(new MenuItem("خروج وإغلاق دوامي نهائياً", (s, e) =>
        {
            isRunning = false;
            try { listener.Stop(); } catch { }
            trayIcon.Visible = false;
            Application.Exit();
        }));

        trayIcon.ContextMenu = menu;
        trayIcon.DoubleClick += (s, e) => LaunchBrowser(appUrl);
        trayIcon.Visible = true;
    }

    private static void LaunchBrowser(string url)
    {
        try
        {
            string browserPath = GetBrowserExecutablePath();
            string profileDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DawamiApp",
                "BrowserData");

            Directory.CreateDirectory(profileDir);

            ProcessStartInfo psi = new ProcessStartInfo();
            if (!string.IsNullOrEmpty(browserPath) && File.Exists(browserPath))
            {
                psi.FileName = browserPath;
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

            Process p = Process.Start(psi);
            if (p != null)
            {
                try
                {
                    p.EnableRaisingEvents = true;
                    p.Exited += (s, e) =>
                    {
                        // If browser exited after running for more than 5 seconds, user closed window
                        if ((DateTime.Now - startTime).TotalSeconds > 5)
                        {
                            // Keep tray icon active for 3 seconds before auto-closing, or stay in tray
                        }
                    };
                }
                catch { }
            }
        }
        catch (Exception ex)
        {
            try { Process.Start(url); } catch { }
        }
    }

    private static int GetPreferredPort(int preferred)
    {
        try
        {
            TcpListener test = new TcpListener(IPAddress.Loopback, preferred);
            test.Start();
            test.Stop();
            return preferred;
        }
        catch
        {
            TcpListener l = new TcpListener(IPAddress.Loopback, 0);
            l.Start();
            int port = ((IPEndPoint)l.LocalEndpoint).Port;
            l.Stop();
            return port;
        }
    }

    private static string GetBrowserExecutablePath()
    {
        string[] candidates = new string[]
        {
            // Microsoft Edge candidates
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft", "Edge", "Application", "msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Microsoft", "Edge", "Application", "msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "Edge", "Application", "msedge.exe"),
            // Google Chrome candidates
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Google", "Chrome", "Application", "chrome.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Google", "Chrome", "Application", "chrome.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Google", "Chrome", "Application", "chrome.exe")
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
            context.Response.AddHeader("Access-Control-Allow-Origin", "*");
            context.Response.AddHeader("Cross-Origin-Opener-Policy", "same-origin");
            context.Response.AddHeader("Cross-Origin-Embedder-Policy", "credentialless");
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
