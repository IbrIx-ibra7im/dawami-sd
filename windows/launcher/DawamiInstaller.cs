using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("برنامج تثبيت دوامي - Dawami Setup")]
[assembly: AssemblyDescription("مثبت نظام إدارة حضور وغياب الطلاب الذكي - جامعة دنقلا")]
[assembly: AssemblyCompany("جامعة دنقلا - Dawami Systems")]
[assembly: AssemblyProduct("Dawami Installer")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

class Installer
{
    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string installDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "Dawami");

            string currentDir = AppDomain.CurrentDomain.BaseDirectory;
            string zipSource = Path.Combine(currentDir, "Dawami_v1.1.0_Windows_Portable.zip");

            // Look for release folder or zip
            string releaseSource = Path.Combine(currentDir, "Dawami_Release");

            DialogResult res = MessageBox.Show(
                "مرحباً بك في مثبت نظام «دوامي v1.1.0» - نظام إدارة حضور وغياب الطلاب الذكي.\n\n" +
                "سيتم تثبيت النظام في:\n" + installDir + "\n\n" +
                "وإنشاء اختصار مباشر على سطح المكتب وقائمة ابدأ.\n\n" +
                "هل ترغب في متابعة التثبيت الآن؟",
                "تثبيت نظام دوامي v1.1.0",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);

            if (res != DialogResult.Yes) return;

            Directory.CreateDirectory(installDir);

            if (Directory.Exists(releaseSource))
            {
                CopyDirectory(releaseSource, installDir);
            }
            else if (File.Exists(zipSource))
            {
                ZipFile.ExtractToDirectory(zipSource, installDir);
            }
            else
            {
                MessageBox.Show(
                    "لم يتم العثور على ملفات حزمة التثبيت. يرجى وضع ملف التثبيت بجوار مجلد Dawami_Release أو ملف الـ zip.",
                    "خطأ أثناء التثبيت",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            string exePath = Path.Combine(installDir, "Dawami.exe");
            string iconPath = Path.Combine(installDir, "app_icon.ico");

            // Create Desktop Shortcut
            string desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            string desktopShortcut = Path.Combine(desktopDir, "دوامي - نظام الحضور الذكي.lnk");
            CreateShortcut(desktopShortcut, exePath, installDir, iconPath, "دوامي - إدارة حضور وغياب الطلاب");

            // Create Start Menu Shortcut
            string startMenuDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                "Programs");
            string startMenuShortcut = Path.Combine(startMenuDir, "دوامي.lnk");
            CreateShortcut(startMenuShortcut, exePath, installDir, iconPath, "دوامي - نظام الحضور الذكي");

            DialogResult runNow = MessageBox.Show(
                "تم تثبيت نظام «دوامي v1.1.0» بنجاح!\n\n" +
                "تمت إضافة أيقونة النظام إلى سطح المكتب وقائمة ابدأ.\n\n" +
                "هل تريد تشغيل دوامي الآن؟",
                "اكتمل التثبيت بنجاح",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);

            if (runNow == DialogResult.Yes && File.Exists(exePath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = exePath,
                    WorkingDirectory = installDir
                });
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "حدث خطأ أثناء التثبيت:\n" + ex.Message,
                "خطأ",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private static void CopyDirectory(string sourceDir, string targetDir)
    {
        Directory.CreateDirectory(targetDir);
        foreach (string file in Directory.GetFiles(sourceDir))
        {
            string destFile = Path.Combine(targetDir, Path.GetFileName(file));
            File.Copy(file, destFile, true);
        }
        foreach (string subDir in Directory.GetDirectories(sourceDir))
        {
            string destSubDir = Path.Combine(targetDir, Path.GetFileName(subDir));
            CopyDirectory(subDir, destSubDir);
        }
    }

    private static void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string iconPath, string description)
    {
        try
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) return;

            dynamic shell = Activator.CreateInstance(shellType);
            dynamic shortcut = shell.CreateShortcut(shortcutPath);
            shortcut.TargetPath = targetPath;
            shortcut.WorkingDirectory = workingDir;
            shortcut.Description = description;
            if (File.Exists(iconPath))
            {
                shortcut.IconLocation = iconPath + ",0";
            }
            shortcut.Save();
        }
        catch { }
    }
}
